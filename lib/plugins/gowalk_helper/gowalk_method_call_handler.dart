import 'dart:async';

import 'package:flutter/services.dart';

import 'gowalk_helper.dart';

class GowalkMethodCallHandler {
  final _didChangePaywallDownloadStatusController =
      StreamController<PaywallDownloadStatus>.broadcast();

  Stream<PaywallDownloadStatus> get didChangePaywallDownloadStatusStream =>
      _didChangePaywallDownloadStatusController.stream;

  Future<dynamic> handleMethodCall(MethodCall call) async {
    if (call.method == "didChangePaywallDownloadStatus") {
      _didChangePaywallDownloadStatusController.add(call.arguments);
    }
  }
}
