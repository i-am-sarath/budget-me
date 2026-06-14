import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agent_money/core/theme.dart';
import 'package:agent_money/core/services/auth_service.dart';
import 'package:agent_money/core/services/cloud_service.dart';

/// Gate used everywhere a real account is required (voice, Google Sheets,
/// Spaces). Manual entry never calls this.
///
/// Returns true if the user already has an account or completes sign-in, false
/// if they dismiss. Pass a [reason] to tailor the sheet's subtitle, e.g.
/// "Sign in to log by voice".
Future<bool> requireAccount(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  if (ref.read(authProvider).signedIn) return true;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AccountSheet(reason: reason),
  );
  return ok == true;
}

/// Smooth, single-sheet sign-in: Google + passwordless email code.
class AccountSheet extends ConsumerStatefulWidget {
  final String reason;
  const AccountSheet({super.key, required this.reason});

  @override
  ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

enum _Step { choose, code }

class _AccountSheetState extends ConsumerState<AccountSheet> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _Step _step = _Step.choose;
  bool _loading = false;
  String? _error;

  bool get _cloud => CloudService.isReady;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (mounted) Navigator.pop(context, true);
    } on CloudException catch (e) {
      // A user-cancelled sign-in shouldn't read like an error.
      final msg = e.message.toLowerCase();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = msg.contains('cancel') ? null : e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Google sign-in failed. Try again.';
        });
      }
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailCtrl.text.trim();
    try {
      if (_cloud) {
        // Real backend: send a 6-digit code, then move to the verify step.
        await ref.read(authProvider.notifier).sendEmailCode(email);
        if (mounted) {
          setState(() {
            _loading = false;
            _step = _Step.code;
          });
        }
      } else {
        // Local fallback: no code to send — register the email and finish.
        await ref.read(authProvider.notifier).verifyEmailCode(email, '');
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Couldn\'t send a code. Check the email and try again.';
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(authProvider.notifier)
          .verifyEmailCode(_emailCtrl.text.trim(), code);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _loading = false;
          _error = 'That code didn\'t match. Try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Invalid or expired code. Request a new one.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 14, 24, bottom + 28),
      decoration: BoxDecoration(
        color: tc.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: tc.outlineVariant,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tc.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _step == _Step.code
                  ? Icons.mark_email_unread_rounded
                  : Icons.lock_outline_rounded,
              color: tc.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _step == _Step.code ? 'Check your email' : 'Create your account',
            style: AppFonts.sans(
              color: tc.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _step == _Step.code
                ? 'Enter the 6-digit code we sent to ${_emailCtrl.text.trim()}.'
                : widget.reason,
            style: AppFonts.sans(
              color: tc.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          if (_step == _Step.choose) ..._chooseBody(tc) else ..._codeBody(tc),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: AppFonts.sans(color: tc.error, fontSize: 12.5, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      if (_step == _Step.code) {
                        setState(() {
                          _step = _Step.choose;
                          _error = null;
                        });
                      } else {
                        Navigator.pop(context, false);
                      }
                    },
              child: Text(
                _step == _Step.code ? 'Use a different email' : 'Not now',
                style: AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _chooseBody(AppThemeColors tc) {
    return [
      if (_cloud) ...[
        _GoogleButton(onTap: _loading ? null : _google, tc: tc),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: tc.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or',
                  style:
                      AppFonts.sans(color: tc.onSurfaceVariant, fontSize: 12)),
            ),
            Expanded(child: Divider(color: tc.outlineVariant)),
          ],
        ),
        const SizedBox(height: 16),
      ],
      Form(
        key: _formKey,
        child: TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: !_cloud,
          enabled: !_loading,
          style: AppFonts.sans(color: tc.onSurface, fontSize: 15),
          decoration: _fieldDecoration(tc, 'Email address',
              Icon(Icons.email_outlined, color: tc.onSurfaceVariant, size: 20)),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your email';
            if (!v.contains('@') || !v.contains('.')) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
      ),
      const SizedBox(height: 14),
      _PrimaryButton(
        label: _cloud ? 'Continue with email' : 'Continue',
        loading: _loading,
        onTap: _loading ? null : _submitEmail,
        tc: tc,
      ),
    ];
  }

  List<Widget> _codeBody(AppThemeColors tc) {
    return [
      TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        enabled: !_loading,
        maxLength: 6,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppFonts.sans(
          color: tc.onSurface,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: 8,
        ),
        decoration: _fieldDecoration(tc, '••••••', null).copyWith(
          counterText: '',
        ),
      ),
      const SizedBox(height: 14),
      _PrimaryButton(
        label: 'Verify & continue',
        loading: _loading,
        onTap: _loading ? null : _verifyCode,
        tc: tc,
      ),
    ];
  }

  InputDecoration _fieldDecoration(
      AppThemeColors tc, String label, Widget? prefix) {
    return InputDecoration(
      labelText: prefix == null ? null : label,
      hintText: prefix == null ? label : null,
      prefixIcon: prefix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tc.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tc.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tc.primary, width: 1.5),
      ),
      filled: true,
      fillColor: tc.surfaceContainerHigh,
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final AppThemeColors tc;
  const _GoogleButton({required this.onTap, required this.tc});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: tc.outlineVariant),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Text('G',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF4285F4))),
        label: Text(
          'Continue with Google',
          style: AppFonts.sans(
              color: tc.onSurface, fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final AppThemeColors tc;
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: tc.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(label,
                style:
                    AppFonts.sans(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}
