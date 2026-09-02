import 'dart:math';

import 'package:collection/collection.dart';

import 'atom.dart';
import 'atom_state.dart';
import 'curriculum.dart';
import 'exercise.dart';
import 'learning_rules.dart';
import 'planner.dart';
import 'progress_event.dart';

/// Превращает план урока в конкретные задания. Отдельный слой, потому что
/// «какие атомы показать» и «каким заданием их спросить» — разные решения:
/// первое зависит от графа, второе от состояния конкретного атома.
class ExerciseGenerator {
  ExerciseGenerator({
    required this.curriculum,
    this.rules = const LearningRules(),
    Random? random,
  }) : _random = random ?? Random();

  final Curriculum curriculum;
  final LearningRules rules;
  final Random _random;

  /// Сколько заданий даётся на каждый новый атом в блоке тренажа.
  static const _drillsPerNewAtom = 3;

  /// Потолок повторов одного атома за сессию. Добивать урок до двенадцати
  /// заданий по одной и той же букве — не тренировка, а издевательство:
  /// лучше короткий урок, чем двенадцать раз подряд одно и то же.
  static const _maxPerAtom = 3;

  List<Exercise> build({
    required LessonPlan plan,
    required CurriculumContext ctx,
    required int sessionId,
  }) {
    // Новые атомы уже показаны в блоке «новое», поэтому входят в пул
    // дистракторов и могут встретиться как неверный вариант у соседей.
    final pool = {..._introducedAtoms(ctx), ...plan.newAtoms}.toList();

    // Понятия объясняются в блоке «новое» и заданиями не спрашиваются,
    // поэтому в расписание тренажа они не попадают вовсе — иначе занимали бы
    // слоты, из которых ничего не получается.
    final review = plan.reviewAtoms
        .map(_atomById)
        .nonNulls
        .where(_drillable)
        .toList();
    final fresh = plan.newAtoms.where(_drillable).toList();

    final exercises = <Exercise>[];
    for (final atom in _schedule(fresh, review)) {
      final ex = _make(
        atom,
        ctx,
        pool,
        sessionId,
        isReview: !plan.newAtoms.contains(atom),
      );
      if (ex != null) exercises.add(ex);
    }
    return exercises;
  }

  /// Кого спрашиваем и в каком порядке.
  ///
  /// Атомы чередуются: подряд одну и ту же букву не спрашиваем. Блоками
  /// («три раза алиф, потом три раза ба») человек отвечает по инерции —
  /// держит в голове одну букву и не переключается, а именно переключение
  /// и есть навык чтения.
  ///
  /// Новый атом встречается чаще старого: он в этом уроке и вводится.
  /// Если атомов меньше, чем слотов, круги повторяются — но не больше
  /// [_maxPerAtom] раз на атом, иначе урок вырождается в одну букву.
  List<Atom> _schedule(List<Atom> fresh, List<Atom> review) {
    final remaining = <Atom, int>{
      for (final atom in fresh) atom: _drillsPerNewAtom,
      for (final atom in review) atom: 1,
    };
    if (remaining.isEmpty) return const [];

    final cap = min(rules.tasksPerSession, remaining.length * _maxPerAtom);

    // Добираем до полного урока по кругу, пока не упрёмся в потолок.
    final atoms = remaining.keys.toList();
    var i = 0;
    var planned = remaining.values.reduce((a, b) => a + b);
    while (planned < cap) {
      final atom = atoms[i % atoms.length];
      if (remaining[atom]! < _maxPerAtom) {
        remaining[atom] = remaining[atom]! + 1;
        planned++;
      }
      i++;
      if (i > atoms.length * _maxPerAtom) break;
    }

    // Раскладываем по кругу: за один проход по атому, порядок внутри
    // прохода случайный, чтобы уроки не выглядели одинаково.
    final result = <Atom>[];
    while (result.length < cap && remaining.values.any((n) => n > 0)) {
      final pass = remaining.keys.where((a) => remaining[a]! > 0).toList()
        ..shuffle(_random);

      // На стыке кругов случайный порядок может повторить последнюю букву
      // предыдущего прохода — тогда меняем её местами со следующей.
      if (pass.length > 1 && result.isNotEmpty && pass.first == result.last) {
        pass.swap(0, 1);
      }

      for (final atom in pass) {
        if (result.length >= cap) break;
        result.add(atom);
        remaining[atom] = remaining[atom]! - 1;
      }
    }
    return result;
  }

  static bool _drillable(Atom atom) => atom.kind != AtomKind.concept;

  Exercise? _make(
    Atom atom,
    CurriculumContext ctx,
    List<Atom> pool,
    int sessionId, {
    required bool isReview,
  }) {
    final level = _levelFor(atom, ctx, sessionId);
    final picked = _pickDistractors(atom, pool, level);

    // Вариантов не набирается — на старте курса введённых букв просто мало.
    // Вместо пустого урока даём задание без выбора: обводку. Она работает
    // с одной буквой и заодно тренирует воспроизведение, а не узнавание.
    if (picked.distractors.length < 2) {
      return Exercise.direct(
        atom: atom,
        mode: ExerciseMode.trace,
        level: level,
        isReview: isReview,
      );
    }

    final options = [atom, ...picked.distractors]..shuffle(_random);
    return Exercise(
      atom: atom,
      mode: _modeFor(atom, picked.level),
      options: options,
      answerIndex: options.indexOf(atom),
      level: picked.level,
      isReview: isReview,
    );
  }

  /// Градация: только введён → далёкие, в ротации → смешанные,
  /// на подходе к known → минимальная пара. Атом, вернувшийся из паузы,
  /// получает облегчённый режим — долбить тем же способом бессмысленно.
  DistractorLevel _levelFor(Atom atom, CurriculumContext ctx, int sessionId) {
    final p = ctx.progress[atom.id] ?? const AtomProgress();
    if (p.returnedEasy(sessionId, rules)) return DistractorLevel.distant;

    return switch (p.state) {
      AtomState.fresh || AtomState.introduced => DistractorLevel.distant,
      AtomState.learning when p.cleanStreak >= rules.cleanStreakForKnown - 1 =>
        DistractorLevel.minimalPair,
      AtomState.learning => DistractorLevel.mixed,
      AtomState.known || AtomState.mastered => DistractorLevel.minimalPair,
    };
  }

  /// Дистракторы берутся только из введённых атомов: иначе человек выбирает
  /// между знакомым и незнакомым и просто отсеивает по узнаваемости.
  _Picked _pickDistractors(Atom atom, List<Atom> pool, DistractorLevel level) {
    final sameForm = pool
        .where((a) => a.id != atom.id && a.form == atom.form)
        .toList();

    final confusable = sameForm
        .where((a) => atom.confusableWith.contains(a.letterId))
        .toList();
    final distant = sameForm
        .whereNot((a) => atom.confusableWith.contains(a.letterId))
        .toList();

    // Минимальная пара возможна, только когда обе буквы уже введены.
    // Если пары нет — честно откатываемся, а не подставляем далёкие
    // варианты под видом сложных.
    final (chosen, source) = switch (level) {
      DistractorLevel.minimalPair when confusable.length >= 2 => (
        DistractorLevel.minimalPair,
        confusable,
      ),
      DistractorLevel.minimalPair => (DistractorLevel.mixed, sameForm),
      DistractorLevel.mixed => (DistractorLevel.mixed, sameForm),
      DistractorLevel.distant when distant.length >= 2 => (
        DistractorLevel.distant,
        distant,
      ),
      DistractorLevel.distant => (DistractorLevel.mixed, sameForm),
    };

    final shuffled = [...source]..shuffle(_random);
    return _Picked(chosen, shuffled.take(3).toList());
  }

  ExerciseMode _modeFor(Atom atom, DistractorLevel level) {
    if (level == DistractorLevel.minimalPair &&
        atom.confusableWith.isNotEmpty) {
      return ExerciseMode.distinguishDots;
    }
    const basic = [ExerciseMode.formToName, ExerciseMode.nameToForm];
    return basic[_random.nextInt(basic.length)];
  }

  List<Atom> _introducedAtoms(CurriculumContext ctx) => curriculum.nodes
      .map((n) => n.atom)
      .where((a) => ctx.stateOf(a.id) != AtomState.fresh)
      .toList();

  Atom? _atomById(String id) =>
      curriculum.nodes.firstWhereOrNull((n) => n.atom.id == id)?.atom;
}

class _Picked {
  const _Picked(this.level, this.distractors);

  final DistractorLevel level;
  final List<Atom> distractors;
}
