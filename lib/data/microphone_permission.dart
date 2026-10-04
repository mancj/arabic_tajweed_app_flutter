import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

enum MicrophonePermissionResult { granted, denied, settingsRequired }

/// Запрашивает доступ только при попытке записать голос. Повторный запрос при
/// уже выданном доступе не открывает системное окно.
class MicrophonePermission {
  const MicrophonePermission();

  Future<bool> isPermanentlyDenied() async {
    try {
      return (await Permission.microphone.status).isPermanentlyDenied;
    } catch (_) {
      // Если статус недоступен, решаем при попытке записи, а не прячем голос.
      return false;
    }
  }

  Future<MicrophonePermissionResult> request() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicrophonePermissionResult.granted;
    if (status.isPermanentlyDenied ||
        status.isRestricted ||
        (Platform.isIOS && status.isDenied)) {
      return MicrophonePermissionResult.settingsRequired;
    }
    return MicrophonePermissionResult.denied;
  }

  Future<bool> openSettings() => openAppSettings();
}
