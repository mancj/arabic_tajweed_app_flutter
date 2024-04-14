import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'gowalk_helper.dart';

var logger = Logger(
  printer: PrettyPrinter(
    colors: false,
    methodCount: 1,
    lineLength: 200,
    noBoxingByDefault: true,
  ),
);

class GowalkHelperPlugin {
  bool _isInitialized = false;
  bool _isPrepared = false;
  static const _channel = MethodChannel('com.gowalk.app/channel');
  late final GowalkMethodCallHandler _methodCallHandler;

  GowalkHelperPlugin() {
    _methodCallHandler = GowalkMethodCallHandler();
    _channel.setMethodCallHandler(_methodCallHandler.handleMethodCall);
  }

  Future<void> ping() async {
    try {
      final String result = await _channel.invokeMethod('ping', 'ping');
      logger.d("Ping $result");
    } on PlatformException catch (e) {
      logger.w("Failed to call native method: '${e.message}'.");
    }
  }

  Future<void> initPlugin({
    required String appleAppID,
    String? mixpanelKey,
    String? amplitudeKey,
    String? adaptyKey,
    bool shouldShowRatingAfterATTView = true,
    String? oneSignalApiKey,
    String? oneSignalAppGroupId,
    String? qonversionKey,
  }) async {
    if (_isInitialized) return;
    final bool result = await _channel.invokeMethod(
      'initGowalkDevHelper',
      {
        "appleAppID": appleAppID,
        "mixpanelKey": mixpanelKey,
        "amplitudeKey": amplitudeKey,
        "adaptyKey": adaptyKey,
        "shouldShowRatingAfterATTView": shouldShowRatingAfterATTView,
        "oneSignalApiKey": oneSignalApiKey,
        "oneSignalAppGroupId": oneSignalAppGroupId,
        "qonversionKey": qonversionKey,
      },
    );
    _isInitialized = true;
    logger.d("Gowalk dev helper initialized: $result");
  }

  Future<void> prepareHelper() async {
    if (_isPrepared) return;
    try {
      final bool result = await _channel.invokeMethod('prepareHelper');
      logger.d("Gowalk dev helper prepared: $result");
      _isPrepared = true;
    } catch (e) {
      print(e);
    }
  }

  Future<bool> initializeOnboarding({bool forceShowOnboarding = false}) async {
    bool didShownOnboarding = await _channel.invokeMethod(
        'initializeOnboarding', forceShowOnboarding);
    return didShownOnboarding;
  }

  Future<void> showAppRatingPopup() async {
    await _channel.invokeMethod('showAppRatingPopup');
    logger.d("Gowalk showAppRatingPopup called");
  }

  Future<void> showPaidContentOrPaywall(
    Function() presentPaidContent,
    Function(PaywallDownloadStatus status)?
        didChangePaywallDownloadStatusStream, {
    bool skipDebug = false,
    String? placementId,
  }) async {
    if (kDebugMode && skipDebug) {
      presentPaidContent();
      return;
    }
    var subscription = _methodCallHandler.didChangePaywallDownloadStatusStream
        .listen((status) {
      didChangePaywallDownloadStatusStream?.call(status);
    });
    bool result = await _channel.invokeMethod(
      "showPaidContentOrPaywall",
      placementId,
    );
    if (result) {
      presentPaidContent();
    }
    await subscription.cancel();
  }

  Future<bool> showPaywall([String? placementId]) async {
    bool result = await _channel.invokeMethod("showPaywall", placementId);
    logger.d("Gowalk showPaywall called with result: $result");
    return result;
  }

  Future<void> setOnboardingPassed(bool passed) async {
    await _channel.invokeMethod("setOnboardingPassed", passed);
  }

  Future<bool> getSubscriptionStatus() async {
    bool result = await _channel.invokeMethod('getSubscriptionStatus');
    logger.d("Gowalk getSubscriptionStatus called with result: $result");
    return result;
  }

  Future<String?> getRemoteConfigStringValue(String key) async {
    String? result =
        await _channel.invokeMethod('getRemoteConfigStringValue', key);
    logger.d("Gowalk getRemoteConfigStringValue called with result: $result");
    return result;
  }
}
