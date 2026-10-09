import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'pronunciation_check.dart';
import 'rest_client.dart';

/// Общий контракт проверки произношения для любого учебного материала.
class PronunciationRestClient extends RestClient {
  PronunciationRestClient({super.dio});
  static const checkTimeout = Duration(seconds: 15);

  Future<PronunciationCheck> check({
    required File audio,
    required PronunciationTarget target,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'target': jsonEncode(target.toJson()),
      'audio': await MultipartFile.fromFile(
        audio.path,
        filename: audio.uri.pathSegments.last,
      ),
    });
    final result = await postObject(
      '/pronunciation/check',
      PronunciationCheck.fromJson,
      data: form,
      cancelToken: cancelToken,
      options: Options(
        connectTimeout: checkTimeout,
        sendTimeout: checkTimeout,
        receiveTimeout: checkTimeout,
      ),
    );
    result.validateFor(target);
    return result;
  }
}
