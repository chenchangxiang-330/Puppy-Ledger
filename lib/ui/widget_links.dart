import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';

/// Each Android click is consumed exactly once after Flutter's navigator is ready.
class WidgetLinks {
  WidgetLinks(this.controller, this.receive);
  static const channel = MethodChannel('puppy_ledger/widgets');
  final LedgerController controller;
  final void Function(String type, String value) receive;
  bool active = false, reading = false, again = false;
  void attach() {
    active = true;
    controller.addListener(refresh);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'intentAvailable') await drain();
    });
    refresh();
  }

  Future<void> refresh() async {
    if (!active) return;
    try {
      await channel.invokeMethod<void>('dataChanged');
    } on MissingPluginException {
      return;
    } on PlatformException catch (e) {
      debugPrint('Widget refresh: ${e.code}');
    }
  }

  Future<void> drain() async {
    again = true;
    if (reading || !active) return;
    reading = true;
    try {
      while (active && again) {
        again = false;
        final launch = await channel.invokeMapMethod<String, String>(
          'takeLaunch',
        );
        if (!active) return;
        if (launch != null) {
          again = true;
          receive(launch['type'] ?? '', launch['value'] ?? '');
        }
      }
    } on MissingPluginException {
      return;
    } on PlatformException catch (e) {
      debugPrint('Widget launch: ${e.code}');
    } finally {
      reading = false;
    }
  }

  void dispose() {
    active = false;
    controller.removeListener(refresh);
    channel.setMethodCallHandler(null);
  }
}
