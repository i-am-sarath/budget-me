import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/currency_service.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:agent_money/features/transactions/models/transaction_model.dart';
import 'package:agent_money/features/transactions/repositories/transaction_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ManualEntrySheet extends ConsumerStatefulWidget {
  final TransactionModel? prefill;
  const ManualEntrySheet({super.key, this.prefill});

  @override
  ConsumerState<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _payeeController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String _category = 'General';
  AccountModel? _selectedAccount;
  DateTime _date = DateTime.now();

  // ── World-wide category definitions ──────────────────────
  static const _categories = {
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
  };

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _amountController.text = p.amount.toString();
      _noteController.text = p.note;
      _payeeController.text = p.payee ?? '';
      _type = p.type;
      _category = p.category;
      _date = p.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _payeeController.dispose();
    super.dispose();
  }

  List<(String, String)> get _currentCategories =>
      _categories[_type] ?? _categories[TransactionType.expense]!;

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      final cats = _categories[type]!;
      if (!cats.any((c) => c.$2 == _category)) {
        _category = cats.first.$2;
      }
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      final amount = double.tryParse(_amountController.text) ?? 0;
      final transaction = TransactionModel(
        amount: amount,
        type: _type,
        category: _category,
        note: _noteController.text,
        payee: _payeeController.text.isEmpty ? null : _payeeController.text,
        accountId: _selectedAccount?.id,
        accountName: _selectedAccount?.name,
        date: _date,
      );
      ref.read(transactionListProvider.notifier).addTransaction(transaction);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountProvider);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final tc = AppThemeColors.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 20, left: 24, right: 24, bottom: bottomPad + 32,
      ),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tc.outlineVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Transaction type selector
              _buildTypeSelector(tc),
              const SizedBox(height: 16),

              // Amount field
              _buildAmountField(currency, tc),
              const SizedBox(height: 14),

              // Category chips
              _buildLabel('Category', tc),
              const SizedBox(height: 8),
              _buildCategoryGrid(tc),
              const SizedBox(height: 14),

              // Payee field for lend/borrow
              if (_type == TransactionType.lend ||
                  _type == TransactionType.borrow) ...[
                _buildTextField(
                  controller: _payeeController,
                  label: 'Person / organisation name',
                  icon: Icons.person_outline_rounded,
                  tc: tc,
                ),
                const SizedBox(height: 14),
              ],

              // Note
              _buildTextField(
                controller: _noteController,
                label: 'Note (optional)',
                icon: Icons.edit_outlined,
                tc: tc,
              ),
              const SizedBox(height: 14),

              // Account selector
              _buildLabel('Account', tc),
              const SizedBox(height: 8),
              accountsAsync.when(
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
                data: (accounts) => _buildAccountSelector(accounts, tc),
              ),
              const SizedBox(height: 14),

              // Date picker
              _buildDatePicker(tc),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(
                    'Save Transaction',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Type selector ─────────────────────────────────────────
  Widget _buildTypeSelector(AppThemeColors tc) {
    final types = [
      (TransactionType.expense,    'Expense',  Icons.arrow_upward_rounded,      tc.expense),
      (TransactionType.income,     'Income',   Icons.arrow_downward_rounded,    tc.income),
      (TransactionType.investment, 'Invest',   Icons.trending_up_rounded,       tc.investment),
      (TransactionType.lend,       'Lend',     Icons.people_alt_rounded,        tc.lend),
      (TransactionType.borrow,     'Borrow',   Icons.person_add_alt_1_rounded,  tc.borrow),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tc.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: types.map((t) {
          final isSelected = _type == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onTypeChanged(t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? tc.onSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$3,
                        color: isSelected ? tc.surface : tc.onSurfaceVariant,
                        size: 16),
                    const SizedBox(height: 3),
                    Text(
                      t.$2,
                      style: GoogleFonts.inter(
                        color: isSelected ? tc.surface : tc.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Amount field ──────────────────────────────────────────
  Widget _buildAmountField(CurrencyState currency, AppThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            currency.currency.symbol,
            style: GoogleFonts.inter(
              color: tc.onSurfaceVariant,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: widget.prefill == null,
              style: GoogleFonts.inter(
                color: tc.onSurface,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if (double.tryParse(v) == null) return 'Invalid amount';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label, AppThemeColors tc) => Text(
        label,
        style: GoogleFonts.inter(
          color: tc.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );

  // ── Category chips ────────────────────────────────────────
  Widget _buildCategoryGrid(AppThemeColors tc) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _currentCategories.map((cat) {
        final isSelected = _category == cat.$2;
        return GestureDetector(
          onTap: () => setState(() => _category = cat.$2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? tc.onSurface : tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? Colors.transparent : tc.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.$1, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  cat.$2,
                  style: GoogleFonts.inter(
                    color: isSelected ? tc.surface : tc.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppThemeColors tc,
  }) =>
      TextFormField(
        controller: controller,
        style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: tc.onSurfaceVariant, size: 20),
        ),
      );

  // ── Account selector chips ────────────────────────────────
  Widget _buildAccountSelector(
      List<AccountModel> accounts, AppThemeColors tc) {
    if (accounts.isEmpty) {
      return Text(
        'No accounts yet — add one in the Accounts tab',
        style: GoogleFonts.inter(color: tc.onSurfaceVariant, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _accountChip(null, 'None', tc),
        ...accounts.map((acc) => _accountChip(acc, acc.name, tc)),
      ],
    );
  }

  Widget _accountChip(AccountModel? acc, String label, AppThemeColors tc) {
    final isSelected = acc == null
        ? _selectedAccount == null
        : _selectedAccount?.id == acc.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccount = acc),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? tc.onSurface : tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? Colors.transparent : tc.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (acc != null) ...[
              Icon(acc.type.icon,
                  size: 12,
                  color: isSelected ? tc.surface : acc.type.color),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? tc.surface : tc.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date picker ───────────────────────────────────────────
  Widget _buildDatePicker(AppThemeColors tc) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tc.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                color: tc.onSurfaceVariant, size: 18),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(_date),
              style: GoogleFonts.inter(color: tc.onSurface, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
