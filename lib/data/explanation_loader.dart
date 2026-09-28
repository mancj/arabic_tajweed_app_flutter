import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import '../domain/explanation_document.dart';

/// Читает карточки из ассетов и проверяет содержимое до показа на экране.
class ExplanationLoader {
  ExplanationLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final _cache = <String, Future<ExplanationContent>>{};

  Future<ExplanationContent> load(String asset) =>
      _cache.putIfAbsent(asset, () => _load(asset));

  Future<ExplanationContent> _load(String asset) async {
    try {
      final source = await _bundle.loadString(asset);
      return parse(source, sourceName: asset);
    } catch (error) {
      // Исправленный файл можно загрузить повторно после неудачной попытки.
      _cache.remove(asset);
      if (error is FormatException) rethrow;
      throw FormatException('Карточка "$asset": $error');
    }
  }

  static ExplanationContent parse(
    String source, {
    String sourceName = '<card>',
  }) {
    try {
      // Приводим вложенные YamlMap/YamlList к стандартным JSON-коллекциям,
      // чтобы поля моделей разбирал существующий json_serializable.
      final json = jsonDecode(jsonEncode(loadYaml(source)));
      if (json is! Map<String, dynamic>) {
        throw const FormatException('ожидается карточка с title и blocks');
      }
      return ExplanationContent(document: ExplanationDocument.fromJson(json));
    } catch (error) {
      throw FormatException('Карточка "$sourceName": $error');
    }
  }
}
