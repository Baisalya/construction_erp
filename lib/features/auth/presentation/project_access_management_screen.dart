import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/permission_key.dart';
import '../data/auth_providers.dart';
import '../../staff/presentation/staff_page.dart';
import 'access_denied_screen.dart';

class ProjectAccessManagementScreen extends ConsumerWidget {
  const ProjectAccessManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(permissionServiceProvider).valueOrNull;
    if (!(service?.can(PermissionKey.staffManagement) ?? false)) {
      return const AccessDeniedScreen(
        message: 'Only owner/admin can assign staff to projects.',
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Project access')),
      body: const StaffPage(),
    );
  }
}
