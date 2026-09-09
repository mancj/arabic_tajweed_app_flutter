import 'dart:io';

import 'package:arabic_tajweed_app/data/rest/letter_check.dart';
import 'package:arabic_tajweed_app/data/rest/rest_client.dart';
import 'package:dio/dio.dart';

/// Проверка произношения на сервере.
class PronunciationRestClient extends RestClient {
  PronunciationRestClient({super.dio});

  /// Проверка записи не должна ждать дольше пятнадцати секунд.
  static const checkTimeout = Duration(seconds: 15);

  /// Названа ли в записи буква [expected]. Ожидается сам глиф («ت»),
  /// а не имя. Сервер принимает wav и m4a.
  Future<LetterCheck> checkLetter({
    required File audio,
    required String expected,
  }) async {
    final form = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        audio.path,
        filename: audio.uri.pathSegments.last,
      ),
    });
    return postObject(
      '/letter',
      LetterCheck.fromJson,
      data: form,
      query: {'expected': expected},
      options: Options(
        connectTimeout: checkTimeout,
        sendTimeout: checkTimeout,
        receiveTimeout: checkTimeout,
      ),
    );
  }
}
