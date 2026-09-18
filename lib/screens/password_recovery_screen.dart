import 'package:flutter/material.dart';
import '../auth/recovery_service.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    required this.service,
    this.resetSession = false,
    this.onFinished,
  });
  final RecoveryService service;
  final bool resetSession;
  final Future<void> Function()? onFinished;
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _updated = false;
  String? _message;
  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (widget.resetSession) {
        await widget.service.updatePassword(_password.text);
        if (mounted) {
          setState(() {
            _updated = true;
            _message = 'Password updated. Sign in with your new password.';
          });
        }
        _password.clear();
        _confirm.clear();
      } else {
        await widget.service.sendResetEmail(_email.text.trim().toLowerCase());
        if (mounted) {
          setState(
            () => _message =
                'If an account exists for this email, a reset link will arrive. Open it on this device.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = widget.resetSession
              ? 'Unable to update your password. Try again or request a new reset link.'
              : 'Unable to send the reset request. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onFinished != null) {
        await widget.onFinished!();
      } else if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Reset password'),
      automaticallyImplyLeading: !widget.resetSession,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_updated && !widget.resetSession)
                  TextFormField(
                    key: const Key('recovery-email'),
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'University email',
                    ),
                    validator: (v) =>
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch((v ?? '').trim())
                        ? null
                        : 'Enter a valid email address.',
                  ),
                if (!_updated && widget.resetSession) ...[
                  TextFormField(
                    key: const Key('recovery-password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    validator: (v) => (v ?? '').length >= 12
                        ? null
                        : 'Use at least 12 characters.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('recovery-confirm'),
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                    ),
                    validator: (v) =>
                        v == _password.text ? null : 'Passwords must match.',
                  ),
                ],
                const SizedBox(height: 24),
                if (_message != null)
                  Semantics(liveRegion: true, child: Text(_message!)),
                const SizedBox(height: 16),
                if (!_updated)
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Please wait…'
                          : widget.resetSession
                          ? 'Update password'
                          : 'Send reset link',
                    ),
                  ),
                TextButton(
                  onPressed: _busy ? null : _finish,
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
