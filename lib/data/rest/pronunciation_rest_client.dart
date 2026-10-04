import 'dart:io';

import 'package:arabic_tajweed_app/data/rest/letter_check.dart';
import 'package:arabic_tajweed_app/data/rest/rest_client.dart';
import 'package:dio/dio.dart';

import 'syllable_check.dart';

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
    CancelToken? cancelToken,
  }) => _checkAudio(
    '/letter',
    LetterCheck.fromJson,
    audio,
    expected,
    cancelToken,
  );

  /// Ожидается прочитанный слог с краткой огласовкой: «بِ», а не имя буквы.
  /// Это настоящий запрос; отсутствие метода на сервере остаётся ошибкой API.
  Future<SyllableCheck> checkSyllable({
    required File audio,
    required String expected,
    CancelToken? cancelToken,
  }) async {
    final check = await _checkAudio(
      '/syllable',
      SyllableCheck.fromJson,
      audio,
      expected,
      cancelToken,
    );
    check.validateFor(expected);
    return check;
  }

  Future<T> _checkAudio<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
    File audio,
    String expected,
    CancelToken? cancelToken,
  ) async {
    final form = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        audio.path,
        filename: audio.uri.pathSegments.last,
      ),
    });
    return postObject(
      path,
      fromJson,
      data: form,
      cancelToken: cancelToken,
      query: {'expected': expected},
      options: Options(
        connectTimeout: checkTimeout,
        sendTimeout: checkTimeout,
        receiveTimeout: checkTimeout,
      ),
    );
  }
}
