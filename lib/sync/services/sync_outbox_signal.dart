import 'dart:async';

/// In-process notification that local business data has produced a sync item.
///
/// The database queue remains the durable source. This signal only lets the
/// foreground auto-sync service react immediately instead of waiting for its
/// next periodic queue check.
class SyncOutboxSignal {
  SyncOutboxSignal._();

  static final StreamController<String> _controller =
      StreamController<String>.broadcast(sync: true);

  static Stream<String> get stream => _controller.stream;

  static void notify(String companyId) {
    if (companyId.isNotEmpty && !_controller.isClosed) {
      _controller.add(companyId);
    }
  }
}
