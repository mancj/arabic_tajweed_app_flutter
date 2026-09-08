import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/curriculum_loader.dart';
import '../../../data/letter_audio.dart';
import '../../../data/progress_database.dart';
import '../../../data/progress_repository.dart';
import '../../../domain/atom.dart';
import '../../../domain/atom_state.dart';
import '../../../domain/audio_track.dart';
import '../../../domain/curriculum.dart';
import '../../../domain/exercise.dart';
import '../../../domain/exercise_generator.dart';
import '../../../domain/learning_rules.dart';
import '../../../domain/lesson_session.dart';
import '../../../domain/topic_board.dart';
import '../../../domain/planner.dart';
import '../../../domain/progress_event.dart';
import '../../widgets/drawing/drawing_canvas.dart';
import '../../widgets/drawing/tracing_shape_svg.dart';

/// Что показывает экран прямо сейчас.
enum LessonStage { loading, intro, exercise, finished }

class LessonController extends GetxController {
  LessonController({
    LearningRules? rules,
    ProgressDatabase? database,
    Curriculum? curriculum,
    String? topicId,
    Future<TracingShape> Function(String asset)? shapeLoader,
    LetterAudio? audio,
  }) : rules = rules ?? const LearningRules(),
       _database = database,
       _injectedCurriculum = curriculum,
       _topicId = topicId,
       _shapeLoader = shapeLoader ?? _loadShapeAsset,
       _audio = audio ?? LetterAudio();

  final LearningRules rules;

  /// В тестах база подставляется в памяти; в приложении берётся из Get.
  final ProgressDatabase? _database;

  /// Готовый граф вместо чтения ассета — нужен тестам.
  final Curriculum? _injectedCurriculum;

  /// Если задан, урок собирается по конкретной теме, а не спрашивается
  /// у планировщика: нажали на строку — работаем с этой темой.
  final String? _topicId;

  /// Откуда берутся фигуры для обводки. В тестах подставляется, чтобы
  /// не ходить в ассеты.
  final Future<TracingShape> Function(String asset) _shapeLoader;

  final stage = LessonStage.loading.obs;
  final loadError = RxnString();
  final _refresh = 0.obs;

  /// Атомы блока «новое»: показываем без проверки, потом спрашиваем.
  final introAtoms = <Atom>[].obs;
  final introIndex = 0.obs;

  /// Выбранный вариант — до нажатия «Далее» ответ ещё можно передумать.
  final selected = Rxn<int>();
  final wasWrong = false.obs;

  /// Холст обводки. Один на весь урок: между заданиями он очищается,
  /// а не пересоздаётся.
  final drawing = DrawingController(smoothing: 1, minDistance: 3);

  /// Фигура текущего задания. null — обводить нечего, показываем заглушку.
  final tracingShape = Rxn<TracingShape>();

  /// Подсказка под холстом: что рисовать дальше или что не сошлось.
  final tracingHint = ''.obs;

  /// С чего начинается любая буква: холст ждёт части по порядку.
  static const _tracingStartHint = 'Начните с основы буквы';

  /// В режиме по памяти буква собралась целиком — можно засчитывать.
  final tracingDone = false.obs;

  /// Разобранные SVG: одна и та же буква встречается в уроке не раз.
  final _shapes = <String, TracingShape>{};

  /// Карточка перед текущим заданием. Формы букв объясняются там, где
  /// впервые встречаются, а не списком в начале урока: соединение — это
  /// не десять правил подряд, а одно правило на каждую новую связку.
  final card = Rxn<Atom>();

  /// Чьи карточки в этом уроке уже показаны.
  final _shownCards = <String>{};

  /// Атомы, которым этот урок посвящён. Блок повтора приводит буквы
  /// из прошлых уроков, и объяснять их заново — не дело этого урока:
  /// карточка показывается только для своего материала.
  final _ownAtoms = <String>{};

  /// Голос буквы. Один плеер на урок: новое нажатие обрывает предыдущий
  /// звук, а не накладывается на него.
  /// В тестах подставляется с плеером под известным именем: у настоящего
  /// имя случайное, и его каналы нечем подменить.
  final LetterAudio _audio;

  /// Есть ли у атома запись. У понятий, слогов и хамзы её пока нет.
  bool hasVoice(Atom atom) => LetterAudio.has(atom.letterId);

  /// Нажатие на кнопку звучания: играет, ставит на паузу или продолжает —
  /// решает сам плеер, экрану знать об этом нечего.
  void playVoice(Atom atom) => unawaited(_audio.toggle(atom.letterId));

  /// Звучание при появлении буквы: всегда с начала. Нажатие звучащую букву
  /// останавливает, а показ следующей формы той же буквы — не должен.
  void startVoice(Atom atom) => unawaited(_audio.play(atom.letterId));

  /// Что сейчас звучит: форма записи и позиция. Карточка отдаёт это волне.
  ValueListenable<AudioTrack> get voiceTrack => _audio.track;

  /// Пороги совпадения у холста и у сообщений должны быть одни и те же.
  static const tracingMatcher = TracingMatcher();

  late final Curriculum _curriculum;
  late final ProgressRepository _progress;
  LessonSession? _session;
  LessonPlan? _plan;
  DateTime _shownAt = DateTime.now();

  /// Номер сессии — следующий за последним в логе. От него зависят очередь
  /// повторений, откладывание атомов и гарантия темпа.
  late final int _sessionId;

  /// Урок собран по теме, а не выдан планировщиком.
  bool get isTopicLesson => _topicId != null;

  /// Заголовок экрана: повторением урок считается, только если ничего
  /// нового в нём нет.
  bool get isReviewOnly => isTopicLesson && (_plan?.newAtoms.isEmpty ?? false);

  Exercise? get current {
    _refresh.value;
    return _session?.current;
  }

  double get progress {
    _refresh.value;
    return _session?.progress ?? 0;
  }

  Atom? get introAtom => introIndex.value < introAtoms.length
      ? introAtoms[introIndex.value]
      : null;

  @override
  void onInit() {
    super.onInit();
    // Ошибку загрузки нельзя глотать: без неё экран навсегда останется
    // на индикаторе, и причина будет невидима.
    unawaited(
      _start().catchError((Object e, StackTrace st) {
        loadError.value = '$e';
        stage.value = LessonStage.finished;
        Error.throwWithStackTrace(e, st);
      }),
    );
  }

  Future<void> _start() async {
    _curriculum = _injectedCurriculum ?? await const CurriculumLoader().load();
    _progress = ProgressRepository(
      database: _database ?? Get.find<ProgressDatabase>(),
      rules: rules,
    );

    final ctx = await _context();
    _sessionId = await _progress.nextSessionId();
    _plan = _topicId == null
        ? LessonPlanner(curriculum: _curriculum, rules: rules).plan(
            ctx: ctx,
            sessionId: _sessionId,
            sessionsWithoutNew: await _progress.sessionsWithoutNew(),
          )
        : _topicPlan(ctx);

    _ownAtoms
      ..clear()
      ..addAll(
        _topicId == null
            ? _plan!.newAtoms.map((a) => a.id)
            : _curriculum.topics
                      .firstWhereOrNull((t) => t.id == _topicId)
                      ?.counterOf ??
                  const [],
      );

    introAtoms.assignAll(_introFor(_plan!));
    stage.value = introAtoms.isEmpty ? LessonStage.exercise : LessonStage.intro;
    if (introAtoms.isEmpty) await _buildSession();
    _shownAt = DateTime.now();
  }

  /// Что показать в блоке «новое».
  ///
  /// Обычно это новые атомы урока. В повторении темы, где вводить нечего,
  /// показываем её понятия: спросить их заданием нельзя, поэтому
  /// «повторить понятие» означает перечитать объяснение.
  List<Atom> _introFor(LessonPlan plan) {
    if (!isTopicLesson) return plan.newAtoms.where(_belongsToIntro).toList();

    // Урок по теме показывает её объяснения целиком — и новые, и знакомые.
    // Человек сам выбрал эту тему, значит хочет пройти её заново, а не
    // получить огрызок из того, что он ещё не доучил.
    final inLesson = {
      for (final atom in plan.newAtoms) atom.id: atom,
      for (final id in plan.reviewAtoms)
        if (_atomById(id) case final atom?) id: atom,
    };

    final topic = _curriculum.topics.firstWhereOrNull((t) => t.id == _topicId);

    // Порядок берём из темы: он и есть порядок объяснений в уроке.
    return [
      for (final id in topic?.counterOf ?? const <String>[])
        if (inLesson[id] case final atom?)
          if (_belongsToIntro(atom) && atom.note.isNotEmpty) atom,
    ];
  }

  /// Что объясняется в начале урока, а что по ходу.
  ///
  /// Понятия и изолированные начертания идут вперёд: сначала показываем
  /// буквы, потом спрашиваем. Соединённые формы — нет: девять карточек
  /// подряд про начало, середину и конец читаются как один длинный текст,
  /// из которого не запоминается ничего.
  bool _belongsToIntro(Atom atom) =>
      atom.form == null || atom.form == LetterForm.isolated;

  Atom? _atomById(String id) =>
      _curriculum.nodes.firstWhereOrNull((n) => n.atom.id == id)?.atom;

  /// Урок по теме: набор атомов задан ею, планировщик не нужен.
  LessonPlan _topicPlan(CurriculumContext ctx) {
    final topic = _curriculum.topics.firstWhere((m) => m.id == _topicId);
    return TopicBoard(
      _curriculum,
    ).planFor(topic, ctx, sessionId: _sessionId, rules: rules);
  }

  Future<CurriculumContext> _context() async => CurriculumContext(
    progress: await _progress.progress(),
    formsByLetter: _formsByLetter(),
  );

  /// Какая буква из каких форм состоит — нужно, чтобы считать «буква
  /// в known» как «все её формы в known».
  Map<String, List<String>> _formsByLetter() {
    final result = <String, List<String>>{};
    for (final node in _curriculum.nodes) {
      final letterId = node.atom.letterId;
      if (letterId == null) continue;
      (result[letterId] ??= []).add(node.atom.id);
    }
    return result;
  }

  /// Блок «новое»: атом показан, но ещё не спрошен.
  Future<void> nextIntro() async {
    final atom = introAtom;
    if (atom != null) {
      await _progress.record(
        AtomIntroduced(
          atomId: atom.id,
          sessionId: _sessionId,
          at: DateTime.now(),
        ),
      );
    }
    introIndex.value++;
    if (introAtom != null) return;

    // _buildSession сам ставит finished, если спрашивать нечего:
    // затирать это переходом в exercise нельзя.
    await _buildSession();
    if (stage.value != LessonStage.finished) {
      stage.value = LessonStage.exercise;
      _shownAt = DateTime.now();
    }
  }

  Future<void> _buildSession() async {
    final ctx = await _context();
    final exercises = ExerciseGenerator(
      curriculum: _curriculum,
      rules: rules,
    ).build(plan: _plan!, ctx: ctx, sessionId: _sessionId);

    _session = LessonSession(
      exercises: exercises,
      sessionId: _sessionId,
      rules: rules,
    );
    await _loadShapes(exercises);
    if (exercises.isEmpty) stage.value = LessonStage.finished;
    _refresh.value++;
    _syncCard();
    _syncTracing();
  }

  /// Фигуры разбираются один раз на урок, до первого задания: иначе холст
  /// мигал бы пустым, пока грузится SVG.
  Future<void> _loadShapes(List<Exercise> exercises) async {
    final names = exercises
        .where((e) => e.mode.isTracing)
        .map((e) => e.atom.tracing)
        .nonNulls
        .toSet();

    for (final name in names) {
      if (_shapes.containsKey(name)) continue;
      try {
        _shapes[name] = await _shapeLoader(name);
      } catch (_) {
        // Файла нет или он не разбирается: задание покажет заглушку.
        // Ронять из-за этого весь урок нельзя.
      }
    }
  }

  static Future<TracingShape> _loadShapeAsset(String asset) =>
      TracingShapeSvg.load('assets/svg/alphabet/$asset.svg', id: asset);

  /// Готовит холст под текущее задание: чистит нарисованное, подставляет
  /// фигуру и возвращает подсказку в исходное состояние.
  /// Нужна ли карточка перед текущим заданием. Показывается один раз
  /// за урок: второй встрече той же формы объяснение уже не нужно.
  void _syncCard() {
    final atom = _session?.current?.atom;
    final needed =
        atom != null &&
        atom.note.isNotEmpty &&
        !_belongsToIntro(atom) &&
        _ownAtoms.contains(atom.id) &&
        _shownCards.add(atom.id);
    card.value = needed ? atom : null;
  }

  /// Карточка прочитана: атом записывается как показанный, и урок
  /// возвращается к заданию.
  Future<void> dismissCard() async {
    final atom = card.value;
    if (atom == null) return;

    await _progress.record(
      AtomIntroduced(
        atomId: atom.id,
        sessionId: _sessionId,
        at: DateTime.now(),
      ),
    );
    card.value = null;
    // Время на ответ считается с закрытия карточки: чтение объяснения
    // не должно превращать верный ответ в медленный.
    _shownAt = DateTime.now();
  }

  void _syncTracing() {
    final exercise = _session?.current;
    final name = exercise != null && exercise.mode.isTracing
        ? exercise.atom.tracing
        : null;

    drawing.clear();
    tracingDone.value = false;
    tracingShape.value = name == null ? null : _shapes[name];
    // Строка под сеткой — только обратная связь: что рисовать дальше
    // и что не сошлось. Само задание написано в шапке карточки, и дублировать
    // его здесь незачем.
    tracingHint.value = tracingShape.value == null ? '' : _tracingStartHint;
  }

  /// Задание, где вместо вариантов холст.
  bool get isTracingTask {
    _refresh.value;
    final exercise = _session?.current;
    return exercise != null &&
        exercise.mode.isTracing &&
        tracingShape.value != null;
  }

  /// Холст показывает контур: в режиме обводки всегда, а в режиме по памяти —
  /// после ошибки, когда контур и есть показ верного ответа.
  TracingMode get canvasMode {
    _refresh.value;
    return _session?.current?.mode == ExerciseMode.trace || wasWrong.value
        ? TracingMode.tracing
        : TracingMode.freehand;
  }

  /// Стереть нарисованное и начать букву заново. Собранные части холст
  /// откатывает сам, вслед за исчезнувшими штрихами. После разбора ошибки
  /// подсказку не трогаем: там на холсте показан верный ответ.
  void clearTracing() {
    drawing.clear();
    if (wasWrong.value) return;
    tracingDone.value = false;
    tracingHint.value = _tracingStartHint;
  }

  /// Части буквы засчитываются по одной — и по контуру, и по памяти:
  /// проверять нечего, ответ готов, когда собрана последняя.
  void onTracingProgress(TracingProgress progress) {
    if (wasWrong.value) return;
    tracingHint.value = progress.isComplete
        ? 'Буква собрана'
        : 'Нарисуйте: ${progress.nextLabel ?? 'букву'}';
  }

  void onTracingMerged() {
    if (wasWrong.value) return;
    tracingDone.value = true;
    tracingHint.value = 'Буква собрана';
  }

  /// Холст сам показал, как пишется, после серии промахов, см.
  /// [DrawingCanvas.missesBeforeReveal]. Это не ошибка и не разбор: контур
  /// остаётся, человек обводит по нему, и собранная буква засчитывается
  /// верным ответом. Строгость проверки не меняется — подсказка честнее,
  /// чем сниженная планка, — а ошибкой обводка становится только по
  /// кнопке «Не помню». См. SPEC.md §5.
  void onTracingRevealed() {
    if (wasWrong.value) return;
    tracingHint.value = 'Обведите по подсказке';
  }

  /// Ошибка в обводке: ответ засчитан как неверный, холст очищен, и на нём
  /// открывается контур — показ сам запускается на чистом холсте.
  Future<void> _revealTracing() async {
    await submit(directOutcome: false);
    if (wasWrong.value) drawing.clear();
  }

  /// «Не помню» в режиме по памяти: ответ засчитывается ошибкой, а контур
  /// открывается — иначе человек застревает на букве, которую не помнит.
  Future<void> giveUpTracing() => _revealTracing();

  /// У заданий без выбора нечего выделять — кнопка активна сразу.
  /// Исключение — письмо: там ответ готов, только когда буква собрана
  /// целиком, независимо от того, был ли перед глазами контур.
  bool get canSubmit {
    _refresh.value;
    final exercise = _session?.current;
    if (exercise == null) return false;
    if (exercise.isChoice) return selected.value != null;
    if (exercise.mode.isTracing && tracingShape.value != null) {
      return tracingDone.value || wasWrong.value;
    }
    return true;
  }

  void select(int index) {
    if (wasWrong.value) return;
    selected.value = index;
  }

  /// Ответ засчитывается по нажатию «Далее», а не по тапу по карточке:
  /// иначе случайное касание стоит атому отката.
  /// Пропустить задание. Только для отладочных сборок: даёт быстро дойти
  /// до нужного экрана, не отвечая. Ответ в лог не пишется, поэтому
  /// прогресс букв не искажается.
  Future<void> skipExercise() async {
    final session = _session;
    if (session == null || session.current == null) return;

    session.skip();
    selected.value = null;
    wasWrong.value = false;
    _shownAt = DateTime.now();
    _refresh.value++;
    _syncCard();
    _syncTracing();
    if (session.isFinished) await _finish();
  }

  /// ВРЕМЕННОЕ. У заданий-заглушек нет своей проверки, поэтому исход
  /// задаёт кнопка: одна засчитывает верно, другая — мимо. Нужно, чтобы
  /// гонять ветку с ошибками, пока обводка и сборка не написаны.
  /// TODO(stub): убрать вместе с заглушками, см. SPEC.md §4.
  Future<void> submitStub({required bool correct}) =>
      submit(directOutcome: correct);

  /// [directOutcome] — исход задания без вариантов: обводку судит холст,
  /// а у оставшихся заглушек его задаёт кнопка.
  Future<void> submit({bool? directOutcome}) async {
    final session = _session;
    final exercise = session?.current;
    if (session == null || exercise == null) return;

    // У заглушки нет своей проверки: исход приходит от кнопки, по умолчанию
    // верный. Отрицательный индекс сессия трактует как ошибку.
    final choice = exercise.isChoice
        ? selected.value
        : ((directOutcome ?? true)
              ? Exercise.directAnswer
              : Exercise.directMiss);
    if (choice == null) return;

    if (wasWrong.value) {
      // Верный ответ уже показан — это подтверждение, а не новая попытка.
      wasWrong.value = false;
      selected.value = null;
      _refresh.value++;
      // Холст после разбора чистый: задание осталось тем же, и человек
      // пишет букву заново, а не поверх своей ошибки.
      if (exercise.mode.isTracing) _syncTracing();
      return;
    }

    final elapsed = DateTime.now().difference(_shownAt);
    final outcome = session.answer(
      exercise,
      choice,
      fastEnough: elapsed <= _speedLimit(exercise.mode),
    );

    // Пишем сразу, а не в конце сессии: лог должен пережить убитое
    // приложение, иначе ответы теряются молча.
    await _progress.record(session.log.last);

    if (outcome == AnswerOutcome.wrong) {
      wasWrong.value = true;
      return;
    }

    selected.value = null;
    _shownAt = DateTime.now();
    _refresh.value++;
    _syncCard();
    _syncTracing();
    if (session.isFinished) await _finish();
  }

  /// TODO(speed): пороги подлежат калибровке, и у аудио с обводкой они
  /// другие. См. SPEC.md §4.
  Duration _speedLimit(ExerciseMode mode) =>
      mode.isTracing ? const Duration(seconds: 40) : const Duration(seconds: 3);

  Future<void> _finish() async {
    // «Пройден» — это факт о занятии, а не о знании: человек дошёл до конца
    // сессии. Освоенность букв добирается повторениями и на отметку
    // не влияет — иначе закрытый урок выглядит недоделанным.
    final topicId = _topicId;
    if (topicId != null) {
      await _progress.completeTopic(topicId, sessionId: _sessionId);
    }
    stage.value = LessonStage.finished;
  }

  /// Итог урока: какие атомы поднялись до известных.
  Future<List<Atom>> learned() async {
    final progress = await _progress.progress();
    return introAtoms
        .where(
          (a) =>
              (progress[a.id]?.state ?? AtomState.fresh).index >=
              AtomState.learning.index,
        )
        .toList();
  }

  String get planReason => _plan?.reason ?? '';

  @override
  void onClose() {
    drawing.dispose();
    unawaited(_audio.dispose());
    super.onClose();
  }
}
