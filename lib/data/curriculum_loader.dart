import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/curriculum.dart';

/// Загружает учебный контент из ассетов. Граф, темы и тексты лежат
/// JSON-файлами в репозитории: версионируются через git, работают офлайн.
/// Формат намеренно такой, чтобы те же файлы можно было отдавать с сервера,
/// когда контент начнёт меняться чаще релизов. См. SPEC.md §6.
class CurriculumLoader {
  const CurriculumLoader({this.assets = defaultAssets});

  static const wordBankAsset = 'assets/curriculum/words.json';
  static const defaultAssets = [
    'assets/curriculum/stage1.json',
    'assets/curriculum/stage2.json',
    'assets/curriculum/stage3.json',
    wordBankAsset,
  ];

  final List<String> assets;

  Future<Curriculum> load() async {
    final stages = await Future.wait(assets.map(_loadStage));
    return merge(stages);
  }

  Future<Curriculum> _loadStage(String asset) async =>
      parse(await rootBundle.loadString(asset));

  /// Отдельно от загрузки, чтобы разбор можно было тестировать без ассетов.
  static Curriculum parse(String source) =>
      Curriculum.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Этапы лежат отдельными файлами, но граф один: порядок узлов внутри
  /// склейки задаёт предпочтение планировщика при равных условиях. Темы
  /// сортируются по этапу, поэтому файл хранения не диктует программу курса.
  static Curriculum merge(Iterable<Curriculum> stages) {
    final stageList = stages.toList();
    final words = [for (final stage in stageList) ...stage.words];
    final byId = {for (final word in words) word.id: word};
    if (byId.length != words.length) {
      throw StateError('Повтор ID в банке слов');
    }
    final sets = {for (final stage in stageList) ...stage.wordSets};
    for (final ids in sets.values) {
      for (final id in ids) {
        if (!byId.containsKey(id)) {
          throw StateError('В подборке не найдено слово $id');
        }
      }
    }
    return Curriculum(
      nodes: [
        for (final stage in stageList)
          for (final node in stage.nodes)
            if (node.atom.wordId case final id?)
              CurriculumNode(
                atom: node.atom.copyWith(
                  display:
                      (byId[id] ?? (throw StateError('Не найдено слово $id')))
                          .display,
                  audioAsset: byId[id]!.audioAsset,
                ),
                requirement: node.requirement,
              )
            else
              node,
      ],
      topics: [
        for (final stage in stageList) ...stage.topics,
      ].sortedBy((topic) => topic.stage),
      words: words,
      wordSets: sets,
    );
  }
}
