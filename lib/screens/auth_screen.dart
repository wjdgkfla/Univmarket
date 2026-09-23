import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../widgets/brand_mark.dart';
import '../auth/auth_service.dart';
import '../auth/recovery_service.dart';
import 'password_recovery_screen.dart';

/// Launch schools. Mirrors `university_domains` (exact domain match), which
/// the server enforces; this only gives an early, clear error.
const launchEmailDomains = {'gmu.edu', 'gwu.edu'};

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.auth,
    this.recovery,
    this.showWelcome = false,
  });
  final AuthService auth;
  final RecoveryService? recovery;
  final bool showWelcome;
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
  late bool _welcome = widget.showWelcome;

  Widget _welcomePage(BuildContext context) {
    final c = context.colors;
    const photos = [
      'assets/images/books.jpg',
      'assets/images/headphones.jpg',
      'assets/images/chair.jpg',
      'assets/images/bike.jpg',
      'assets/images/lamp.jpg',
      'assets/images/bag.jpg',
    ];
    Widget school(String name, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Lockup(),
                  const SizedBox(height: 20),
                  ExcludeSemantics(
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final path in photos)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.photo,
                            ),
                            child: Image.asset(
                              path,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  ColoredBox(color: c.surface2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Welcome to UnivMarket',
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Buy and sell with students at your school. Your university email connects you to your campus marketplace.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: c.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 22),
                  school(
                    'George Mason University',
                    schoolColors['GMU']!.accent,
                  ),
                  school(
                    'George Washington University',
                    schoolColors['GWU']!.accent,
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => setState(() {
                      _welcome = false;
                      _register = true;
                    }),
                    child: const Text('Create account'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _welcome = false;
                      _register = false;
                    }),
                    child: const Text('Sign in'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Use your @gmu.edu or @gwu.edu email to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: c.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
                'We sent a confirmation link to $email. Open it, then sign in here. Check your spam folder if you don\'t see it.';
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
  Widget build(BuildContext context) => _welcome
      ? _welcomePage(context)
      : Scaffold(
          appBar: widget.showWelcome
              ? AppBar(
                  leading: IconButton(
                    tooltip: 'Back to welcome',
                    icon: const Icon(CupertinoIcons.chevron_back),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _welcome = true),
                  ),
                )
              : null,
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
                          const _Lockup(),
                          const SizedBox(height: 28),
                          Text(
                            _register ? 'Create your account' : 'Welcome back',
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: context.colors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _register
                                ? 'Create your account with your @gmu.edu or @gwu.edu email.'
                                : 'Sign in with your @gmu.edu or @gwu.edu email.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: context.colors.inkSoft,
                            ),
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
                            validator: (value) {
                              final email = (value ?? '').trim().toLowerCase();
                              if (!RegExp(
                                r'^[^\s@]+@[^\s@]+$',
                              ).hasMatch(email)) {
                                return 'Enter a valid email address.';
                              }
                              return launchEmailDomains.contains(
                                    email.split('@')[1],
                                  )
                                  ? null
                                  : 'Use your @gmu.edu or @gwu.edu email.';
                            },
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
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
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
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface2,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.control,
                                    ),
                                  ),
                                  child: Text(
                                    _message!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (!_register && widget.recovery != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PasswordRecoveryScreen(
                                                service: widget.recovery!,
                                              ),
                                        ),
                                      ),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          const SizedBox(height: 8),
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

/// App icon plus name, used at the top of the signed-out screens.
class _Lockup extends StatelessWidget {
  const _Lockup();
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: 'UnivMarket',
    excludeSemantics: true,
    child: Row(
      children: [
        const AppIconTile(size: 36),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'UnivMarket',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: context.colors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}
