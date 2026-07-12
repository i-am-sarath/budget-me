import 'package:agent_money/features/transactions/models/transaction_model.dart';

/// Single source of truth for the (emoji, label) category options shown per
/// transaction type in the manual entry sheet. The voice-parsing backend
/// prompt (`backend/src/index.ts`) must emit exactly these label strings —
/// keep the two in sync when this catalog changes.
const Map<TransactionType, List<(String emoji, String label)>> kTransactionCategories = {
  TransactionType.expense: [
    ('🍔', 'Food & Dining'),
    ('🚗', 'Transport'),
    ('🛍️', 'Shopping'),
    ('🏠', 'Housing'),
    ('💊', 'Health'),
    ('📱', 'Bills & Utilities'),
    ('🎬', 'Entertainment'),
    ('📚', 'Education'),
    ('✈️', 'Travel'),
    ('👗', 'Clothing'),
    ('🐾', 'Pet Care'),
    ('⚙️', 'General'),
  ],
  TransactionType.income: [
    ('💼', 'Salary'),
    ('💰', 'Freelance'),
    ('🎁', 'Gift'),
    ('🏦', 'Interest'),
    ('🏡', 'Rental Income'),
    ('📦', 'Side Business'),
    ('💹', 'Dividends'),
    ('⚙️', 'Other'),
  ],
  TransactionType.investment: [
    ('📈', 'Stocks'),
    ('🏦', 'Mutual Fund'),
    ('🏠', 'Real Estate'),
    ('💎', 'Crypto'),
    ('🪙', 'Gold / Metals'),
    ('📊', 'ETF / Index Fund'),
    ('💵', 'Fixed Deposit'),
    ('⚙️', 'Other'),
  ],
  TransactionType.lend: [
    ('👤', 'Friend'),
    ('👨‍👩‍👧', 'Family'),
    ('💼', 'Colleague'),
    ('⚙️', 'Other'),
  ],
  TransactionType.borrow: [
    ('👤', 'Friend'),
    ('👨‍👩‍👧', 'Family'),
    ('🏦', 'Bank / Lender'),
    ('💼', 'Colleague'),
    ('⚙️', 'Other'),
  ],
  TransactionType.lendReturn: [
    ('👤', 'Friend'),
    ('👨‍👩‍👧', 'Family'),
    ('💼', 'Colleague'),
    ('⚙️', 'Other'),
  ],
  TransactionType.borrowReturn: [
    ('👤', 'Friend'),
    ('👨‍👩‍👧', 'Family'),
    ('🏦', 'Bank / Lender'),
    ('💼', 'Colleague'),
    ('💳', 'Loan Repayment'),
    ('⚙️', 'Other'),
  ],
};

/// The valid category label strings for [type], e.g. for validating LLM output.
List<String> categoryLabelsFor(TransactionType type) =>
    kTransactionCategories[type]!.map((c) => c.$2).toList();

/// Whether [category] is one of the known labels for [type] (case-sensitive,
/// exact match — the LLM prompt is instructed to emit these exact strings).
bool isKnownCategory(TransactionType type, String category) =>
    categoryLabelsFor(type).contains(category);
