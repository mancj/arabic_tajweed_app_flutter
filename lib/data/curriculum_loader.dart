import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/curriculum.dart';

/// Загружает учебный контент из ассетов. Граф, темы и тексты лежат
/// JSON-файлами в репозитории: версионируются через git, работают офлайн.
/// Формат намеренно такой, чтобы те же файлы можно было отдавать с сервера,
/// когда контент начнёт меняться чаще релизов. См. SPEC.md §6.
class CurriculumLoader {
  const CurriculumLoader({this.stageAssets = defaultStageAssets});

  static const defaultStageAssets = ['assets/curriculum/stage1.json'];

  final List<String> stageAssets;

  Future<Curriculum> load() async {
    final stages = await Future.wait(stageAssets.map(_loadStage));
    return merge(stages);
  }

  Future<Curriculum> _loadStage(String asset) async =>
      parse(await rootBundle.loadString(asset));

  /// Отдельно от загрузки, чтобы разбор можно было тестировать без ассетов.
  static Curriculum parse(String source) =>
      Curriculum.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Этапы лежат отдельными файлами, но граф один: порядок узлов внутри
  /// склейки задаёт предпочтение планировщика при равных условиях.
  static Curriculum merge(Iterable<Curriculum> stages) => Curriculum(
    nodes: [for (final s in stages) ...s.nodes],
    topics: [for (final s in stages) ...s.topics],
  );
}
