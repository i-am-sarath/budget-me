import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';

/// User-facing exception for voice-log failures.
/// Messages here are safe to render directly in the UI.
class VoiceLogException implements Exception {
  final String message;
  final bool isRateLimit;
  VoiceLogException(this.message, {this.isRateLimit = false});

  @override
  String toString() => message;
}

class OpenAIService {
  void _validateConfig() {
    if (ApiConfig.proxyBaseUrl.isEmpty || ApiConfig.proxyClientSecret.isEmpty) {
      throw VoiceLogException(
        'Voice logging is temporarily unavailable. Please try manual entry.',
      );
    }
  }

  Future<String> _userId() async {
    try {
      return await Purchases.appUserID;
    } catch (_) {
      // RevenueCat not initialized (e.g. desktop). Fall back to a stable-enough
      // device identifier so rate limiting still works coarsely.
      return 'anon-${Platform.operatingSystem}';
    }
  }

  Map<String, String> _baseHeaders(String userId) => {
        'Authorization': 'Bearer ${ApiConfig.proxyClientSecret}',
        'X-User-Id': userId,
      };

  // ─────────────────────────────────────────────
  // Step 1: Transcribe audio (proxied → Whisper)
  // ─────────────────────────────────────────────

  Future<String> transcribeAudio(File audioFile,
      {String languageCode = 'auto'}) async {
    _validateConfig();
    final userId = await _userId();
    final url = Uri.parse('${ApiConfig.proxyBaseUrl}/v1/transcribe');

    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(_baseHeaders(userId))
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
        filename: 'audio.m4a',
      ));

    if (languageCode != 'auto' && languageCode.isNotEmpty) {
      request.fields['language'] = languageCode;
    }

    final streamed = await request.send().timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw VoiceLogException(
        'Transcription took too long. Please try again.',
      ),
    );
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['text'] as String? ?? '').trim();
    }
    throw _mapProxyError(streamed.statusCode, body, isTranscribe: true);
  }

  // ─────────────────────────────────────────────
  // Step 2: Parse transactions (proxied → GPT-4o-mini)
  // ─────────────────────────────────────────────

  Future<List<TransactionModel>> parseTransactions(String transcript) async {
    _validateConfig();
    final userId = await _userId();
    final url = Uri.parse('${ApiConfig.proxyBaseUrl}/v1/parse');
    final today = DateTime.now().toIso8601String().split('T')[0];

    final response = await http
        .post(
          url,
          headers: {
            ..._baseHeaders(userId),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'transcript': transcript, 'today': today}),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw VoiceLogException(
            'Could not understand the audio. Please try again.',
          ),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as String? ?? '';
      return _parseTransactionList(content);
    }
    throw _mapProxyError(response.statusCode, response.body, isTranscribe: false);
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  /// Maps proxy HTTP errors to user-friendly messages.
  /// The proxy returns {"error": {"code": "...", "message": "..."}}; we ignore
  /// the message and pick our own copy keyed on the HTTP status + code.
  VoiceLogException _mapProxyError(
    int status,
    String body, {
    required bool isTranscribe,
  }) {
    String? code;
    try {
      final parsed = jsonDecode(body) as Map<String, dynamic>;
      code = (parsed['error'] as Map<String, dynamic>?)?['code'] as String?;
    } catch (_) {/* body wasn't JSON */}

    if (status == 429 || code == 'rate_limited') {
      return VoiceLogException(
        'You\'ve reached your monthly voice log limit. Upgrade to Pro for unlimited.',
        isRateLimit: true,
      );
    }
    if (status == 401 || status == 403) {
      return VoiceLogException(
        'Voice logging is temporarily unavailable. Please update the app.',
      );
    }
    if (status >= 500 || status == 502) {
      return VoiceLogException(
        isTranscribe
            ? 'Could not transcribe audio right now. Please try again.'
            : 'Could not understand the audio right now. Please try again.',
      );
    }
    return VoiceLogException(
      'Something went wrong. Please try again or use manual entry.',
    );
  }

  List<TransactionModel> _parseTransactionList(String content) {
    try {
      final cleaned = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;

      List<dynamic> items;
      if (parsed.containsKey('transactions')) {
        items = parsed['transactions'] as List<dynamic>;
      } else if (parsed.containsKey('data')) {
        items = parsed['data'] as List<dynamic>;
      } else {
        items = parsed.values.firstWhere(
          (v) => v is List,
          orElse: () => [],
        ) as List<dynamic>;
      }

      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final dateStr = map['date'] as String? ??
            DateTime.now().toIso8601String().split('T')[0];

        DateTime date;
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {
          date = DateTime.now();
        }

        final typeRaw = (map['type'] as String? ?? 'expense').toLowerCase();
        final type = _resolveType(typeRaw);

        final accountName = (map['account_name'] as String?)?.trim();
        return TransactionModel(
          amount: (map['amount'] as num).toDouble(),
          type: type,
          category: map['category'] as String? ?? 'General',
          note: map['note'] as String? ?? '',
          payee: map['payee'] as String?,
          accountName: (accountName != null && accountName.isNotEmpty)
              ? accountName
              : null,
          date: date,
        );
      }).toList();
    } catch (_) {
      throw VoiceLogException(
        'Could not understand the audio. Please try speaking again.',
      );
    }
  }

  /// lend_return → income, borrow_return → expense at the model layer.
  TransactionType _resolveType(String raw) {
    switch (raw) {
      case 'lend_return':
        return TransactionType.lendReturn;
      case 'borrow_return':
        return TransactionType.borrowReturn;
      default:
        return TransactionType.fromString(raw);
    }
  }
}
