import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_feedback.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_providers.dart';
import '../domain/app_user.dart';

class CompanySetupScreen extends ConsumerStatefulWidget {
  const CompanySetupScreen({super.key});

  @override
  ConsumerState<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends ConsumerState<CompanySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _financialYearStartController =
      TextEditingController(text: DateTime.now().year.toString());
  final _financialYearEndController =
      TextEditingController(text: (DateTime.now().year + 1).toString());
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _financialYearStartController.dispose();
    _financialYearEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company setup'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create your construction company profile',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This creates local company records first, then Firebase company/staff metadata. Tender, project and billing data still remain local-first.',
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Company name *',
                            prefixIcon: Icon(Icons.apartment_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Company name is required'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          runSpacing: 12,
                          spacing: 12,
                          children: [
                            SizedBox(
                              width: 320,
                              child: TextFormField(
                                controller: _gstController,
                                decoration: const InputDecoration(
                                    labelText: 'GST number'),
                              ),
                            ),
                            SizedBox(
                              width: 320,
                              child: TextFormField(
                                controller: _panController,
                                decoration: const InputDecoration(
                                    labelText: 'PAN number'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          runSpacing: 12,
                          spacing: 12,
                          children: [
                            SizedBox(
                              width: 320,
                              child: TextFormField(
                                controller: _financialYearStartController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Financial year starts (year)',
                                ),
                                validator: _validateYear,
                              ),
                            ),
                            SizedBox(
                              width: 320,
                              child: TextFormField(
                                controller: _financialYearEndController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Financial year ends (year)',
                                ),
                                validator: _validateYear,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          runSpacing: 12,
                          spacing: 12,
                          children: [
                            SizedBox(
                              width: 320,
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration:
                                    const InputDecoration(labelText: 'Phone'),
                              ),
                            ),
                            SizedBox(
                              width: 320,
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                    labelText: 'Company email'),
                              ),
                            ),
                          ],
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
                          onPressed:
                              _isLoading || user == null ? null : _submit,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Create company'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isLoading || user == null
                              ? null
                              : () => _showJoinDialog(user),
                          icon: const Icon(Icons.group_add_outlined),
                          label: const Text('Join company with invite code'),
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

  Future<void> _showJoinDialog(AppUser user) async {
    final companyIdController = TextEditingController();
    final inviteCodeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? dialogError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Join your company'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ask the owner for the Company ID and invite code. Sign in with the invited email address.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: companyIdController,
                      decoration:
                          const InputDecoration(labelText: 'Company ID'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Company ID is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: inviteCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration:
                          const InputDecoration(labelText: 'Invite code'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Invite code is required'
                              : null,
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await ref
                            .read(companyRepositoryProvider)
                            .acceptInvitation(
                              user: user,
                              companyId: companyIdController.text,
                              inviteCode: inviteCodeController.text,
                            );
                        ref.invalidate(userAccessPolicyProvider(user));
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (!mounted) return;
                        this.context.go('/');
                      } catch (error) {
                        setDialogState(() {
                          saving = false;
                          dialogError = friendlyErrorMessage(error);
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join company'),
            ),
          ],
        ),
      ),
    );
    companyIdController.dispose();
    inviteCodeController.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      setState(() => _error = 'Login again before creating company.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final startYear = int.parse(_financialYearStartController.text);
      final endYear = int.parse(_financialYearEndController.text);
      await ref.read(companyRepositoryProvider).createOwnerCompany(
            owner: user,
            companyName: _nameController.text,
            gstNumber: _gstController.text,
            panNumber: _panController.text,
            address: _addressController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            financialYearStart:
                DateTime(startYear, DateTime.april).millisecondsSinceEpoch,
            financialYearEnd:
                DateTime(endYear, DateTime.march, 31).millisecondsSinceEpoch,
          );
      ref.invalidate(userAccessPolicyProvider(user));
      if (mounted) {
        context.go('/');
      }
    } catch (error) {
      setState(() => _error = friendlyErrorMessage(error,
          fallback: 'The company could not be saved. Please try again.'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateYear(String? value) {
    final year = int.tryParse(value ?? '');
    if (year == null || year < 2000 || year > 2200) {
      return 'Enter a four-digit year';
    }
    return null;
  }
}
