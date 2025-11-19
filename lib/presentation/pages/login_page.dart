// lib/presentation/pages/login_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofgconnects_mobile/logic/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isLoginView = true;
  String? _error;
  bool _isLoading = false;

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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifier = ref.read(authProvider.notifier);
      if (_isLoginView) {
        await notifier.loginUser(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await notifier.registerUser(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
        );
      }
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027), 
              Color(0xFF203A43), 
              Color(0xFF2C5364)
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                    ]
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 50, color: Colors.blueAccent),
                        const SizedBox(height: 16),
                        Text(
                          _isLoginView ? 'Welcome Back!' : 'Join OFG',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLoginView ? 'Log in to continue' : 'Connect with your community',
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 32),

                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                            ),
                            child: Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                          ),

                        if (!_isLoginView) ...[
                          _buildTextField(_nameController, 'Full Name', Icons.person_outline),
                          const SizedBox(height: 16),
                        ],

                        _buildTextField(_emailController, 'Email Address', Icons.email_outlined),
                        const SizedBox(height: 16),
                        _buildTextField(_passwordController, 'Password', Icons.lock_outline, isObscure: true),
                        
                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shadowColor: Colors.blueAccent.withOpacity(0.5),
                              elevation: 8,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(_isLoginView ? 'Log In' : 'Sign Up', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text('OR', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                            ),
                            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                          ],
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleLogin,
                            icon: const Icon(Icons.g_mobiledata, size: 28), 
                            label: const Text('Continue with Google'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLoginView = !_isLoginView;
                              _error = null;
                            });
                          },
                          child: Text(
                            _isLoginView ? "Don't have an account? Sign Up" : 'Already have an account? Log In',
                            style: const TextStyle(color: Colors.blueAccent),
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
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isObscure = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
      validator: (val) => val!.isEmpty ? 'Required' : null,
    );
  }
}