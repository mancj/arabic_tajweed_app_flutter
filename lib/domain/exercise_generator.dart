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
  static const _maxPerAtom = 5;

  List<Exercise> build({
    required LessonPlan plan,
    required CurriculumContext ctx,
    required int sessionId,
  }) {
    plan.validate(curriculum, rules);
    // Отдельные буквы объяснены в начале. Соединённые формы добавляем
    // только при переходе к их блоку: срединная не должна стать вариантом
    // ответа, пока урок ещё знакомит с конечными.
    final pool = {
      ..._introducedAtoms(ctx),
      ...plan.newAtoms.where((a) => !_isConnectedForm(a)),
    };

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

    // Кого в этом уроке уже просили назвать вслух: ровно раз на букву за урок.
    final spoken = <String>{};
    final seen = <Atom, int>{};

    final exercises = <Exercise>[];
    for (final atom in schedule) {
      pool.addAll(fresh.where((a) => a.form == atom.form));
      final index = seen[atom] ?? 0;
      seen[atom] = index + 1;

      final ex = _make(
        atom,
        ctx,
        pool.toList(),
        sessionId,
        slot: _Slot(index: index, count: slots[atom]!),
        traced: traced,
        spoken: spoken,
        isReview: !plan.newAtoms.contains(atom),
        isTopicAtom: fresh.contains(atom) || review.contains(atom),
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
    // весь урок и буквы прошлых уроков не всплывают. А если тема сама
    // не заполняет урок, остаток тоже отдаётся повтору — урок не должен
    // кончаться на десятом задании только потому, что тема узкая. ТЗ §6.2.
    final reserved = min(rules.reviewPerSession, spaced.length);
    final forTopic = max(0, rules.tasksPerSession - reserved);

    // Весь материал плана получает обязательные задания. Вместимость
    // проверена заранее: здесь ни одна форма уже не может исчезнуть.
    final remaining = {
      for (final atom in {...fresh, ...review})
        atom: rules.minimumExercises(atom),
    };
    var available = forTopic - remaining.values.sum;
    if (remaining.isEmpty && spaced.isEmpty) return const [];

    // Новым небазовым формам тоже даём три встречи, если есть место.
    for (final atom in fresh.where(remaining.containsKey)) {
      final extra = min(available, _drillsPerNewAtom - remaining[atom]!);
      remaining[atom] = remaining[atom]! + extra;
      available -= extra;
    }
    final cap = remaining.isEmpty
        ? 0
        : min(forTopic, remaining.length * _maxPerAtom);
    final spacedSlots = spaced.take(rules.tasksPerSession - cap).toList();

    // Добираем до полного урока по кругу, пока не упрёмся в потолок.
    final atoms = remaining.keys.toList();
    var i = 0;
    var planned = remaining.values.sum;
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
    if (fresh.any(_isConnectedForm)) {
      // Все формы входят в один сеанс, но изучаются последовательными
      // блоками. Внутри блока сохраняется чередование букв.
      final byForm = result.groupListsBy((a) => a.form);
      return [
        for (final form in [
          null,
          LetterForm.isolated,
          LetterForm.finalForm,
          LetterForm.initial,
          LetterForm.medial,
        ])
          ...?byForm[form],
        ...spacedSlots,
      ];
    }
    return [...result, ...spacedSlots];
  }

  static bool _drillable(Atom atom) => atom.kind != AtomKind.concept;

  static bool _isConnectedForm(Atom atom) =>
      atom.form != null && atom.form != LetterForm.isolated;

  static bool _isBaseLetter(Atom atom) =>
      atom.letterId != null && atom.form == LetterForm.isolated;

  Exercise? _make(
    Atom atom,
    CurriculumContext ctx,
    List<Atom> pool,
    int sessionId, {
    required _Slot slot,
    required Set<String> traced,
    required Set<String> spoken,
    required bool isReview,
    required bool isTopicAtom,
  }) {
    final level = _levelFor(atom, ctx, sessionId);
    if (atom.kind == AtomKind.syllable) {
      return _connectionQuestion(atom, slot.index, isReview);
    }

    // Базовая буква темы обязательно проходит оба вида письма и голос,
    // даже при повторном открытии темы. При пяти встречах между ними
    // узнавание; при трёх-четырёх сначала сохраняем обязательные режимы.
    // У новой буквы сессия переносит голос сразу после её объяснения.
    final requiredPractice = isTopicAtom && _isBaseLetter(atom);
    if (requiredPractice) {
      final mode = switch (slot.index) {
        0 when atom.tracing != null => ExerciseMode.trace,
        _ when slot.isLast => ExerciseMode.sayName,
        _ when atom.tracing != null && slot.index == min(2, slot.count - 2) =>
          ExerciseMode.traceFromMemory,
        _ => null,
      };
      if (mode != null) {
        if (mode == ExerciseMode.sayName) spoken.add(atom.letterId!);
        return Exercise.direct(
          atom: atom,
          mode: mode,
          level: level,
          isReview: isReview,
        );
      }
    }

    // Слоты атома чередуются: активное задание — рука или голос — через
    // одно с узнаванием. Какие слоты активные, решает письмо; голос может
    // забрать активный слот себе, см. [_saysName]. У знакомой буквы
    // в повторении слот один, и без этого назвать её вслух не просили бы
    // никогда. Первую встречу новой буквы голос не берёт: обводка по
    // контуру остаётся первой.
    final p = ctx.progress[atom.id] ?? const AtomProgress();
    final active = !requiredPractice && _isActiveSlot(p, slot);
    final tracing = active
        ? _tracingMode(atom, p, slot, traced, isReview: isReview)
        : null;
    if (_saysName(atom, slot, spoken, isReview: isReview, activeSlot: active)) {
      return Exercise.direct(
        atom: atom,
        mode: ExerciseMode.sayName,
        level: level,
        isReview: isReview,
      );
    }

    // Обводка выбирается до дистракторов: это не запасной вариант на случай,
    // когда вариантов не набралось, а самостоятельное задание. Буква в нём
    // воспроизводится, а не узнаётся — только так атом доходит до mastered.
    if (tracing != null) {
      if (tracing == ExerciseMode.trace) traced.add(atom.id);
      return Exercise.direct(
        atom: atom,
        mode: tracing,
        level: level,
        isReview: isReview,
      );
    }

    // Формы одной буквы: «как она пишется в середине?» В вопросе показана
    // отдельная форма — та, с которой букву узнали. Когда спрашивают саму
    // отдельную, показывают любую другую введённую. В ответах — спрашиваемая
    // и остальные, кроме показанной: она уже на экране, выбирать её нет
    // смысла. Нужны хотя бы две формы кроме спрашиваемой, иначе вариант
    // всего один.
    final forms = _otherFormsOf(atom, pool);
    if (forms.length >= 2 && _random.nextInt(3) == 0) {
      final prompt =
          forms.firstWhereOrNull((f) => f.form == LetterForm.isolated) ??
          forms[_random.nextInt(forms.length)];
      final options = [atom, ...forms.where((f) => f != prompt)]
        ..shuffle(_random);
      return Exercise(
        atom: atom,
        mode: ExerciseMode.positionToForm,
        options: options,
        answerIndex: options.indexOf(atom),
        level: level,
        isReview: isReview,
        prompt: prompt,
      );
    }

    if (atom.kind == AtomKind.sign || atom.kind == AtomKind.haraka) {
      final options = [atom, ..._pickDistractors(atom, pool, level).distractors]
        ..shuffle(_random);
      return Exercise(
        atom: atom,
        mode: (slot.index + p.cleanStreak).isEven
            ? ExerciseMode.nameToForm
            : ExerciseMode.formToName,
        options: options,
        answerIndex: options.indexOf(atom),
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
      mode: ExerciseMode.soundToLetter,
      options: options,
      answerIndex: options.indexOf(atom),
      level: picked.level,
      isReview: isReview,
    );
  }

  /// Сочетания строятся из уже знакомых букв. Для первого блока
  /// соединения не нужны три заранее выученных слога или пустой холст.
  Exercise _connectionQuestion(Atom atom, int index, bool isReview) {
    final letters = curriculum.nodes
        .map((n) => n.atom)
        .where((a) => a.form == LetterForm.isolated)
        .toList();
    final parts = atom.display.runes
        .map(
          (r) => letters.firstWhere((a) => a.display == String.fromCharCode(r)),
        )
        .toList();
    final variants = [
      atom,
      Atom(
        id: '${atom.id}.reverse',
        kind: AtomKind.syllable,
        display: parts.reversed.map((a) => a.display).join(),
        label: parts.reversed.map((a) => a.label).join(' и '),
      ),
      Atom(
        id: '${atom.id}.repeat',
        kind: AtomKind.syllable,
        display: parts.first.display * parts.length,
        label: List.filled(parts.length, parts.first.label).join(' и '),
      ),
    ]..shuffle(_random);
    return Exercise(
      atom: atom,
      mode: index.isEven ? ExerciseMode.nameToForm : ExerciseMode.formToName,
      level: DistractorLevel.mixed,
      options: variants,
      answerIndex: variants.indexOf(atom),
      isReview: isReview,
    );
  }

  /// Когда за букву берётся холст, а не карточки с вариантами.
  ///
  /// Порядок всегда один: сначала по контуру, потом по памяти. Просить
  /// написать по памяти букву, которую человек ни разу не вёл рукой, —
  /// это проверка до обучения.
  ///
  /// Письмо идёт через задание: первый слот — по контуру, если букву ещё
  /// ни разу не вели рукой, дальше по памяти через одно, а между ними
  /// узнавание. Так письмо и карточки делят слоты атома поровну: одно
  /// письмо на урок оставляло букву в основном карточкам, а урок из одного
  /// письма был бы рисованием, а не чтением. У буквы с единственным слотом
  /// письмо по памяти — иначе освоенная буква возвращалась бы только
  /// карточками.
  ///
  /// Букву из повторения по памяти просим, только когда она уже освоена:
  /// на середине пути повторению полезнее узнавание, а письмо по памяти
  /// там превращается в экзамен не вовремя.
  /// Активные слоты атома — те, где букву воспроизводят рукой или голосом,
  /// а не узнают среди карточек. Идут через один: у новой буквы с первого
  /// слота (там контур), у уже писавшейся — со второго. Единственный слот
  /// всегда активный, иначе освоенная буква возвращалась бы только
  /// карточками. Наличие контура на это не влияет: у буквы без SVG активный
  /// слот достаётся голосу или, если и он не выпал, карточке.
  bool _isActiveSlot(AtomProgress p, _Slot slot) {
    if (slot.count == 1) return true;
    final firstActive = p.hadActiveSuccess ? 1 : 0;
    return (slot.index - firstActive).isEven;
  }

  /// Чем пишут в активном слоте. Вызывается только для активных слотов.
  ExerciseMode? _tracingMode(
    Atom atom,
    AtomProgress p,
    _Slot slot,
    Set<String> traced, {
    required bool isReview,
  }) {
    // Фигура есть не у всякого атома: у понятий и слогов её нет вовсе.
    if (atom.tracing == null) return null;

    final wroteBefore = p.hadActiveSuccess || traced.contains(atom.id);
    if (!wroteBefore) return slot.isFirst ? ExerciseMode.trace : null;
    if (isReview && p.state.index < AtomState.known.index) return null;
    return ExerciseMode.traceFromMemory;
  }

  /// Когда букву просят назвать вслух.
  ///
  /// Только отдельная форма: имя у буквы одно на все формы, и спрашивать
  /// его у каждой — четыре раза одно и то же. Не на первой встрече в уроке:
  /// сначала букву узнают среди вариантов, потом просят назвать. У буквы
  /// из повторения первая встреча в уроке не первая вообще — её можно
  /// спросить сразу. Ровно раз на букву за урок, иначе урок превращается в
  /// диктовку или оставляет букву без произношения. Только в активном слоте —
  /// том, что иначе ушёл бы письму: голос не ломает чередование с узнаванием.
  bool _saysName(
    Atom atom,
    _Slot slot,
    Set<String> spoken, {
    required bool isReview,
    required bool activeSlot,
  }) {
    final letterId = atom.letterId;
    if (letterId == null || atom.form != LetterForm.isolated) return false;
    if (!activeSlot) return false;
    if (slot.isFirst && !isReview) return false;
    if (spoken.contains(letterId)) return false;
    spoken.add(letterId);
    return true;
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
        .where(
          (a) => a.id != atom.id && a.form == atom.form && a.kind == atom.kind,
        )
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

  /// Остальные введённые формы той же буквы — варианты для вопроса
  /// «как она пишется в этой позиции?» и то, что показать в самом вопросе.
  List<Atom> _otherFormsOf(Atom atom, List<Atom> pool) => atom.form == null
      ? const []
      : pool
            .where((a) => a.letterId == atom.letterId && a.id != atom.id)
            .where((a) => a.form != null)
            .toList();

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
