import 'dart:convert';

import 'package:arabic_tajweed_app/data/rest/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' show Get, Inst;

/// Каркас для клиентов сервера. Один клиент — одна область API.
///
/// Наследник описывает только пути и модели, а разбор ответа
/// и перевод ошибок в [ApiException] делает базовый класс:
///
/// ```dart
/// class LessonsRestClient extends RestClient {
///   Future<List<LessonJson>> getLessons() =>
///       getList('/lessons', LessonJson.fromJson);
///
///   Future<LessonJson> getLesson(String id) =>
///       getObject('/lessons/$id', LessonJson.fromJson);
///
///   Future<void> markDone(String id) => post('/lessons/$id/done');
/// }
/// ```
///
/// Регистрируется в `AppBinding` после `Dio`: `Get.put(LessonsRestClient())`.
abstract class RestClient {
  final Dio _dio;

  RestClient({Dio? dio}) : _dio = dio ?? Get.find<Dio>();

  /// GET, в ответе один объект.
  @protected
  Future<T> getObject<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson, {
    Map<String, dynamic>? query,
  }) {
    return request(
      (dio) => dio.get(path, queryParameters: query),
      (json) => fromJson(json as Map<String, dynamic>),
    );
  }

  /// GET, в ответе список объектов.
  @protected
  Future<List<T>> getList<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson, {
    Map<String, dynamic>? query,
  }) {
    return request(
      (dio) => dio.get(path, queryParameters: query),
      (json) => _parseList(json, fromJson),
    );
  }

  /// POST, в ответе один объект.
  @protected
  Future<T> postObject<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson, {
    Object? data,
    Map<String, dynamic>? query,
    Options? options,
  }) {
    return request(
      (dio) =>
          dio.post(path, data: data, queryParameters: query, options: options),
      (json) => fromJson(json as Map<String, dynamic>),
    );
  }

  /// POST без полезного ответа.
  @protected
  Future<void> post(String path, {Object? data, Map<String, dynamic>? query}) {
    return request(
      (dio) => dio.post(path, data: data, queryParameters: query),
      (_) {},
    );
  }

  /// Общий путь любого запроса: выполнить, раскодировать тело,
  /// разобрать модель. Любая ошибка Dio наружу выходит как [ApiException].
  /// Для нестандартных запросов (DELETE, PUT, файлы) вызывать напрямую.
  @protected
  Future<T> request<T>(
    Future<Response<dynamic>> Function(Dio dio) call,
    T Function(dynamic json) parse,
  ) async {
    try {
      final response = await call(_dio);
      return parse(_decode(response.data));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Сервер иногда отдаёт JSON как текст (без нужного content-type).
  /// Тогда раскодируем сами; пустое тело считаем отсутствием данных.
  static dynamic _decode(dynamic data) {
    if (data is String) {
      return data.isEmpty ? null : jsonDecode(data);
    }
    return data;
  }

  static List<T> _parseList<T>(
    dynamic json,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (json == null) return const [];
    return (json as List)
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
