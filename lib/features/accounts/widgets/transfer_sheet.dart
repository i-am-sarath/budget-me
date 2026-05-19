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

class TransferSheet extends ConsumerStatefulWidget {
  /// Optional pre-selected source account.
  final AccountModel? fromAccount;
  const TransferSheet({super.key, this.fromAccount});

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  AccountModel? _from;
  AccountModel? _to;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _from = widget.fromAccount;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit(List<AccountModel> accounts) async {
    if (!_formKey.currentState!.validate()) return;

    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both accounts')),
      );
      return;
    }

    if (_from!.id == _to!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and destination must differ')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final note = _noteCtrl.text.trim();
    final displayNote = note.isNotEmpty ? note : 'Transfer';

    // Determine if destination is a liability (loan / credit card)
    final isLoanRepayment =
        _to!.type == AccountType.loan || _to!.type == AccountType.creditCard;

    // Debit from source — uses transferOut so it does NOT count as a budget expense
    final debit = TransactionModel(
      amount: amount,
      type: TransactionType.transferOut,
      category: isLoanRepayment ? 'Loan Repayment' : 'Transfer',
      note: '$displayNote → ${_to!.name}',
      accountId: _from!.id,
      accountName: _from!.name,
      date: _date,
    );

    // Credit to destination
    // For loan/credit card: borrowReturn → reduces the liability balance
    // For normal accounts: transferIn → does NOT inflate "Earned" summary
    final credit = TransactionModel(
      amount: amount,
      type: isLoanRepayment ? TransactionType.borrowReturn : TransactionType.transferIn,
      category: isLoanRepayment ? 'Loan Repayment' : 'Transfer',
      note: '$displayNote ← ${_from!.name}',
      accountId: _to!.id,
      accountName: _to!.name,
      date: _date,
    );

    final txNotifier = ref.read(transactionListProvider.notifier);

    try {
      await txNotifier.addTransaction(debit);
      if (!mounted) return;
      await txNotifier.addTransaction(credit);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final currency = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountProvider);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
          top: 24, left: 24, right: 24, bottom: bottomPad + 32),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
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

              // Title
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tc.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.swap_horiz_rounded,
                        color: tc.onSurface, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Transfer Money',
                    style: GoogleFonts.inter(
                      color: tc.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Amount
              Container(
                decoration: BoxDecoration(
                  color: tc.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tc.outlineVariant, width: 0.5),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
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
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        autofocus: true,
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
                          if (double.tryParse(v) == null ||
                              double.parse(v) <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // From / To selectors
              accountsAsync.when(
                loading: () => const CircularProgressIndicator(strokeWidth: 2),
                error: (e, _) => Text('Error: $e'),
                data: (accounts) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccountDropdown(
                      label: 'FROM account',
                      selected: _from,
                      accounts: accounts,
                      exclude: _to,
                      tc: tc,
                      onChanged: (a) => setState(() => _from = a),
                    ),
                    const SizedBox(height: 8),

                    // Swap arrow
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          final tmp = _from;
                          _from = _to;
                          _to = tmp;
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: tc.surfaceContainerHigh,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: tc.outlineVariant, width: 0.5),
                          ),
                          child: Icon(Icons.swap_vert_rounded,
                              color: tc.onSurface, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    _AccountDropdown(
                      label: 'TO account',
                      selected: _to,
                      accounts: accounts,
                      exclude: _from,
                      tc: tc,
                      onChanged: (a) => setState(() => _to = a),
                    ),
                    const SizedBox(height: 16),

                    // Note
                    TextFormField(
                      controller: _noteCtrl,
                      style: GoogleFonts.inter(
                          color: tc.onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        prefixIcon: Icon(Icons.edit_outlined,
                            color: tc.onSurfaceVariant, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date picker
                    GestureDetector(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: tc.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: tc.outlineVariant, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_outlined,
                                color: tc.onSurfaceVariant, size: 18),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('EEEE, MMM d, yyyy').format(_date),
                              style: GoogleFonts.inter(
                                  color: tc.onSurface, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _submit(accounts),
                        child: Text(
                          'Transfer',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Account Dropdown ────────────────────────────────────────
class _AccountDropdown extends StatelessWidget {
  final String label;
  final AccountModel? selected;
  final List<AccountModel> accounts;
  final AccountModel? exclude;
  final AppThemeColors tc;
  final ValueChanged<AccountModel?> onChanged;

  const _AccountDropdown({
    required this.label,
    required this.selected,
    required this.accounts,
    required this.exclude,
    required this.tc,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filtered =
        accounts.where((a) => exclude == null || a.id != exclude!.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: tc.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: tc.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tc.outlineVariant, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AccountModel>(
              value: selected != null &&
                      filtered.any((a) => a.id == selected!.id)
                  ? selected
                  : null,
              hint: Text(
                'Select account',
                style: GoogleFonts.inter(
                    color: tc.onSurfaceVariant, fontSize: 14),
              ),
              isExpanded: true,
              dropdownColor: tc.surfaceContainerHigh,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: tc.onSurfaceVariant, size: 20),
              items: filtered.map((acc) {
                return DropdownMenuItem<AccountModel>(
                  value: acc,
                  child: Row(
                    children: [
                      Icon(acc.displayIcon,
                          color: tc.onSurface, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          acc.name,
                          style: GoogleFonts.inter(
                              color: tc.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
