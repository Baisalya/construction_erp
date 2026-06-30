import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/construction_erp_app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'features/auth/data/auth_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseBootstrapResult firebaseState;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseState = const FirebaseBootstrapResult.ready();
  } catch (error, stackTrace) {
    firebaseState = FirebaseBootstrapResult.failed(error, stackTrace);
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseBootstrapProvider.overrideWithValue(firebaseState),
      ],
      child: const ConstructionErpApp(),
    ),
  );
}
