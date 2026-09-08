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

  /// Сколько заданий даётся на каждый новый атом в блоке закрепления.
  static const _drillsPerNewAtom = 3;

  /// Сколько неверных вариантов показываем. Вместе с ответом получается
  /// три карточки: четвёртая почти не снижает угадывание, а выбор из трёх
  /// читается быстрее и на узких экранах помещается без прокрутки.
  static const _distractorCount = 2;

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
    // поэтому в расписание закрепления они не попадают вовсе — иначе занимали бы
    // слоты, из которых ничего не получается.
    final review = plan.reviewAtoms
        .map(_atomById)
        .nonNulls
        .where(_drillable)
        .toList();
    final fresh = plan.newAtoms.where(_drillable).toList();

    final spaced = plan.spacedReview
        .map(_atomById)
        .nonNulls
        .where(_drillable)
        .toList();

    final schedule = _schedule(fresh, review, spaced);
    final slots = <Atom, int>{};
    for (final atom in schedule) {
      slots[atom] = (slots[atom] ?? 0) + 1;
    }

    // Кому в этом уроке уже дали обводку по контуру: по памяти просим
    // только после неё, в том числе когда обе попали в один урок.
    final traced = <String>{};
    final seen = <Atom, int>{};

    final exercises = <Exercise>[];
    for (final atom in schedule) {
      final index = seen[atom] ?? 0;
      seen[atom] = index + 1;

      final ex = _make(
        atom,
        ctx,
        pool,
        sessionId,
        slot: _Slot(index: index, count: slots[atom]!),
        traced: traced,
        isReview: !plan.newAtoms.contains(atom),
      );
      if (ex != null) exercises.add(ex);
    }
    return exercises;
  }

  /// Кого спрашиваем и в каком порядке: сначала закрепление по материалу
  /// урока, затем блок повторения из общей очереди.
  ///
  /// Внутри закрепления атомы чередуются: подряд одну и ту же букву не спрашиваем. Блоками
  /// («три раза алиф, потом три раза ба») человек отвечает по инерции —
  /// держит в голове одну букву и не переключается, а именно переключение
  /// и есть навык чтения.
  ///
  /// Новый атом встречается чаще старого: он в этом уроке и вводится.
  /// Если атомов меньше, чем слотов, круги повторяются — но не больше
  /// [_maxPerAtom] раз на атом, иначе урок вырождается в одну букву.
  List<Atom> _schedule(List<Atom> fresh, List<Atom> review, List<Atom> spaced) {
    // Слоты под возврат старого резервируются первыми: иначе тема съедает
    // весь урок и буквы прошлых уроков не всплывают. См. ТЗ §6.2.
    final spacedSlots = spaced.take(rules.reviewPerSession).toList();

    final remaining = <Atom, int>{
      for (final atom in fresh) atom: _drillsPerNewAtom,
      for (final atom in review) atom: 1,
    };
    if (remaining.isEmpty && spacedSlots.isEmpty) return const [];

    final forTopic = max(0, rules.tasksPerSession - spacedSlots.length);
    final cap = remaining.isEmpty
        ? 0
        : min(forTopic, remaining.length * _maxPerAtom);

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

    // Возврат старого идёт отдельным блоком в хвосте, после закрепления:
    // сначала материал урока, потом повторение прошлых тем. См. ТЗ §6.2.
    // Чередование действует только внутри закрепления.
    return [...result, ...spacedSlots];
  }

  static bool _drillable(Atom atom) => atom.kind != AtomKind.concept;

  Exercise? _make(
    Atom atom,
    CurriculumContext ctx,
    List<Atom> pool,
    int sessionId, {
    required _Slot slot,
    required Set<String> traced,
    required bool isReview,
  }) {
    final level = _levelFor(atom, ctx, sessionId);

    // Обводка выбирается до дистракторов: это не запасной вариант на случай,
    // когда вариантов не набралось, а самостоятельное задание. Буква в нём
    // воспроизводится, а не узнаётся — только так атом доходит до mastered.
    final tracing = _tracingMode(atom, ctx, slot, traced, isReview: isReview);
    if (tracing != null) {
      if (tracing == ExerciseMode.trace) traced.add(atom.id);
      return Exercise.direct(
        atom: atom,
        mode: tracing,
        level: level,
        isReview: isReview,
      );
    }

    final picked = _pickDistractors(atom, pool, level);

    // Вариантов не набирается — на старте курса введённых букв просто мало.
    // Вместо пустого урока даём задание без выбора: обводку. Она работает
    // с одной буквой и заодно тренирует воспроизведение, а не узнавание.
    if (picked.distractors.length < _distractorCount) {
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

  /// Когда за букву берётся холст, а не карточки с вариантами.
  ///
  /// Порядок всегда один: сначала по контуру, потом по памяти. Просить
  /// написать по памяти букву, которую человек ни разу не вёл рукой, —
  /// это проверка до обучения.
  ///
  /// Письмо занимает не больше одного слота атома за урок: первый, если
  /// букву ещё ни разу не вели рукой, и последний, если уже вели. Между
  /// ними остаётся узнавание — иначе урок сведётся к рисованию.
  ///
  /// Букву из повторения по памяти просим, только когда она уже освоена:
  /// на середине пути повторению полезнее узнавание, а письмо по памяти
  /// там превращается в экзамен не вовремя.
  ExerciseMode? _tracingMode(
    Atom atom,
    CurriculumContext ctx,
    _Slot slot,
    Set<String> traced, {
    required bool isReview,
  }) {
    // Фигура есть не у всякого атома: у понятий и слогов её нет вовсе.
    if (atom.tracing == null) return null;

    final p = ctx.progress[atom.id] ?? const AtomProgress();
    final wroteBefore = p.hadActiveSuccess || traced.contains(atom.id);

    if (!wroteBefore) return slot.isFirst ? ExerciseMode.trace : null;
    if (isReview && p.state.index < AtomState.known.index) return null;
    return slot.isLast ? ExerciseMode.traceFromMemory : null;
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
      DistractorLevel.minimalPair when confusable.length >= _distractorCount =>
        (DistractorLevel.minimalPair, confusable),
      DistractorLevel.minimalPair => (DistractorLevel.mixed, sameForm),
      DistractorLevel.mixed => (DistractorLevel.mixed, sameForm),
      DistractorLevel.distant when distant.length >= _distractorCount => (
        DistractorLevel.distant,
        distant,
      ),
      DistractorLevel.distant => (DistractorLevel.mixed, sameForm),
    };

    final shuffled = [...source]..shuffle(_random);
    return _Picked(chosen, shuffled.take(_distractorCount).toList());
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

/// Какая по счёту встреча атома в уроке и сколько их всего.
class _Slot {
  const _Slot({required this.index, required this.count});

  final int index;
  final int count;

  bool get isFirst => index == 0;
  bool get isLast => index == count - 1;
}

class _Picked {
  const _Picked(this.level, this.distractors);

  final DistractorLevel level;
  final List<Atom> distractors;
}
