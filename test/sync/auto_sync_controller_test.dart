import 'dart:async';

import 'package:construction_erp/sync/domain/sync_models.dart';
import 'package:construction_erp/sync/services/auto_sync_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const context = SyncContext(
    companyId: 'company-1',
    userId: 'user-1',
    deviceId: 'device-1',
  );
  const success = SyncRunResult(
    uploaded: 1,
    downloaded: 0,
    applied: 0,
    conflicts: 0,
    failed: 0,
  );

  test('startup, local save and remote change trigger automatic sync',
      () async {
    final outbox = StreamController<String>.broadcast(sync: true);
    final remote = StreamController<void>.broadcast(sync: true);
    var runs = 0;
    final controller = AutoSyncController(
      runSync: (_) async {
        runs++;
        return success;
      },
      pendingCount: (_) async => 0,
      loadScope: (_) async => const SyncDownloadScope(allCompanyData: true),
      watchRemoteChanges: (_, __) => remote.stream,
      outboxSignals: outbox.stream,
      queueCheckInterval: const Duration(seconds: 5),
      saveDebounce: const Duration(milliseconds: 5),
    );
    addTearDown(() async {
      controller.dispose();
      await outbox.close();
      await remote.close();
    });

    await controller.start(context);
    await _waitFor(() => runs == 1);

    outbox.add('another-company');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(runs, 1);

    outbox.add('company-1');
    await _waitFor(() => runs == 2);

    remote.add(null);
    await _waitFor(() => runs == 3);
    expect(controller.phase, AutoSyncPhase.upToDate);
  });

  test('overlapping automatic triggers are coalesced into one follow-up run',
      () async {
    final outbox = StreamController<String>.broadcast(sync: true);
    final remote = StreamController<void>.broadcast(sync: true);
    final firstRun = Completer<SyncRunResult>();
    var runs = 0;
    final controller = AutoSyncController(
      runSync: (_) {
        runs++;
        return runs == 1 ? firstRun.future : Future.value(success);
      },
      pendingCount: (_) async => 0,
      loadScope: (_) async => const SyncDownloadScope(allCompanyData: true),
      watchRemoteChanges: (_, __) => remote.stream,
      outboxSignals: outbox.stream,
      queueCheckInterval: const Duration(seconds: 5),
      saveDebounce: const Duration(milliseconds: 5),
    );
    addTearDown(() async {
      controller.dispose();
      await outbox.close();
      await remote.close();
    });

    await controller.start(context);
    await _waitFor(() => runs == 1);
    outbox.add('company-1');
    remote.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(runs, 1);

    firstRun.complete(success);
    await _waitFor(() => runs == 2);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(runs, 2);
  });

  test('pause stops triggers and resume performs a fresh sync', () async {
    final outbox = StreamController<String>.broadcast(sync: true);
    final remote = StreamController<void>.broadcast(sync: true);
    var runs = 0;
    final controller = AutoSyncController(
      runSync: (_) async {
        runs++;
        return success;
      },
      pendingCount: (_) async => 0,
      loadScope: (_) async => const SyncDownloadScope(allCompanyData: true),
      watchRemoteChanges: (_, __) => remote.stream,
      outboxSignals: outbox.stream,
      queueCheckInterval: const Duration(seconds: 5),
      saveDebounce: const Duration(milliseconds: 5),
    );
    addTearDown(() async {
      controller.dispose();
      await outbox.close();
      await remote.close();
    });

    await controller.start(context);
    await _waitFor(() => runs == 1);
    await controller.pause();
    outbox.add('company-1');
    remote.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(runs, 1);

    await controller.resume();
    await _waitFor(() => runs == 2);
  });

  test('network failure keeps local work safe and manual retry recovers',
      () async {
    final outbox = StreamController<String>.broadcast(sync: true);
    final remote = StreamController<void>.broadcast(sync: true);
    var runs = 0;
    final controller = AutoSyncController(
      runSync: (_) async {
        runs++;
        if (runs == 1) throw StateError('network unavailable');
        return success;
      },
      pendingCount: (_) async => 1,
      loadScope: (_) async =>
          const SyncDownloadScope(allCompanyData: true),
      watchRemoteChanges: (_, __) => remote.stream,
      outboxSignals: outbox.stream,
      queueCheckInterval: const Duration(seconds: 5),
      saveDebounce: const Duration(milliseconds: 5),
    );
    addTearDown(() async {
      controller.dispose();
      await outbox.close();
      await remote.close();
    });

    await controller.start(context);
    await _waitFor(() => controller.phase == AutoSyncPhase.offline);
    expect(controller.message, contains('retry automatically'));

    final result = await controller.syncNow(context);
    expect(result.failed, 0);
    expect(controller.phase, AutoSyncPhase.upToDate);
    expect(runs, 2);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out while waiting for the automatic sync state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
