import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/sync_models.dart';
import 'sync_outbox_signal.dart';

typedef AutoSyncRunner = Future<SyncRunResult> Function(SyncContext context);
typedef PendingSyncCounter = Future<int> Function(String companyId);
typedef SyncScopeLoader = Future<SyncDownloadScope> Function(
  SyncContext context,
);
typedef RemoteChangeWatcher = Stream<void> Function(
  String companyId,
  SyncDownloadScope scope,
);
typedef AutoSyncCompleted = void Function(
  SyncContext context,
  SyncRunResult result,
);

enum AutoSyncPhase { stopped, checking, upToDate, offline, attention }

class AutoSyncController extends ChangeNotifier {
  AutoSyncController({
    required AutoSyncRunner runSync,
    required PendingSyncCounter pendingCount,
    required SyncScopeLoader loadScope,
    required RemoteChangeWatcher watchRemoteChanges,
    AutoSyncCompleted? onCompleted,
    Stream<String>? outboxSignals,
    this.queueCheckInterval = const Duration(seconds: 8),
    this.saveDebounce = const Duration(milliseconds: 700),
    this.fullCheckEveryTicks = 8,
  })  : _runSync = runSync,
        _pendingCount = pendingCount,
        _loadScope = loadScope,
        _watchRemoteChanges = watchRemoteChanges,
        _onCompleted = onCompleted,
        _outboxSignals = outboxSignals ?? SyncOutboxSignal.stream;

  final AutoSyncRunner _runSync;
  final PendingSyncCounter _pendingCount;
  final SyncScopeLoader _loadScope;
  final RemoteChangeWatcher _watchRemoteChanges;
  final AutoSyncCompleted? _onCompleted;
  final Stream<String> _outboxSignals;
  final Duration queueCheckInterval;
  final Duration saveDebounce;
  final int fullCheckEveryTicks;

  SyncContext? _context;
  StreamSubscription<String>? _outboxSubscription;
  StreamSubscription<void>? _remoteSubscription;
  Timer? _periodicTimer;
  Timer? _saveTimer;
  Future<SyncRunResult>? _inFlight;
  bool _runAgain = false;
  bool _paused = false;
  bool _disposed = false;
  bool _recovering = false;
  int _generation = 0;
  int _tick = 0;
  int _consecutiveFailures = 0;
  DateTime? _retryAfter;

  AutoSyncPhase phase = AutoSyncPhase.stopped;
  String message = 'Automatic updating is starting.';
  DateTime? lastSuccessfulSync;
  SyncRunResult? lastResult;

  String get companyId => _context?.companyId ?? '';
  bool get isRunning => _inFlight != null;

  Future<void> start(
    SyncContext context, {
    bool syncImmediately = true,
  }) async {
    final sameContext = _sameContext(_context, context);
    if (sameContext && !_paused && _periodicTimer != null) return;

    await _cancelRuntime();
    _context = context;
    _paused = false;
    _recovering = false;
    _consecutiveFailures = 0;
    _retryAfter = null;
    _tick = 0;
    final generation = ++_generation;

    _outboxSubscription = _outboxSignals.listen((changedCompanyId) {
      if (changedCompanyId != context.companyId || _paused) return;
      _saveTimer?.cancel();
      _saveTimer = Timer(saveDebounce, () => _requestSync(force: true));
    });
    _periodicTimer = Timer.periodic(
      queueCheckInterval,
      (_) => unawaited(_periodicCheck(generation)),
    );
    unawaited(_attachRemoteListener(context, generation));

    _setState(
      AutoSyncPhase.checking,
      'Checking for company updates...',
    );
    if (syncImmediately) _requestSync(force: true);
  }

  Future<SyncRunResult> syncNow(SyncContext context) async {
    if (!_sameContext(_context, context) || _paused) {
      await start(context, syncImmediately: false);
    }
    return _execute(force: true);
  }

  Future<void> pause() async {
    if (_paused) return;
    _paused = true;
    ++_generation;
    await _cancelRuntime();
    _setState(AutoSyncPhase.stopped, 'Updates paused while the app is hidden.');
  }

  Future<void> resume() async {
    final context = _context;
    if (context == null) return;
    await start(context);
  }

  Future<void> stop() async {
    _paused = false;
    _context = null;
    ++_generation;
    await _cancelRuntime();
    _setState(AutoSyncPhase.stopped, 'Automatic updating is off.');
  }

  Future<void> _attachRemoteListener(
    SyncContext context,
    int generation,
  ) async {
    try {
      final scope = await _loadScope(context);
      if (_disposed || _paused || generation != _generation) return;
      await _remoteSubscription?.cancel();
      _remoteSubscription =
          _watchRemoteChanges(context.companyId, scope).listen(
        (_) => _requestSync(force: true),
        onError: (Object error, StackTrace stackTrace) {
          _recordFailure(error);
        },
        onDone: () {
          if (!_paused && generation == _generation) {
            _recovering = true;
          }
        },
      );
    } catch (error) {
      if (generation == _generation) _recordFailure(error);
    }
  }

  Future<void> _periodicCheck(int generation) async {
    if (_disposed || _paused || generation != _generation || _context == null) {
      return;
    }
    final now = DateTime.now();
    if (_retryAfter != null && now.isBefore(_retryAfter!)) return;

    _tick++;
    if (_recovering) {
      _recovering = false;
      await _attachRemoteListener(_context!, generation);
      _requestSync(force: true);
      return;
    }

    try {
      final pending = await _pendingCount(_context!.companyId);
      if (pending > 0 ||
          (fullCheckEveryTicks > 0 && _tick % fullCheckEveryTicks == 0)) {
        _requestSync(force: pending > 0);
      }
    } catch (error) {
      _recordFailure(error);
    }
  }

  void _requestSync({required bool force}) {
    if (_disposed || _paused || _context == null) return;
    if (_inFlight != null) {
      _runAgain = true;
      return;
    }
    unawaited(
      _execute(force: force).then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      ),
    );
  }

  Future<SyncRunResult> _execute({required bool force}) {
    final existing = _inFlight;
    if (existing != null) {
      _runAgain = true;
      return existing;
    }
    final context = _context;
    if (context == null) {
      return Future<SyncRunResult>.error(
        StateError('Automatic sync has no active company.'),
      );
    }
    if (!force &&
        _retryAfter != null &&
        DateTime.now().isBefore(_retryAfter!)) {
      return Future<SyncRunResult>.error(
        StateError('Automatic sync is waiting before retrying.'),
      );
    }

    _setState(AutoSyncPhase.checking, 'Updating company data...');
    late final Future<SyncRunResult> operation;
    operation = _runSync(context).then((result) {
      _consecutiveFailures = 0;
      _retryAfter = null;
      _recovering = false;
      lastSuccessfulSync = DateTime.now();
      lastResult = result;
      if (result.failed > 0 || result.conflicts > 0) {
        _setState(
          AutoSyncPhase.attention,
          result.conflicts > 0
              ? '${result.conflicts} item${result.conflicts == 1 ? '' : 's'} need review.'
              : '${result.failed} item${result.failed == 1 ? '' : 's'} could not update.',
        );
      } else {
        _setState(AutoSyncPhase.upToDate, 'Company data is up to date.');
      }
      _onCompleted?.call(context, result);
      return result;
    }, onError: (Object error, StackTrace stackTrace) {
      _recordFailure(error);
      Error.throwWithStackTrace(error, stackTrace);
    }).whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
      final runAgain = _runAgain;
      _runAgain = false;
      if (runAgain) _requestSync(force: true);
    });
    _inFlight = operation;
    return operation;
  }

  void _recordFailure(Object error) {
    _consecutiveFailures++;
    _recovering = true;
    final delaySeconds = math.min(
      60,
      queueCheckInterval.inSeconds *
          math.pow(2, math.min(_consecutiveFailures - 1, 3)).toInt(),
    );
    _retryAfter = DateTime.now().add(Duration(seconds: delaySeconds));
    final text = error.toString().toLowerCase();
    final offline = text.contains('network') ||
        text.contains('unavailable') ||
        text.contains('timeout') ||
        text.contains('socket');
    _setState(
      offline ? AutoSyncPhase.offline : AutoSyncPhase.attention,
      offline
          ? 'Offline — saved work will retry automatically.'
          : 'Automatic update needs attention. Local work is safe.',
    );
  }

  Future<void> _cancelRuntime() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _saveTimer?.cancel();
    _saveTimer = null;
    await _outboxSubscription?.cancel();
    _outboxSubscription = null;
    await _remoteSubscription?.cancel();
    _remoteSubscription = null;
  }

  bool _sameContext(SyncContext? left, SyncContext right) =>
      left?.companyId == right.companyId &&
      left?.userId == right.userId &&
      left?.staffId == right.staffId &&
      left?.deviceId == right.deviceId;

  void _setState(AutoSyncPhase next, String nextMessage) {
    phase = next;
    message = nextMessage;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _periodicTimer?.cancel();
    _saveTimer?.cancel();
    unawaited(_outboxSubscription?.cancel());
    unawaited(_remoteSubscription?.cancel());
    super.dispose();
  }
}
