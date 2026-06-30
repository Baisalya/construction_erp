import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_database.dart';

final localDatabaseProvider = Provider<ConstructionDatabase>((ref) {
  final database = ConstructionDatabase(openConstructionDatabaseConnection());
  ref.onDispose(database.close);
  return database;
});
