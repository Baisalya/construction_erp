import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class FirebaseSetupErrorScreen extends StatelessWidget {
  const FirebaseSetupErrorScreen({
    required this.errorMessage,
    this.title = 'Cloud sign-in is unavailable',
    this.userMessage =
        'The app could not connect to the sign-in service. Check your internet connection and restart the app. Your existing local company data has not been removed.',
    super.key,
  });

  final String errorMessage;
  final String title;
  final String userMessage;

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
                              title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(userMessage),
                      if (kDebugMode) ...[
                        const SizedBox(height: 16),
                        Text('Developer details: $errorMessage'),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'If this continues, ask your administrator to check the app configuration.',
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
