import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/recovery_service.dart';
import 'password_recovery_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth, this.recovery});
  final AuthService auth;
  final RecoveryService? recovery;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _message;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final registering = _register;
    try {
      final email = _email.text.trim().toLowerCase();
      if (registering) {
        await widget.auth.signUp(email, _password.text);
        if (mounted) {
          setState(() {
            _message =
                'Check your email to confirm your account, then sign in. Your university membership will be checked separately.';
            _register = false;
            _password.clear();
          });
        }
      } else {
        await widget.auth.signIn(email, _password.text);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = registering
              ? 'Unable to create an account. Check your connection and try again.'
              : 'Unable to sign in. Check your credentials, email confirmation, and connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.storefront_outlined, size: 48),
                    const SizedBox(height: 20),
                    Text(
                      'UnivMarket',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your campus marketplace. Use your university email to get started.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const Key('auth-email'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'University email',
                      ),
                      validator: (value) =>
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch((value ?? '').trim())
                          ? null
                          : 'Enter a valid email address.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('auth-password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autocorrect: false,
                      autofillHints: [
                        _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: const InputDecoration(labelText: 'Password'),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => (value ?? '').isEmpty
                          ? 'Enter your password.'
                          : (_register && value!.length < 12
                                ? 'Use at least 12 characters.'
                                : null),
                    ),
                    const SizedBox(height: 24),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_message!),
                        ),
                      ),
                    if (!_register && widget.recovery != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PasswordRecoveryScreen(
                                    service: widget.recovery!,
                                  ),
                                ),
                              ),
                        child: const Text('Forgot password?'),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Please wait…'
                            : (_register ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _register = !_register;
                              _message = null;
                            }),
                      child: Text(
                        _register
                            ? 'Already have an account? Sign in'
                            : 'Create an account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
