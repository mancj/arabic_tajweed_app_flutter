import 'dart:async';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../../../data/curriculum_loader.dart';
import '../../../data/progress_database.dart';
import '../../../data/progress_repository.dart';
import '../../../domain/atom.dart';
import '../../../domain/atom_state.dart';
import '../../../domain/learning_rules.dart';

/// Строка отладочного списка: атом и его свёрнутое состояние.
class AtomRow {
  const AtomRow({required this.atom, required this.progress});

  final Atom atom;
  final AtomProgress progress;
}

/// Отладочный экран: состояние каждого атома, как его видит свёртка лога.
///
/// Нужен, чтобы понимать, почему планировщик ведёт себя так, а не иначе:
/// state, серия, режимы, ошибки и откладывания — всё то, что в уроке
/// не показывается, а решает, что будет дальше.
class AtomProgressController extends GetxController {
  AtomProgressController({LearningRules? rules})
    : rules = rules ?? const LearningRules();

  final LearningRules rules;

  final loading = true.obs;
  final rows = <AtomRow>[].obs;

  /// Свежих атомов больше всего, и они ничего не говорят. По умолчанию
  /// скрыты, чтобы на экране было то, что уже двигалось.
  final hideFresh = true.obs;

  /// Номер сессии, которая начнётся следующей: относительно него
  /// считается, отложен атом ещё или уже вернулся.
  final nextSession = 0.obs;

  late final ProgressRepository _progress;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    loading.value = true;
    final curriculum = await const CurriculumLoader().load();
    _progress = ProgressRepository(
      database: Get.find<ProgressDatabase>(),
      rules: rules,
      letterFormIds: curriculum.letterFormIds,
    );
    final progress = await _progress.progress();
    nextSession.value = await _progress.nextSessionId();

    final known = curriculum.nodes.map((n) => n.atom.id).toSet();
    // Слоги заводятся лениво и в графе не значатся, но прогресс по ним
    // есть — их показываем после атомов графа.
    final lazy = progress.keys
        .whereNot(known.contains)
        .sorted()
        .map((id) => Atom(id: id, kind: AtomKind.syllable, display: id));

    rows.assignAll([
      for (final node in curriculum.nodes)
        AtomRow(
          atom: node.atom,
          progress: progress[node.atom.id] ?? const AtomProgress(),
        ),
      for (final atom in lazy)
        AtomRow(atom: atom, progress: progress[atom.id]!),
    ]);
    loading.value = false;
  }

  List<AtomRow> get visible => hideFresh.value
      ? rows.where((r) => r.progress.state != AtomState.fresh).toList()
      : rows.toList();

  /// Сколько атомов в каждом состоянии — сводка над списком.
  Map<AtomState, int> get counts => {
    for (final state in AtomState.values)
      state: rows.where((r) => r.progress.state == state).length,
  };

  bool isDeferred(AtomProgress p) => p.isDeferredAt(nextSession.value, rules);
}
