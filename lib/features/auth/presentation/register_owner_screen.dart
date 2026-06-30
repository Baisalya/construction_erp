import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_providers.dart';
import '../domain/auth_failure.dart';

class RegisterOwnerScreen extends ConsumerStatefulWidget {
  const RegisterOwnerScreen({super.key});

  @override
  ConsumerState<RegisterOwnerScreen> createState() =>
      _RegisterOwnerScreenState();
}

class _RegisterOwnerScreenState extends ConsumerState<RegisterOwnerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create your login, then create a company as owner or join an existing company with an invite code.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) =>
                              value != null && value.contains('@')
                                  ? null
                                  : 'Enter valid email',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) =>
                              value != null && value.length >= 6
                                  ? null
                                  : 'Minimum 6 characters',
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: const Icon(Icons.person_add_alt_outlined),
                          label: const Text('Create account'),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.go('/auth/login'),
                          child: const Text('Already have account? Login'),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).registerOwnerWithEmailPassword(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _nameController.text,
          );
      if (mounted) {
        context.go('/company/setup');
      }
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
