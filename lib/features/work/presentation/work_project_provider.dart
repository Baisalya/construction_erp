import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../project/domain/project_record.dart';

final workProjectsProvider =
    FutureProvider.autoDispose<List<ProjectRecord>>((ref) async {
  final repository = ref.watch(projectRepositoryProvider);
  final writeContext = ref.watch(localWriteContextProvider);
  return repository.listProjects(writeContext.companyId);
});
