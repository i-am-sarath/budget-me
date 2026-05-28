import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_money/core/theme.dart';
import 'package:agent_money/features/accounts/models/account_model.dart';
import 'package:agent_money/features/accounts/repositories/account_repository.dart';
import 'package:google_fonts/google_fonts.dart';

class AddAccountSheet extends ConsumerStatefulWidget {
  /// Pass an existing account to enter edit mode.
  final AccountModel? existing;
  const AddAccountSheet({super.key, this.existing});

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _lastFourCtrl = TextEditingController();

  AccountType _type = AccountType.bank;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _balanceCtrl.text = e.balance == 0 ? '' : e.balance.toString();
      _bankCtrl.text = e.bankName;
      _lastFourCtrl.text = e.accountNumber;
      _type = e.type;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _bankCtrl.dispose();
    _lastFourCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final e = widget.existing;
    final balance = double.tryParse(_balanceCtrl.text) ?? 0.0;
    if (balance < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid balance amount')));
      return;
    }
    final account = AccountModel(
      id: e?.id,
      name: _nameCtrl.text.trim(),
      type: _type,
      balance: balance,
      bankName: _bankCtrl.text.trim(),
      accountNumber: _lastFourCtrl.text.trim(),
      createdAt: e?.createdAt,
    );

    if (_isEditing) {
      ref.read(accountProvider.notifier).updateAccount(account);
    } else {
      ref.read(accountProvider.notifier).addAccount(account);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final tc = AppThemeColors.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: bottomPad + 32,
      ),
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
              Text(
                _isEditing ? 'Edit Account' : 'Add Account',
                style: GoogleFonts.inter(
                  color: tc.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isEditing
                    ? 'Update your account details below'
                    : 'Choose a type that fits your account',
                style: GoogleFonts.inter(
                  color: tc.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),

              // Account type grid
              _buildTypeGrid(tc),
              const SizedBox(height: 8),

              // Type hint
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _type.hint,
                  key: ValueKey(_type),
                  style: GoogleFonts.inter(
                    color: _type.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Account name
              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Account name',
                  hintText: _type == AccountType.bank
                      ? 'e.g. Chase Checking'
                      : _type == AccountType.cash
                      ? 'e.g. Wallet cash'
                      : _type == AccountType.loan
                      ? 'e.g. Car loan'
                      : 'Account name',
                  prefixIcon: Icon(_type.icon, color: _type.color, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 14),

              // Balance
              TextFormField(
                controller: _balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  labelText: _isEditing
                      ? 'Current balance'
                      : 'Opening balance (optional)',
                  hintText: '0.00',
                  prefixIcon: Icon(
                    Icons.account_balance_rounded,
                    color: tc.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),

              // Bank / institution name (bank & credit card)
              if (_type == AccountType.bank ||
                  _type == AccountType.creditCard ||
                  _type == AccountType.wallet ||
                  _type == AccountType.mobilePay) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bankCtrl,
                  style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: _type == AccountType.bank
                        ? 'Bank name (optional)'
                        : _type == AccountType.creditCard
                        ? 'Issuer name (optional)'
                        : 'Provider name (optional)',
                    hintText: _type == AccountType.mobilePay
                        ? 'e.g. PayPal, GCash, Pix'
                        : _type == AccountType.wallet
                        ? 'e.g. Apple Pay, Google Pay'
                        : '',
                    prefixIcon: Icon(
                      Icons.account_balance_rounded,
                      color: tc.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ],

              // Last 4 digits (bank & credit card only)
              if (_type == AccountType.bank ||
                  _type == AccountType.creditCard) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastFourCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  style: GoogleFonts.inter(color: tc.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Last 4 digits (optional)',
                    counterText: '',
                    prefixIcon: Icon(
                      Icons.credit_card_rounded,
                      color: tc.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ],

              // Loan-specific note
              if (_type == AccountType.loan) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tc.expense.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tc.expense.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: tc.expense,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enter the outstanding amount you owe. This will appear as debt in your net worth.',
                          style: GoogleFonts.inter(
                            color: tc.expense,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(
                    _isEditing ? 'Save Changes' : 'Create Account',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeGrid(AppThemeColors tc) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AccountType.values.map((t) {
        final isSelected = _type == t;
        return GestureDetector(
          onTap: () => setState(() {
            _type = t;
            // Clear bank-specific fields if switching away
            if (t != AccountType.bank && t != AccountType.creditCard) {
              _lastFourCtrl.clear();
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? t.color.withOpacity(0.15)
                  : tc.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? t.color : tc.outlineVariant,
                width: isSelected ? 1 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  t.icon,
                  color: isSelected ? t.color : tc.onSurfaceVariant,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  t.label,
                  style: GoogleFonts.inter(
                    color: isSelected ? t.color : tc.onSurfaceVariant,
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
}
