// lib/presentation/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

// Use ConsumerStatefulWidget to access Riverpod providers
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // This is your 'isLoginView' state
  bool _isLoginView = true;
  // This is your 'error' state
  String? _error;
  bool _isLoading = false;

  // Form controllers, just like React's useState for inputs
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // This is your 'handleSubmit' function
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return; // Form validation
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifier = ref.read(authProvider.notifier);
      if (_isLoginView) {
        // Call login function
        await notifier.loginUser(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        // Call register function
        await notifier.registerUser(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
        );
      }
      // No need to navigate, the AuthGate will handle it!
      
    } catch (e) {
      // Set the error message
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // This is your 'handleGoogleLogin' function
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
        await ref.read(authProvider.notifier).googleLogin();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
       setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is your UI from LoginPage.js
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Text
                Text(
                  _isLoginView ? 'Welcome Back!' : 'Create Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  _isLoginView ? 'Log in to continue.' : 'Sign up to get started.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 16),

                // Name Field (conditionally rendered)
                if (!_isLoginView)
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter your name' : null,
                  ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter your email' : null,
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) =>
                      value!.length < 8 ? 'Password must be 8+ chars' : null,
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Text(_isLoginView ? 'Log In' : 'Sign Up'),
                ),
                const SizedBox(height: 16),

                // Divider
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Google Login Button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  icon: const Icon(Icons.g_mobiledata), // Placeholder for Google Icon
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // Toggle View Button
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginView = !_isLoginView;
                      _error = null; // Clear error on toggle
                    });
                  },
                  child: Text(
                    _isLoginView
                        ? "Don't have an account? Sign Up"
                        : 'Already have an account? Log In',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}