import 'package:flutter/material.dart';

class FirebaseSetupErrorScreen extends StatelessWidget {
  const FirebaseSetupErrorScreen({
    required this.errorMessage,
    super.key,
  });

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Firebase setup needed',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(errorMessage),
                      const SizedBox(height: 16),
                      const Text(
                        'Run flutterfire configure for Android and Windows, then replace lib/firebase_options.dart. Business data remains local-first; Firebase is only for auth, company, staff and permission metadata in Phase 6.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Access is not bypassed when Firebase initialization fails. Restart the app after fixing configuration.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
