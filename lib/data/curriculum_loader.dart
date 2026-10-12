import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/atom.dart';
import '../domain/curriculum.dart';
import '../domain/practice_profile.dart';
import '../domain/reading_word.dart';

/// Загружает учебный контент из ассетов. Граф, темы и тексты лежат
/// JSON-файлами в репозитории: версионируются через git, работают офлайн.
/// Формат намеренно такой, чтобы те же файлы можно было отдавать с сервера,
/// когда контент начнёт меняться чаще релизов. См. SPEC.md §6.
class CurriculumLoader {
  const CurriculumLoader({this.assets = defaultAssets});

  static const wordBankAsset = 'assets/curriculum/words.json';
  static const practiceProfilesAsset =
      'assets/curriculum/practice_profiles.json';
  static const defaultAssets = [
    'assets/curriculum/stage1.json',
    'assets/curriculum/stage2.json',
    'assets/curriculum/stage3.json',
    wordBankAsset,
    practiceProfilesAsset,
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
    final profileEntries = stageList.expand(
      (stage) => stage.practiceProfiles.entries,
    );
    final profiles = Map<String, PracticeProfile>.fromEntries(profileEntries);
    if (profiles.length != profileEntries.length) {
      throw StateError('Повтор ID профиля практики');
    }
    for (final entry in profiles.entries) {
      entry.value.validate(entry.key);
    }
    if (profiles['standard']?.isStandard == false) {
      throw StateError('Стандартный профиль должен сохранять прежние правила');
    }
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
            CurriculumNode(
              atom: _resolveAtom(node.atom, byId, profiles),
              requirement: node.requirement,
            ),
      ],
      topics: [
        for (final stage in stageList) ...stage.topics,
      ].sortedBy((topic) => topic.stage),
      words: words,
      wordSets: sets,
      practiceProfiles: profiles,
    );
  }

  static Atom _resolveAtom(
    Atom source,
    Map<String, ReadingWord> words,
    Map<String, PracticeProfile> profiles,
  ) {
    final profile =
        profiles[source.practiceProfileId] ??
        (source.practiceProfileId == 'standard'
            ? const PracticeProfile.standard()
            : throw StateError(
                'Неизвестный профиль ${source.practiceProfileId} у ${source.id}',
              ));
    final word = source.wordId == null
        ? null
        : words[source.wordId] ??
              (throw StateError('Не найдено слово ${source.wordId}'));
    final atom = source.copyWith(
      display: word?.display,
      audioAsset: word?.audioAsset,
      practiceProfile: profile,
    );
    profile.validateFor(atom);
    return atom;
  }
}
