import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/app_feedback.dart';
import '../../staff/domain/staff_access_policy.dart';
import '../data/auth_providers.dart';
import '../domain/company_profile.dart';

class CompanySettingsScreen extends ConsumerStatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  ConsumerState<CompanySettingsScreen> createState() =>
      _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends ConsumerState<CompanySettingsScreen> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final policy = user == null
        ? null
        : ref.watch(userAccessPolicyProvider(user)).valueOrNull;
    final companyId = policy?.staff.companyId;
    return Scaffold(
      appBar: AppBar(title: const Text('Company settings')),
      body: companyId == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<CompanyProfile?>(
              key: ValueKey(_refreshKey),
              future: ref
                  .read(companyRepositoryProvider)
                  .readLocalCompany(companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final company = snapshot.data;
                if (company == null) {
                  return const Center(
                    child: Text('Company details are not available.'),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.apartment_outlined),
                        ),
                        title: Text(company.name),
                        subtitle: Text('Company ID: $companyId'),
                        trailing: policy?.isOwnerOrAdmin == true
                            ? FilledButton.icon(
                                onPressed: () => _edit(company, policy!),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          _Detail('GST number', company.gstNumber),
                          _Detail('PAN number', company.panNumber),
                          _Detail('Address', company.address),
                          _Detail('Phone', company.phone),
                          _Detail('Email', company.email),
                        ],
                      ),
                    ),
                    if (!policy!.isOwnerOrAdmin) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Only owner/admin can edit company details.',
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Future<void> _edit(
    CompanyProfile company,
    StaffAccessPolicy policy,
  ) async {
    final result = await showDialog<_CompanyEdit>(
      context: context,
      builder: (context) => _CompanyEditDialog(company: company),
    );
    if (result == null) return;
    try {
      await ref.read(companyRepositoryProvider).updateCompanyProfile(
            actorPolicy: policy,
            companyName: result.name,
            gstNumber: result.gst,
            panNumber: result.pan,
            address: result.address,
            phone: result.phone,
            email: result.email,
          );
      if (mounted) {
        setState(() => _refreshKey++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company details updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error))),
        );
      }
    }
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        subtitle: Text(value?.trim().isNotEmpty == true ? value! : 'Not added'),
      );
}

class _CompanyEditDialog extends StatefulWidget {
  const _CompanyEditDialog({required this.company});

  final CompanyProfile company;

  @override
  State<_CompanyEditDialog> createState() => _CompanyEditDialogState();
}

class _CompanyEditDialogState extends State<_CompanyEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _gst;
  late final TextEditingController _pan;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final company = widget.company;
    _name = TextEditingController(text: company.name);
    _gst = TextEditingController(text: company.gstNumber);
    _pan = TextEditingController(text: company.panNumber);
    _address = TextEditingController(text: company.address);
    _phone = TextEditingController(text: company.phone);
    _email = TextEditingController(text: company.email);
  }

  @override
  void dispose() {
    for (final controller in [_name, _gst, _pan, _address, _phone, _email]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit company details'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Company name *',
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Company name is required.'
                        : null,
                  ),
                  TextFormField(
                    controller: _gst,
                    decoration: const InputDecoration(labelText: 'GST number'),
                  ),
                  TextFormField(
                    controller: _pan,
                    decoration: const InputDecoration(labelText: 'PAN number'),
                  ),
                  TextFormField(
                    controller: _address,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => value?.trim().isNotEmpty == true &&
                            !value!.contains('@')
                        ? 'Enter a valid email address.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                _CompanyEdit(
                  name: _name.text.trim(),
                  gst: _gst.text.trim(),
                  pan: _pan.text.trim(),
                  address: _address.text.trim(),
                  phone: _phone.text.trim(),
                  email: _email.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class _CompanyEdit {
  const _CompanyEdit({
    required this.name,
    required this.gst,
    required this.pan,
    required this.address,
    required this.phone,
    required this.email,
  });

  final String name;
  final String gst;
  final String pan;
  final String address;
  final String phone;
  final String email;
}
