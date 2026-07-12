// Offline regression guard for the voice → transaction parsing pipeline.
// Two things run here without any network access:
//
//  1. A "fixture lint" over backend/test/fixtures/voice_parse_cases.json —
//     catches the exact category/type drift bug class (the LLM prompt's
//     vocabulary silently diverging from the app's real category chips)
//     without needing to call the actual LLM.
//  2. Unit tests for parseTransactionJson() (lib/core/services/openai_service.dart)
//     covering the defensive parsing / low-confidence / graceful-fallback
//     contract against canned LLM responses.
//
// The live per-field accuracy scoring against the real model lives in
// backend/test/run_regression.ts (needs OPENAI_API_KEY + network) — this
// file is the fast, always-green guard that runs in `flutter test`.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_money/core/services/openai_service.dart';
import 'package:agent_money/features/transactions/models/category_catalog.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';

void main() {
  group('fixture lint (backend/test/fixtures/voice_parse_cases.json)', () {
    late Map<String, dynamic> fixtures;

    setUpAll(() {
      final file = File('backend/test/fixtures/voice_parse_cases.json');
      fixtures = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('has a healthy number of cases', () {
      final cases = fixtures['cases'] as List;
      expect(cases.length, greaterThanOrEqualTo(50),
          reason: 'Acceptance criteria calls for 50-100 real-world phrases');
      expect(cases.length, lessThanOrEqualTo(100));
    });

    test('every case id is unique', () {
      final cases = fixtures['cases'] as List;
      final ids = cases.map((c) => c['id'] as String).toList();
      expect(ids.toSet().length, ids.length, reason: 'Duplicate case id found');
    });

    test('every expected type/category pair is in the app\'s real vocabulary', () {
      final cases = fixtures['cases'] as List;
      final problems = <String>[];

      for (final c in cases) {
        final expectEmpty = c['expectEmpty'] == true;
        if (expectEmpty) continue;

        final expect = c['expect'] as List?;
        if (expect == null) {
          problems.add('${c['id']}: has neither "expect" nor "expectEmpty"');
          continue;
        }

        for (final tx in expect) {
          final typeStr = tx['type'] as String;
          final type = TransactionType.fromString(typeStr);
          // fromString silently defaults to expense on garbage input — catch
          // that here so a typo'd fixture type doesn't pass silently.
          if (type == TransactionType.expense && typeStr != 'expense') {
            problems.add('${c['id']}: type "$typeStr" is not a recognized TransactionType');
            continue;
          }

          final category = tx['category'] as String;
          if (!isKnownCategory(type, category)) {
            problems.add(
              '${c['id']}: category "$category" is not in kTransactionCategories for '
              '${type.name} (valid: ${categoryLabelsFor(type).join(", ")})',
            );
          }

          final dateStr = tx['date'] as String;
          if (DateTime.tryParse(dateStr) == null) {
            problems.add('${c['id']}: date "$dateStr" is not ISO-parseable');
          }

          if ((tx['amount'] as num) <= 0) {
            problems.add('${c['id']}: expected amount must be positive');
          }
        }
      }

      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('parseTransactionJson — defensive parsing contract', () {
    test('parses a well-formed single transaction', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {
            'amount': 280,
            'type': 'expense',
            'category': 'Food & Dining',
            'note': 'Groceries',
            'payee': '',
            'account_name': '',
            'date': '2026-07-12',
            'low_confidence': false,
          }
        ]
      }));

      expect(result, hasLength(1));
      expect(result.single.lowConfidence, isFalse);
      expect(result.single.transaction.amount, 280);
      expect(result.single.transaction.type, TransactionType.expense);
      expect(result.single.transaction.category, 'Food & Dining');
      expect(result.single.transaction.date, DateTime.parse('2026-07-12'));
    });

    test('preserves order across multiple transactions', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {'amount': 280, 'type': 'expense', 'category': 'Food & Dining', 'date': '2026-07-12'},
          {'amount': 40, 'type': 'expense', 'category': 'Food & Dining', 'date': '2026-07-12'},
        ]
      }));

      expect(result, hasLength(2));
      expect(result[0].transaction.amount, 280);
      expect(result[1].transaction.amount, 40);
    });

    test('lend_return and borrow_return map to the correct model type', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {'amount': 500, 'type': 'lend_return', 'category': 'Friend', 'date': '2026-07-12'},
          {'amount': 1000, 'type': 'borrow_return', 'category': 'Loan Repayment', 'date': '2026-07-12'},
        ]
      }));

      expect(result[0].transaction.type, TransactionType.lendReturn);
      expect(result[1].transaction.type, TransactionType.borrowReturn);
    });

    test('accepts amount as a numeric string (LLM schema drift)', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {'amount': '280', 'type': 'expense', 'category': 'Food & Dining', 'date': '2026-07-12'}
        ]
      }));

      expect(result.single.transaction.amount, 280);
      expect(result.single.lowConfidence, isFalse);
    });

    test('missing amount is flagged low-confidence rather than dropped', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {'type': 'expense', 'category': 'Food & Dining', 'date': '2026-07-12'}
        ]
      }));

      expect(result, hasLength(1), reason: 'the item must still surface for manual review, not vanish');
      expect(result.single.lowConfidence, isTrue);
      expect(result.single.lowConfidenceReason, contains('amount'));
    });

    test('zero or negative amount is flagged low-confidence', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {'amount': 0, 'type': 'expense', 'category': 'Food & Dining', 'date': '2026-07-12'}
        ]
      }));
      expect(result.single.lowConfidence, isTrue);
    });

    test('off-vocabulary category is kept (not discarded) but flagged low-confidence', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {'amount': 280, 'type': 'expense', 'category': 'Groceries', 'date': '2026-07-12'}
        ]
      }));

      expect(result.single.transaction.category, 'Groceries',
          reason: 'raw category text must not be silently discarded');
      expect(result.single.lowConfidence, isTrue);
      expect(result.single.lowConfidenceReason, contains('category'));
    });

    test('unrecognized type string defaults to expense and is flagged low-confidence', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {'amount': 280, 'type': 'purchase', 'category': 'General', 'date': '2026-07-12'}
        ]
      }));

      expect(result.single.transaction.type, TransactionType.expense);
      expect(result.single.lowConfidence, isTrue);
      expect(result.single.lowConfidenceReason, contains('type'));
    });

    test('model-flagged low_confidence propagates even when fields look valid', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {
            'amount': 500,
            'type': 'income',
            'category': 'Other',
            'date': '2026-07-12',
            'low_confidence': true,
          }
        ]
      }));

      expect(result.single.lowConfidence, isTrue);
      expect(result.single.lowConfidenceReason, contains('model flagged'));
    });

    test('unparseable date falls back to today rather than throwing', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {'amount': 280, 'type': 'expense', 'category': 'Food & Dining', 'date': 'yesterday'}
        ]
      }));

      expect(result.single.lowConfidence, isTrue);
      expect(result.single.lowConfidenceReason, contains('date'));
    });

    test('empty transactions array throws isNoTransactions (graceful fallback signal)', () {
      expect(
        () => parseTransactionJson(jsonEncode({'transactions': []})),
        throwsA(isA<VoiceLogException>().having((e) => e.isNoTransactions, 'isNoTransactions', isTrue)),
      );
    });

    test('malformed JSON throws a generic VoiceLogException', () {
      expect(
        () => parseTransactionJson('not json at all'),
        throwsA(isA<VoiceLogException>().having((e) => e.isNoTransactions, 'isNoTransactions', isFalse)),
      );
    });

    test('markdown-fenced JSON is unwrapped before parsing', () {
      final result = parseTransactionJson(
        '```json\n${jsonEncode({
          'transactions': [
            {'amount': 280, 'type': 'expense', 'category': 'Food & Dining', 'date': '2026-07-12'}
          ]
        })}\n```',
      );
      expect(result, hasLength(1));
    });

    test('one malformed item in a multi-item array does not wipe out the rest', () {
      final result = parseTransactionJson(jsonEncode({
        'transactions': [
          {'amount': 280, 'type': 'expense', 'category': 'Food & Dining', 'date': '2026-07-12'},
          'not a transaction object',
          {'amount': 40, 'type': 'expense', 'category': 'Food & Dining', 'date': '2026-07-12'},
        ]
      }));

      expect(result, hasLength(2));
      expect(result[0].transaction.amount, 280);
      expect(result[1].transaction.amount, 40);
    });
  });

  group('OpenAIService.parseTransactions — client-side short-circuit', () {
    test('blank transcript throws isNoTransactions without a network call', () async {
      final service = OpenAIService();
      await expectLater(
        service.parseTransactions('   '),
        throwsA(isA<VoiceLogException>().having((e) => e.isNoTransactions, 'isNoTransactions', isTrue)),
      );
    });
  });
}
