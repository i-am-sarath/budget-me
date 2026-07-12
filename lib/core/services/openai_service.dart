import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/features/transactions/models/category_catalog.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';

/// User-facing exception for voice-log failures.
/// Messages here are safe to render directly in the UI.
class VoiceLogException implements Exception {
  final String message;
  final bool isRateLimit;

  /// The transcript was understood but described nothing the parser could
  /// turn into a transaction (e.g. silence, "um... nothing", small talk).
  /// The caller should fall back to manual entry rather than show a
  /// misleading "0 transactions found" result.
  final bool isNoTransactions;

  VoiceLogException(
    this.message, {
    this.isRateLimit = false,
    this.isNoTransactions = false,
  });

  @override
  String toString() => message;
}

/// A transaction parsed from voice, plus whether the parser is confident in
/// it. Low-confidence drafts should be surfaced for the user to review/edit
/// rather than offered up for a one-tap save.
class ParsedTransaction {
  final TransactionModel transaction;
  final bool lowConfidence;
  final String? lowConfidenceReason;

  ParsedTransaction(
    this.transaction, {
    this.lowConfidence = false,
    this.lowConfidenceReason,
  });

  ParsedTransaction copyWithTransaction(TransactionModel tx) =>
      ParsedTransaction(tx, lowConfidence: lowConfidence, lowConfidenceReason: lowConfidenceReason);
}

/// Parses the raw JSON content of an LLM `/v1/parse` response into
/// [ParsedTransaction]s. Pure function (no network) — this is what the
/// regression tests exercise directly with canned LLM output.
///
/// Throws [VoiceLogException] if the content isn't valid/expected JSON, or
/// (with [VoiceLogException.isNoTransactions] set) if it parsed fine but
/// described no transactions at all.
List<ParsedTransaction> parseTransactionJson(String content) {
  late final List<dynamic> items;
  try {
    final cleaned = content.replaceAll('```json', '').replaceAll('```', '').trim();
    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;

    if (parsed.containsKey('transactions')) {
      items = parsed['transactions'] as List<dynamic>;
    } else if (parsed.containsKey('data')) {
      items = parsed['data'] as List<dynamic>;
    } else {
      items = parsed.values.firstWhere((v) => v is List, orElse: () => []) as List<dynamic>;
    }
  } catch (_) {
    throw VoiceLogException('Could not understand the audio. Please try speaking again.');
  }

  if (items.isEmpty) {
    throw VoiceLogException(
      "Didn't catch a transaction in that. Please try again or enter it manually.",
      isNoTransactions: true,
    );
  }

  final results = <ParsedTransaction>[];
  for (final raw in items) {
    final parsedItem = _parseOneTransaction(raw);
    if (parsedItem != null) results.add(parsedItem);
  }

  if (results.isEmpty) {
    // Every item in the array was too malformed to salvage even defensively.
    throw VoiceLogException('Could not understand the audio. Please try speaking again.');
  }
  return results;
}

/// Parses a single transaction JSON object defensively — a malformed or
/// missing field degrades to a low-confidence draft rather than throwing,
/// so one bad item in a multi-transaction utterance doesn't wipe out the
/// rest of the batch. Returns null only if the item isn't a usable map at
/// all (e.g. the LLM emitted a bare string in the array).
ParsedTransaction? _parseOneTransaction(dynamic raw) {
  if (raw is! Map<String, dynamic>) return null;
  final map = raw;

  final reasons = <String>[];

  final dateStr = map['date'] as String? ?? DateTime.now().toIso8601String().split('T')[0];
  DateTime date;
  try {
    date = DateTime.parse(dateStr);
  } catch (_) {
    date = DateTime.now();
    reasons.add('date unparseable');
  }

  final typeRaw = (map['type'] as String? ?? '').toLowerCase().trim();
  final type = _resolveType(typeRaw.isEmpty ? 'expense' : typeRaw);
  if (!_validTypeStrings.contains(typeRaw)) {
    reasons.add(typeRaw.isEmpty ? 'type missing' : 'type "$typeRaw" unrecognized, defaulted to expense');
  }

  final amount = _coerceAmount(map['amount']);
  if (amount == null || amount <= 0) reasons.add('amount missing or invalid');

  var category = (map['category'] as String?)?.trim() ?? '';
  if (category.isEmpty) {
    category = 'General';
    reasons.add('category missing');
  } else if (!isKnownCategory(type, category)) {
    // Off-vocabulary category (prompt/model drift) — keep the raw text so no
    // information is silently discarded, but flag it for review.
    reasons.add('category "$category" not in known list for ${type.name}');
  }

  final llmFlaggedLowConfidence = map['low_confidence'] == true;
  if (llmFlaggedLowConfidence) reasons.add('model flagged low confidence');

  final accountName = (map['account_name'] as String?)?.trim();

  final tx = TransactionModel(
    amount: amount ?? 0,
    type: type,
    category: category,
    note: map['note'] as String? ?? '',
    payee: map['payee'] as String?,
    accountName: (accountName != null && accountName.isNotEmpty) ? accountName : null,
    date: date,
  );

  return ParsedTransaction(
    tx,
    lowConfidence: reasons.isNotEmpty,
    lowConfidenceReason: reasons.isEmpty ? null : reasons.join('; '),
  );
}

/// Accepts a numeric amount whether the LLM returned it as a JSON number or
/// (occasionally, despite the schema) as a numeric-looking string.
double? _coerceAmount(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
  return null;
}

const _validTypeStrings = {
  'expense',
  'income',
  'investment',
  'lend',
  'borrow',
  'lend_return',
  'borrow_return',
};

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

  Future<String> transcribeAudio(File audioFile) async {
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

  Future<List<ParsedTransaction>> parseTransactions(String transcript) async {
    if (transcript.trim().isEmpty) {
      throw VoiceLogException(
        "Didn't catch any speech. Please try again or enter it manually.",
        isNoTransactions: true,
      );
    }

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
      return parseTransactionJson(content);
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

}
