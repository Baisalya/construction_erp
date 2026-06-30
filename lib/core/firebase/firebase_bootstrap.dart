class FirebaseBootstrapResult {
  const FirebaseBootstrapResult._({
    required this.isReady,
    this.errorMessage,
    this.stackTrace,
  });

  const FirebaseBootstrapResult.ready() : this._(isReady: true);

  factory FirebaseBootstrapResult.failed(Object error, StackTrace stackTrace) {
    return FirebaseBootstrapResult._(
      isReady: false,
      errorMessage: error.toString(),
      stackTrace: stackTrace,
    );
  }

  final bool isReady;
  final String? errorMessage;
  final StackTrace? stackTrace;
}
