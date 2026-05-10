import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:agent_money/core/config/api_config.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';

  // ─────────────────────────────────────────────
  // Step 1: Transcribe audio with Whisper
  // No forced language — auto-detect handles Tamil, Hindi, English, Hinglish
  // ─────────────────────────────────────────────

  Future<String> transcribeAudio(File audioFile) async {
    final url = Uri.parse('$_baseUrl/audio/transcriptions');

    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer ${ApiConfig.openAiKey}'
      ..fields['model'] = 'whisper-1'
      // No 'language' field → Whisper auto-detects (Tamil, Hindi, English, Hinglish)
      ..fields['response_format'] = 'text'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
          filename: 'audio.m4a',
        ),
      );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Whisper API timed out'),
    );
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      return responseBody.trim();
    } else {
      final error = _parseErrorMessage(responseBody);
      throw Exception('Transcription failed: $error');
    }
  }

  // ─────────────────────────────────────────────
  // Step 2: Parse transactions with GPT-4o-mini
  // ─────────────────────────────────────────────

  Future<List<TransactionModel>> parseTransactions(String transcript) async {
    final url = Uri.parse('$_baseUrl/chat/completions');

    final today = DateTime.now().toIso8601String().split('T')[0];
    final systemPrompt =
        '''
You are a multilingual financial transaction parser for an app called Budget Me.
The user's voice transcript may be in English, Hindi, Tamil, Hinglish, or any mix.

Extract ALL transactions and return them as a JSON object with a "transactions" array.

━━━ TYPES ━━━
"type" must be exactly one of: expense, income, lend, borrow, lend_return, borrow_return, investment
  - expense: user spent money (bought something, paid a bill, rent, EMI, subscriptions)
  - income: user received money (salary, freelance, sold something, cashback)
  - investment: user invested money (SIP, DigiGold, stocks, mutual fund, FD, PPF, NPS, crypto)
  - lend: user gave money TO someone (gave loan, paid for friend, gave advance)
  - borrow: user borrowed money FROM someone (took loan, friend paid for me, took advance)
  - lend_return: someone RETURNED money they owed the user ("he paid me back", "returned my money", "got the money back from him")
  - borrow_return: user RETURNED borrowed money ("I returned the money", "paid back my loan", "repaid", "settled")

━━━ FIELDS ━━━
  - "amount": positive number. Parse "five hundred" → 500, "2k" → 2000, "₹" or "\$" prefix.
  - "category": one of: Food, Transport, Shopping, Rent, Health, Bills, Entertainment, Education, Travel, Salary, Freelance, Investment, Gift, Interest, General, Loan Repayment
  - "note": short English description of the transaction (translate non-English to English)
  - "payee": person's name for lend/borrow types, merchant for expense. Leave "" if unknown.
  - "account_name": if the user mentions a specific account (e.g. "from savings", "to HDFC", "cash", "UPI"), include it. Otherwise leave "".
  - "date": ISO format YYYY-MM-DD. Today is: $today. Use today unless user says otherwise.

━━━ INVESTMENT VOCABULARY ━━━
  - SIP / sip = Systematic Investment Plan → investment
  - DigiGold / digi gold / digital gold → investment
  - Mutual fund / MF → investment
  - FD / fixed deposit → investment
  - PPF / NPS / ELSS → investment
  - Stocks / shares / equity → investment
  - Crypto / bitcoin / ethereum → investment

━━━ MULTILINGUAL VOCABULARY ━━━
Tamil:
  - maligai / மளிகை = grocery/shopping (category: Shopping)
  - unavagam / சாப்பாட்டு கடை = restaurant (category: Food)
  - jama / ஜாமா = paid / credited (context-sensitive)
  - kadan / கடன் = loan/lend
  - thiruppi kuduthan / திரும்பி குடுத்தான் = he returned the money → lend_return
  - saadam / சாதம் = rice/food
  - kadai = shop
  - auto = auto-rickshaw (category: Transport)
  - petrol = fuel (category: Transport)
Hindi/Hinglish:
  - khana / khaana = food
  - gaadi / gadi = vehicle/transport
  - dukaan = shop
  - dost ko diya = lent to friend → lend
  - wapas mila / wapas kiya = returned → lend_return or borrow_return
  - salary aayi = received salary → income
  - EMI / kiraya = rent/EMI → expense
  - udhar diya = lent → lend
  - udhar liya = borrowed → borrow
  - loan bhara = repaid loan → borrow_return

━━━ REPAYMENT LOGIC (IMPORTANT) ━━━
When someone RETURNS money to the user:
  → type = "lend_return" (reduces outstanding lent amount, adds to user balance)
  → Example: "Rahul gave me back the 500 he owed" → lend_return, amount=500, payee="Rahul"

When user RETURNS money they borrowed:
  → type = "borrow_return" (reduces outstanding borrowed amount, reduces user balance)
  → Example: "I paid back the 1000 I borrowed from Priya" → borrow_return, amount=1000, payee="Priya"

When user pays EMI or loan installment:
  → type = "borrow_return", category = "Loan Repayment"
  → Example: "Paid EMI 15000" → borrow_return, amount=15000, category="Loan Repayment", note="EMI payment"

━━━ TRANSFER RECOGNITION ━━━
If the user says "transferred X to Y account" or "moved money from A to B":
  → Create TWO transactions:
    1. expense from source account
    2. income to destination account
  → Both should have category="Transfer"

━━━ EXAMPLES ━━━
Input: "Spent 300 on lunch at office canteen"
Output: {"transactions":[{"amount":300,"type":"expense","category":"Food","note":"Lunch at office canteen","payee":"","account_name":"","date":"$today"}]}

Input: "SIP payment 5000 for mutual fund"
Output: {"transactions":[{"amount":5000,"type":"investment","category":"Investment","note":"SIP mutual fund payment","payee":"","account_name":"","date":"$today"}]}

Input: "Rahul gave me back 500 rupees"
Output: {"transactions":[{"amount":500,"type":"lend_return","category":"General","note":"Rahul returned 500","payee":"Rahul","account_name":"","date":"$today"}]}

Input: "Paid EMI 15000 from HDFC account"
Output: {"transactions":[{"amount":15000,"type":"borrow_return","category":"Loan Repayment","note":"EMI payment","payee":"","account_name":"HDFC","date":"$today"}]}

Input: "Got salary 50000, paid 12000 rent"
Output: {"transactions":[{"amount":50000,"type":"income","category":"Salary","note":"Monthly salary","payee":"","account_name":"","date":"$today"},{"amount":12000,"type":"expense","category":"Rent","note":"Monthly rent","payee":"","account_name":"","date":"$today"}]}

Input: "50 rupees kuduthen Ravi ku" (Tamil: gave 50 rupees to Ravi)
Output: {"transactions":[{"amount":50,"type":"lend","category":"General","note":"Lent to Ravi","payee":"Ravi","account_name":"","date":"$today"}]}

Return ONLY valid JSON. No markdown, no explanation, no extra keys.
''';

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${ApiConfig.openAiKey}',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': transcript},
            ],
            'temperature': 0,
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('GPT API timed out'),
        );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['choices'][0]['message']['content'] as String;
      return _parseTransactionList(content);
    } else {
      final error = _parseErrorMessage(response.body);
      throw Exception('Parsing failed: $error');
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

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
        items =
            parsed.values.firstWhere((v) => v is List, orElse: () => [])
                as List<dynamic>;
      }

      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final dateStr =
            map['date'] as String? ??
            DateTime.now().toIso8601String().split('T')[0];

        DateTime date;
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {
          date = DateTime.now();
        }

        // Map lend_return / borrow_return to correct TransactionType
        final typeRaw = (map['type'] as String? ?? 'expense').toLowerCase();
        final type = _resolveType(typeRaw);

        return TransactionModel(
          amount: (map['amount'] as num).toDouble(),
          type: type,
          category: map['category'] as String? ?? 'General',
          note: map['note'] as String? ?? '',
          payee: map['payee'] as String?,
          date: date,
        );
      }).toList();
    } catch (e) {
      throw Exception('Could not parse AI response. Please try again.\n$e');
    }
  }

  /// Maps GPT type strings (including lend_return/borrow_return) to TransactionType.
  /// lend_return → income  (money coming back to user from someone they lent to)
  /// borrow_return → expense (user sending back money they borrowed)
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

  String _parseErrorMessage(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return json['error']?['message'] as String? ?? responseBody;
    } catch (_) {
      return responseBody;
    }
  }
}
