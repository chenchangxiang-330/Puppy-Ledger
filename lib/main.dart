import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'core/controller.dart';
import 'core/store.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final directory = await getApplicationDocumentsDirectory();
    await Directory(directory.path).create(recursive: true);
    final store = await LedgerStore.open(
      databasePath: p.join(directory.path, 'puppy_ledger.db'),
    );
    final controller = LedgerController(store: store, directory: directory);
    await controller.refresh();
    runApp(PuppyLedgerApp(controller: controller));
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pets, size: 64, color: Color(0xff604637)),
                    const SizedBox(height: 20),
                    const Text('账本暂时无法打开', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 12),
                    const Text(
                      '请检查手机存储空间后重新打开。已有账目不会被自动清空。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: main, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
