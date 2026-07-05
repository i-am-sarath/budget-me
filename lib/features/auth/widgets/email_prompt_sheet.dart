import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pi/core/theme.dart';
import 'package:money_pi/core/services/user_service.dart';

// Returns true if user registered, false if dismissed
Future<bool> showEmailPrompt(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const EmailPromptSheet(),
  );
  return result == true;
}

class EmailPromptSheet extends ConsumerStatefulWidget {
  const EmailPromptSheet({super.key});
  @override
  ConsumerState<EmailPromptSheet> createState() => _EmailPromptSheetState();
}

class _EmailPromptSheetState extends ConsumerState<EmailPromptSheet> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await ref.read(userProvider.notifier).register(_emailCtrl.text);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppThemeColors.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 32),
      decoration: BoxDecoration(
        color: tc.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: tc.outlineVariant, width: 0.5),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: tc.outlineVariant,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            // Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tc.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.mic_rounded, color: tc.primary, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Enable Voice Logging',
              style: AppFonts.sans(
                color: tc.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your email to activate voice-powered transaction logging. Free users get 100 logs/month.',
              style: AppFonts.sans(
                color: tc.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: AppFonts.sans(color: tc.onSurface, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined, color: tc.onSurfaceVariant, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tc.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tc.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tc.primary, width: 1.5),
                ),
                filled: true,
                fillColor: tc.surfaceContainerHigh,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your email';
                if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tc.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        'Get Started',
                        style: AppFonts.sans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Use Manual Entry Instead',
                  style: AppFonts.sans(
                    color: tc.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
