import 'dart:convert';
import 'dart:io';

import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:flutter/services.dart';

/// Ассеты в памяти: проверяем загрузку и ошибки без зависимости от rootBundle.
class TextAssetBundle extends AssetBundle {
  TextAssetBundle(this.sources);

  factory TextAssetBundle.forCurriculum(Curriculum curriculum) {
    final paths = {
      for (final node in curriculum.nodes)
        if (node.atom.explanationAsset case final path?) path,
      for (final node in curriculum.nodes)
        if (node.atom.formsOverviewAsset case final path?) path,
    };
    return TextAssetBundle({
      for (final path in paths) path: File(path).readAsStringSync(),
    });
  }

  final Map<String, String> sources;
  final loads = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    final source = sources[key];
    if (source == null) throw StateError('Нет ассета $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}
