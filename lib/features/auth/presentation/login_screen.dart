import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_feedback.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_providers.dart';
import '../domain/auth_failure.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.apartment_outlined,
                          size: 52,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Construction ERP Login',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || !value.contains('@')) {
                              return 'Enter valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _sendPasswordReset,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login_outlined),
                          label: const Text('Sign in with Email'),
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: _isGoogleLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  'G',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                          label: const Text('Continue with Google'),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.go('/auth/register-owner'),
                          child: const Text('Create account'),
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
      await ref.read(authRepositoryProvider).signInWithEmailPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (mounted) {
        context.go('/');
      }
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } catch (error) {
      setState(() => _error = friendlyErrorMessage(error,
          fallback: 'Sign-in could not be completed. Please try again.'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _isGoogleLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) {
        context.go('/');
      }
    } on AuthFailure catch (failure) {
      if ((failure.code == AuthFailureCode.googleAccountChoiceRequired ||
              failure.code == AuthFailureCode.accountLinkRequired) &&
          mounted) {
        final linked = await _showGoogleLinkDialog(failure.email);
        if (linked && mounted) {
          context.go('/');
        }
      } else if (mounted) {
        setState(() => _error = failure.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => _ResetPasswordDialogContent(
        initialEmail: _emailController.text,
      ),
    );
    if (email == null || !mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If an account exists for that email, Firebase has sent password reset instructions.',
            ),
          ),
        );
      }
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showGoogleLinkDialog(String? email) async {
    final linked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _GoogleLinkDialogContent(
        email: email,
        ref: ref,
      ),
    );
    return linked == true;
  }
}

class _ResetPasswordDialogContent extends StatefulWidget {
  final String initialEmail;

  const _ResetPasswordDialogContent({required this.initialEmail});

  @override
  State<_ResetPasswordDialogContent> createState() =>
      _ResetPasswordDialogContentState();
}

class _ResetPasswordDialogContentState
    extends State<_ResetPasswordDialogContent> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Account email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (value) => value != null && value.contains('@')
              ? null
              : 'Enter a valid email',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Send reset email'),
        ),
      ],
    );
  }
}

class _GoogleLinkDialogContent extends StatefulWidget {
  final String? email;
  final WidgetRef ref;

  const _GoogleLinkDialogContent({required this.email, required this.ref});

  @override
  State<_GoogleLinkDialogContent> createState() =>
      _GoogleLinkDialogContentState();
}

class _GoogleLinkDialogContentState extends State<_GoogleLinkDialogContent> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _dialogError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Use the correct account'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Selected Google email: ${widget.email ?? 'unknown'}\n\n'
                  'If you previously registered this email with a password, enter that password and link it. This preserves the same company and Firebase user ID. Otherwise continue with Google.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Existing account password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => value == null || value.length < 6
                      ? 'Enter your existing password'
                      : null,
                ),
                if (_dialogError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _dialogError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _dialogError = null;
                  });
                  final navigator = Navigator.of(context);
                  try {
                    await widget.ref
                        .read(authRepositoryProvider)
                        .continueWithPendingGoogleCredential();
                    if (mounted) {
                      navigator.pop(true);
                    }
                  } on AuthFailure catch (failure) {
                    setState(() {
                      _saving = false;
                      _dialogError = failure.message;
                    });
                  } catch (error) {
                    setState(() {
                      _saving = false;
                      _dialogError = friendlyErrorMessage(error);
                    });
                  }
                },
          child: const Text('Continue with Google'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() {
                    _saving = true;
                    _dialogError = null;
                  });
                  final navigator = Navigator.of(context);
                  try {
                    await widget.ref
                        .read(authRepositoryProvider)
                        .linkPendingGoogleCredentialWithPassword(
                          password: _passwordController.text,
                        );
                    if (mounted) {
                      navigator.pop(true);
                    }
                  } on AuthFailure catch (failure) {
                    setState(() {
                      _saving = false;
                      _dialogError = failure.message;
                    });
                  } catch (error) {
                    setState(() {
                      _saving = false;
                      _dialogError = friendlyErrorMessage(error);
                    });
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Link and continue'),
        ),
      ],
    );
  }
}
