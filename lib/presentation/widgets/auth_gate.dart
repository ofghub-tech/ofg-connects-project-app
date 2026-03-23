import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ofgconnects/logic/auth_provider.dart';
import 'package:ofgconnects/presentation/theme/ofg_ui.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _setupPasswordController = TextEditingController();
  final _confirmSetupPasswordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _setupPasswordController.dispose();
    _confirmSetupPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated &&
          !next.requiresPasswordSetup) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: OfgUi.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: OfgUi.appBackground),
        child: SafeArea(
          child: authState.status == AuthStatus.loading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: OfgUi.accent),
                      SizedBox(height: 14),
                      Text('Connecting...',
                          style: TextStyle(color: OfgUi.muted2)),
                    ],
                  ),
                )
              : authState.requiresPasswordSetup
                  ? _buildPasswordSetup()
                  : _buildAuthForm(authState.errorMessage),
        ),
      ),
    );
  }

  Widget _buildAuthForm(String? errorMessage) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: OfgUi.cardDecoration(elevated: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'OFG Connects',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp ? 'Create your account' : 'Sign in to continue',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: OfgUi.muted2),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                        child: _authTab('Sign In', !_isSignUp,
                            () => setState(() => _isSignUp = false))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _authTab('Sign Up', _isSignUp,
                            () => setState(() => _isSignUp = true))),
                  ],
                ),
                const SizedBox(height: 14),
                if (_isSignUp) ...[
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () async {
                    final email = _emailController.text.trim();
                    final password = _passwordController.text.trim();
                    if (email.isEmpty || password.isEmpty) return;
                    final emailOk =
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                    if (!emailOk) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Enter a valid email address.')),
                      );
                      return;
                    }

                    if (_isSignUp) {
                      if (password.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Password must be at least 8 characters.')),
                        );
                        return;
                      }
                      await ref
                          .read(authProvider.notifier)
                          .registerWithEmailPassword(
                            name: _nameController.text.trim(),
                            email: email,
                            password: password,
                          );
                    } else {
                      await ref
                          .read(authProvider.notifier)
                          .loginWithEmailPassword(
                            email: email,
                            password: password,
                          );
                    }
                  },
                  child: Text(_isSignUp ? 'Create Account' : 'Login'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authProvider.notifier).googleLogin(),
                  icon: const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordSetup() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: OfgUi.cardDecoration(elevated: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You signed in with Google. Set a password now so you can also login with email + password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: OfgUi.muted2, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _setupPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmSetupPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm Password'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final password = _setupPasswordController.text.trim();
                    final confirm = _confirmSetupPasswordController.text.trim();
                    if (password.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Password must be at least 8 characters.')),
                      );
                      return;
                    }
                    if (password != confirm) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Passwords do not match.')),
                      );
                      return;
                    }

                    await ref
                        .read(authProvider.notifier)
                        .completePasswordSetupForGoogle(password);
                  },
                  child: const Text('Save Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _authTab(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? OfgUi.accent : OfgUi.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? OfgUi.accentHover : OfgUi.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : OfgUi.muted2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
