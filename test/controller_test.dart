import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppy_ledger/core/backup.dart';
import 'package:puppy_ledger/core/controller.dart';
import 'package:puppy_ledger/core/models.dart';
import 'package:puppy_ledger/core/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const channel = MethodChannel('puppy_ledger/files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory dir;
  late LedgerStore store;
  late LedgerController controller;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4f+XAfwAI/AOT6HomIgAAAABJRU5ErkJggg==',
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('puppy_controller_');
    store = await LedgerStore.open(
      databasePath: '${dir.path}/test.db',
      factory: databaseFactoryFfi,
    );
    controller = LedgerController(store: store, directory: dir);
    await controller.refresh();
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    controller.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });

  test(
    'save publishes once after persistence and rejects simultaneous duplicate',
    () async {
      var notifications = 0;
      controller.addListener(() => notifications++);
      final save = controller.saveEntry(
        amount: '0.10',
        kind: EntryKind.expense,
        date: '2026-11-03',
        categoryId: 'default-1',
        note: '午饭',
      );
      await expectLater(
        controller.saveEntry(
          amount: '0.10',
          kind: EntryKind.expense,
          date: '2026-11-03',
          categoryId: 'default-1',
          note: '午饭',
        ),
        throwsStateError,
      );
      await save;
      expect((await store.entries()).length, 1);
      expect(controller.entries.single.cents, 10);
      expect(notifications, 1);
      final id = controller.entries.single.id;
      await controller.saveEntry(
        id: id,
        amount: '0.20',
        kind: EntryKind.income,
        date: '2026-10-31',
        categoryId: 'income-refund',
        note: '改为退款',
      );
      expect(controller.entries.single.id, id);
      expect((await store.entries()).single.cents, 20);
      await controller.deleteEntry(id);
      expect(controller.entries, isEmpty);
      expect(await store.entries(), isEmpty);
    },
  );

  test(
    'image is copied durably, cancellation preserves it, reset persists',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => png);
      await controller.chooseImage();
      final name = controller.settings.imageFile!;
      expect(name.contains('/'), isFalse);
      expect(await File('${dir.path}/$name').readAsBytes(), png);
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await controller.chooseImage();
      expect(controller.settings.imageFile, name);
      await store.close();
      store = await LedgerStore.open(
        databasePath: '${dir.path}/test.db',
        factory: databaseFactoryFfi,
      );
      controller.dispose();
      controller = LedgerController(store: store, directory: dir);
      await controller.refresh();
      expect(controller.settings.imageFile, name);
      expect(await File('${dir.path}/$name').readAsBytes(), png);
      await controller.resetImage();
      expect((await store.settings()).imageFile, isNull);
    },
  );

  test(
    'export supplies actual portable ZIP and cancelled writes do not succeed',
    () async {
      Uint8List? exported;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'writeBackup') {
          exported = (call.arguments as Map)['bytes'] as Uint8List;
          return true;
        }
        return null;
      });
      await controller.exportBackup();
      final data = BackupCodec.decode(exported!);
      expect(data.entries, isEmpty);
      expect(data.categories.length, 10);
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      await expectLater(
        controller.exportBackup(),
        throwsA(isA<FileActionCancelled>()),
      );
    },
  );
}
