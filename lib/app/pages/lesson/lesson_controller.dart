import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../data/curriculum_loader.dart';
import '../../../data/letter_audio.dart';
import '../../../data/progress_database.dart';
import '../../../data/progress_repository.dart';
import '../../../data/pronunciation_checker.dart';
import '../../../data/pronunciation_preference.dart';
import '../../../data/rest/letter_check.dart';
import '../../../data/rest/pronunciation_rest_client.dart';
import '../../../data/shared_preference_manager.dart';
import '../../../data/voice_recorder.dart';
import '../../../domain/atom.dart';
import '../../../domain/atom_state.dart';
import '../../../domain/audio_track.dart';
import '../../../domain/curriculum.dart';
import '../../../domain/exercise.dart';
import '../../../domain/exercise_generator.dart';
import '../../../domain/learning_rules.dart';
import '../../../domain/lesson_session.dart';
import '../../../domain/lesson_pacing.dart';
import '../../../domain/topic_board.dart';
import '../../../domain/planner.dart';
import '../../../domain/progress_event.dart';
import '../../shared_state/app_clock.dart';
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
    LessonPlan? plan,
    this.continuePlanning = false,
    Future<TracingShape> Function(String asset)? shapeLoader,
    LetterAudio? audio,
    VoiceRecorder? recorder,
    PronunciationRestClient? pronunciation,
    PronunciationPreference? pronunciationPreference,
    AppClock? clock,
  }) : _baseRules = rules ?? const LearningRules(),
       _database = database,
       _injectedCurriculum = curriculum,
       _topicId = topicId,
       _previewPlan = plan,
       _injectedPronunciationPreference = pronunciationPreference,
       _clock =
           clock ??
           (Get.isRegistered<AppClock>() ? Get.find<AppClock>() : AppClock()),
       _shapeLoader = shapeLoader ?? _loadShapeAsset,
       _audio = audio ?? LetterAudio(),
       pronunciation = PronunciationChecker(
         recorder: recorder,
         client: pronunciation,
       );

  final LearningRules _baseRules;

  LearningRules get rules => _baseRules.copyWith(
    requirePronunciation:
        _baseRules.requirePronunciation &&
        _pronunciationRequired &&
        _pronunciationAvailable,
  );

  /// Обычное занятие может добирать повторение до общего бюджета. Один урок
  /// вводит не больше одного цельного блока нового материала; смешанное
  /// повторение тоже всегда остаётся отдельным занятием без нового.
  final bool continuePlanning;

  /// В тестах база подставляется в памяти; в приложении берётся из Get.
  final ProgressDatabase? _database;
  final AppClock _clock;

  /// Готовый граф вместо чтения ассета — нужен тестам.
  final Curriculum? _injectedCurriculum;
  final PronunciationPreference? _injectedPronunciationPreference;

  /// Если задан, урок собирается по конкретной теме, а не спрашивается
  /// у планировщика: нажали на строку — работаем с этой темой.
  String? _topicId;
  final LessonPlan? _previewPlan;

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

  /// Номер ошибки в задании с четырьмя формами. После разбора виджет получает
  /// новый ключ и начинает следующую попытку с сохранёнными подсказками.
  final formSequenceAttempt = 0.obs;
  List<bool>? _formSequenceSlotResults;
  List<Atom?> _formSequenceInitialPlaced = const [];
  bool _revealFormSequenceAnswer = false;

  List<bool>? get formSequenceSlotResults => _formSequenceSlotResults;
  List<Atom?> get formSequenceInitialPlaced => _formSequenceInitialPlaced;
  bool get revealFormSequenceAnswer => _revealFormSequenceAnswer;
  int get formSequenceCorrectCount =>
      _formSequenceSlotResults?.where((result) => result).length ?? 0;

  /// Правильный ответ показывается до перехода, чтобы человек успел увидеть
  /// результат и понять, что именно засчиталось.
  final wasCorrect = false.obs;

  /// Имя буквы в задании на слух показано по просьбе: звук выключен или
  /// не слышно. Само по себе оно в задании не появляется.
  final nameRevealed = false.obs;

  void revealName() => nameRevealed.value = true;

  /// Холст обводки. Один на весь урок: между заданиями он очищается,
  /// а не пересоздаётся.
  final drawing = DrawingController();

  /// Фигура текущего задания. null — обводить нечего, показываем заглушку.
  final tracingShape = Rxn<TracingShape>();

  /// Подсказка под холстом: что рисовать дальше или что не сошлось.
  final tracingHint = ''.obs;

  /// С чего начинается любая буква: холст ждёт части по порядку.
  static const _tracingStartHint = 'Начните с основы буквы';

  /// В режиме по памяти буква собралась целиком — можно засчитывать.
  final tracingDone = false.obs;

  /// В режиме по памяти контур открыт как подсказка, а не как результат.
  final tracingGuideVisible = false.obs;

  /// Разобранные SVG: одна и та же буква встречается в уроке не раз.
  final _shapes = <String, TracingShape>{};

  /// Карточка перед текущим заданием. Формы букв объясняются там, где
  /// впервые встречаются, а не списком в начале урока: соединение — это
  /// не десять правил подряд, а одно правило на каждую новую связку.
  final card = Rxn<Atom>();

  /// Перед первой подробной карточкой буквы показываем все её формы вместе.
  /// Это обзор, а не атом: он не пишет событие и не влияет на прогресс.
  final formsOverview = <Atom>[].obs;

  final _shownFormsOverviews = <String>{};

  /// Чьи карточки в этом уроке уже показаны.
  final _shownCards = <String>{};

  /// Объясняем также новые формы в вариантах ответа, прежде чем показать
  /// сам вопрос. Иначе узнавание проверяло бы ещё не показанный материал.
  final _pendingCards = <Atom>[];

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

  /// Задание «назови букву»: запись и проверка на сервере. Цепочка общая
  /// с экраном тренировки, здесь решается только, что делать с ответом.
  final PronunciationChecker pronunciation;

  /// Номер записи в текущем задании. После первого промаха сервер
  /// подсказывает, что услышал, и даётся ещё одна, см.
  /// [LearningRules.sayNameAttempts].
  final sayAttempt = 1.obs;

  bool get isSayNameTask {
    _refresh.value;
    return current?.mode == ExerciseMode.sayName;
  }

  /// Палец лёг на кнопку: начать запись. После разбора ошибки не пишем —
  /// сначала «Ясно».
  Future<void> startRecording() async {
    if (wasWrong.value) return;
    await pronunciation.start();
  }

  /// Палец поднят: остановить запись, спросить сервер и рассудить ответ.
  Future<void> stopRecording() async {
    final exercise = _session?.current;
    if (exercise == null) return;
    final result = await pronunciation.stop(expected: exercise.atom.display);
    // Ответ пришёл на другое задание — например, после пропуска.
    if (result == null || _session?.current != exercise) return;
    await _judgePronunciation(result);
  }

  /// Совпало — ответ верный. Не совпало: плохая запись (тихо, шумно)
  /// попытку не тратит, первый настоящий промах даёт ещё одну, последний
  /// засчитывается ошибкой — дальше как в остальных режимах.
  Future<void> _judgePronunciation(LetterCheck result) async {
    if (result.matched) {
      await submit(directOutcome: true);
      return;
    }
    if (result.recording.warning != null) return;
    if (sayAttempt.value < rules.sayNameAttempts) {
      sayAttempt.value++;
      return;
    }
    await submit(directOutcome: false);
  }

  /// Новое задание — прошлые записи и подсказки к делу не относятся.
  void _syncPronunciation() {
    pronunciation.reset();
    sayAttempt.value = 1;
  }

  late final Curriculum _curriculum;
  late final ProgressRepository _progress;
  LessonSession? _session;
  Exercise? _answeredExercise;
  bool _returnToIntro = false;
  LessonPlan? _plan;
  DateTime _shownAt = DateTime.now();
  int _completedExercises = 0;
  final _askedCounts = <String, int>{};
  final _formSequenceLetters = <String>{};
  final _sessionIntroduced = <String, Atom>{};
  final _planReasons = <String>[];
  final _firstAttemptResults = <bool>[];
  bool _hasNewMaterial = false;
  LessonPurpose _sessionPurpose = LessonPurpose.standard;
  int? _sessionCheckpointLetters;
  bool _sessionSummaryRecorded = false;
  bool _pronunciationRequired = true;
  bool _pronunciationAvailable = true;
  late final PronunciationPreference? _pronunciationPreference;
  int? _pronunciationSessionId;
  bool _currentBlockEndsSession = false;
  int? _sessionTarget;

  /// Номер сессии — следующий за последним в логе. От него зависят очередь
  /// повторений, откладывание атомов и гарантия темпа.
  late final int _sessionId;

  /// Урок собран по теме, а не выдан планировщиком.
  bool get isTopicLesson => _topicId != null;

  /// Заголовок экрана: повторением урок считается, только если ничего
  /// нового в нём нет.
  bool get isReviewOnly {
    _refresh.value;
    return !_hasNewMaterial;
  }

  List<Atom> get sessionIntroduced => _sessionIntroduced.values.toList();

  Exercise? get current {
    _refresh.value;
    // После ответа сессия уже указывает на следующее задание, но экран ещё
    // показывает прежнее — включая анимацию слияния и окно результата.
    // Иначе холст пересоздаётся, теряет собранные SVG-части и показывает
    // сохранённые штрихи пользователя.
    return _answeredExercise ?? _session?.current;
  }

  double get progress {
    _refresh.value;
    if (!continuePlanning && _pronunciationAvailable) {
      return _session?.progress ?? 0;
    }
    final done = _completedExercises + (_session?.position ?? 0);
    return (done / (_sessionTarget ?? rules.tasksPerSession)).clamp(0, 1);
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
    _pronunciationPreference =
        _injectedPronunciationPreference ??
        (Get.isRegistered<SharedPreferenceManager>()
            ? PronunciationPreference(Get.find<SharedPreferenceManager>())
            : null);
    final pronunciationDisabled = _pronunciationPreference?.isDisabled ?? false;
    _pronunciationRequired =
        _baseRules.requirePronunciation && !pronunciationDisabled;
    _pronunciationAvailable = _pronunciationRequired;
    if (_pronunciationAvailable) {
      _pronunciationSessionId = await _pronunciationPreference?.beginSession();
    }
    _curriculum = _injectedCurriculum ?? await const CurriculumLoader().load();
    _progress = ProgressRepository(
      database: _database ?? Get.find<ProgressDatabase>(),
      rules: rules,
      letterFormIds: _curriculum.letterFormIds,
      baseLetterIds: _curriculum.baseLetterIds,
      now: () => _clock.now,
    );

    final ctx = await _context();
    _sessionId = await _progress.nextSessionId();
    final initialPlan =
        _previewPlan ??
        (_topicId == null
            ? LessonPlanner(curriculum: _curriculum, rules: rules).plan(
                ctx: ctx,
                sessionId: _sessionId,
                sessionsWithoutNew: await _progress.sessionsWithoutNew(),
                pacing: await _progress.pacing(),
              )
            : _topicPlan(ctx));
    await _activatePlan(initialPlan, taskLimit: rules.tasksPerSession);
    _shownAt = DateTime.now();
  }

  Future<void> _activatePlan(
    LessonPlan plan, {
    required int taskLimit,
    bool? endsSession,
  }) async {
    plan.validate(_curriculum, rules, taskLimit: taskLimit);
    _plan = plan;
    if (_planReasons.isEmpty) {
      _sessionPurpose = plan.purpose;
      _sessionCheckpointLetters = plan.checkpointLetters;
    }
    _currentBlockEndsSession =
        endsSession ??
        (plan.purpose.isMixedReview ||
            (continuePlanning && plan.newAtoms.isNotEmpty));
    _topicId = plan.topicId ?? _topicId;
    _planReasons.add(plan.reason);
    _hasNewMaterial = _hasNewMaterial || plan.newAtoms.isNotEmpty;

    _ownAtoms.addAll(
      plan.isFocusedReview || _topicId == null
          ? plan.newAtoms.map((atom) => atom.id)
          : _curriculum.topics
                    .firstWhereOrNull((topic) => topic.id == _topicId)
                    ?.counterOf ??
                const [],
    );

    final intro = _introFor(plan);
    introAtoms.assignAll(intro);
    introIndex.value = 0;
    for (final atom in intro) {
      _sessionIntroduced[atom.id] = atom;
    }
    _session = null;
    _returnToIntro = false;
    card.value = null;
    formsOverview.clear();
    if (introAtoms.isEmpty) {
      // Сначала готовим объяснение первой формы и холст, затем открываем
      // задание. Иначе темы без intro успевали показать вопрос без карточки.
      await _buildSession(taskLimit: taskLimit);
      if (stage.value != LessonStage.finished) {
        stage.value = LessonStage.exercise;
      }
    } else {
      stage.value = LessonStage.intro;
    }
  }

  /// Что показать в блоке «новое».
  ///
  /// Обычно это новые атомы урока. В повторении темы, где вводить нечего,
  /// показываем её понятия: спросить их заданием нельзя, поэтому
  /// «повторить понятие» означает перечитать объяснение.
  List<Atom> _introFor(LessonPlan plan) {
    if (plan.isFocusedReview) return const [];
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
          if (_belongsToIntro(atom)) atom,
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

  /// Номер текущего задания в сессии. Карточки вопроса ключуются по нему:
  /// новая буква спрашивается несколько раз подряд, и ключ по атому
  /// не отличил бы одно задание от следующего.
  int get exerciseIndex {
    _refresh.value;
    return _completedExercises + (_session?.position ?? 0);
  }

  /// Номер текущего задания для отладочной подписи у прогресс-бара.
  int get exerciseNumber {
    _refresh.value;
    return exerciseIndex + 1;
  }

  /// Общее число заданий в текущей сессии для отладочной подписи.
  int get totalExercises {
    _refresh.value;
    return continuePlanning || !_pronunciationAvailable
        ? _sessionTarget ?? rules.tasksPerSession
        : _session?.total ?? 0;
  }

  /// Урок по теме: набор атомов задан ею, планировщик не нужен.
  LessonPlan _topicPlan(CurriculumContext ctx) {
    final topic = _curriculum.topics.firstWhere((m) => m.id == _topicId);
    return TopicBoard(
      _curriculum,
    ).planFor(topic, ctx, sessionId: _sessionId, rules: rules);
  }

  Future<CurriculumContext> _context() async {
    final progress = await _progress.progress();
    return CurriculumContext(
      progress: progress,
      formsByLetter: _formsByLetter(),
    );
  }

  /// Какая буква из каких форм состоит — нужно, чтобы считать «буква
  /// в known» как «все её формы в known».
  Map<String, List<String>> _formsByLetter() => _curriculum.formsByLetter;

  /// Блок «новое»: атом показан, но ещё не спрошен.
  Future<void> nextIntro() async {
    if (stage.value != LessonStage.intro) return;
    final atom = introAtom;
    if (atom != null && _plan!.newAtoms.any((fresh) => fresh.id == atom.id)) {
      await _progress.record(
        AtomIntroduced(atomId: atom.id, sessionId: _sessionId, at: _clock.now),
      );
    }
    introIndex.value++;
    final pronounceNow =
        _pronunciationAvailable &&
        atom != null &&
        atom.letterId != null &&
        atom.form == LetterForm.isolated &&
        _plan!.newAtoms.any((a) => a.id == atom.id);
    if (pronounceNow) {
      if (_session == null) await _buildSession();
      _session!.prioritizePronunciation(atom.id);
      _returnToIntro = true;
      _showExercise();
      return;
    }
    if (introAtom != null) return;

    // _buildSession сам ставит finished, если спрашивать нечего:
    // затирать это переходом в exercise нельзя.
    if (_session == null) await _buildSession();
    if (stage.value != LessonStage.finished) {
      _showExercise();
    }
  }

  void _showExercise() {
    _shownAt = DateTime.now();
    _resetFormSequenceHelp();
    _refresh.value++;
    _syncCard();
    _syncTracing();
    _syncPronunciation();
    stage.value = LessonStage.exercise;
  }

  void _resetFormSequenceHelp() {
    formSequenceAttempt.value = 0;
    _formSequenceSlotResults = null;
    _formSequenceInitialPlaced = const [];
    _revealFormSequenceAnswer = false;
  }

  /// После первого произношения продолжаем знакомство с остальными буквами.
  Future<void> _afterExercise() async {
    selected.value = null;
    wasWrong.value = false;
    wasCorrect.value = false;
    _answeredExercise = null;
    if (_returnToIntro) {
      _returnToIntro = false;
      if (introAtom != null) {
        _refresh.value++;
        _syncPronunciation();
        stage.value = LessonStage.intro;
        return;
      }
    }
    if (_session!.isFinished) {
      await _finishBlock();
    } else {
      _showExercise();
    }
  }

  Future<void> _finishBlock() async {
    _completedExercises += _session?.position ?? 0;
    if (!continuePlanning) {
      if (await _replaceUnavailablePronunciation(endsSession: false)) return;
      await _finish();
      return;
    }
    _session = null;
    if (_currentBlockEndsSession) {
      if (await _replaceUnavailablePronunciation(endsSession: true)) return;
      await _finish();
      return;
    }
    if (_completedExercises >= rules.tasksPerSession) {
      await _finish();
      return;
    }

    final remaining = rules.tasksPerSession - _completedExercises;
    final ctx = await _context();
    final planner = LessonPlanner(curriculum: _curriculum, rules: rules);
    var next = planner.plan(
      ctx: ctx,
      sessionId: _sessionId,
      sessionsWithoutNew: await _progress.sessionsWithoutNew(),
      previousCounts: _askedCounts,
      pacing: await _progress.pacing(),
    );

    // Новый блок вводим только целиком. Если обязательные задания
    // не помещаются, остаток сессии отдаём знакомому материалу.
    if (next.minimumTaskCount(_curriculum, rules) > remaining) {
      next = planner.practicePlan(
        ctx: ctx,
        sessionId: _sessionId,
        taskLimit: remaining,
        previousCounts: _askedCounts,
      );
    }

    if (next.minimumTaskCount(_curriculum, rules) == 0 &&
        next.newAtoms.isEmpty &&
        next.reviewAtoms.isEmpty) {
      await _finish();
      return;
    }
    await _activatePlan(next, taskLimit: remaining);
  }

  /// Технически недоступный голос не оставляет дыру в занятии: удалённые
  /// задания заменяются доступной практикой, но новый материал не вводится.
  Future<bool> _replaceUnavailablePronunciation({
    required bool endsSession,
  }) async {
    final target = _sessionTarget ?? _completedExercises;
    if (_pronunciationAvailable || _completedExercises >= target) return false;

    final remaining = target - _completedExercises;
    final ctx = await _context();
    final topicIds = _curriculum.topics
        .firstWhereOrNull((topic) => topic.id == _topicId)
        ?.counterOf
        .toSet();
    final replacement = LessonPlanner(curriculum: _curriculum, rules: rules)
        .practicePlan(
          ctx: ctx,
          sessionId: _sessionId,
          taskLimit: remaining,
          previousCounts: _askedCounts,
          atomIds: topicIds,
        );
    if (replacement.minimumTaskCount(_curriculum, rules) == 0) return false;

    await _activatePlan(
      replacement,
      taskLimit: remaining,
      endsSession: endsSession,
    );
    return true;
  }

  Future<void> _buildSession({int? taskLimit}) async {
    final ctx = await _context();
    final limit =
        taskLimit ??
        (continuePlanning
            ? rules.tasksPerSession - _completedExercises
            : rules.tasksPerSession);
    final exercises = ExerciseGenerator(curriculum: _curriculum, rules: rules)
        .build(
          plan: _plan!,
          ctx: ctx,
          sessionId: _sessionId,
          taskLimit: limit,
          previousCounts: _askedCounts,
          previousFormSequences: _formSequenceLetters,
          unavailableModes: {
            if (!_pronunciationAvailable) ExerciseMode.sayName,
          },
        );
    _sessionTarget ??= continuePlanning
        ? rules.tasksPerSession
        : exercises.length;

    _session = LessonSession(
      exercises: exercises,
      sessionId: _sessionId,
      rules: rules,
      taskLimit: limit,
      now: () => _clock.now,
    );
    _syncShortSessionTarget(allowShorter: true);
    await _loadShapes(exercises);
    if (exercises.isEmpty) {
      if (continuePlanning) {
        await _finishBlock();
      } else {
        stage.value = LessonStage.finished;
      }
    }
    _refresh.value++;
    _syncCard();
    _syncTracing();
    _syncPronunciation();
  }

  /// У пары букв фактическая длина известна после генерации: если старого
  /// материала мало, прогресс-бар не должен обещать 20 заданий.
  void _syncShortSessionTarget({bool allowShorter = false}) {
    final session = _session;
    if (!_currentBlockEndsSession || session == null) return;
    final actual = _completedExercises + session.total;
    if (allowShorter || _sessionTarget == null || actual > _sessionTarget!) {
      _sessionTarget = actual;
    }
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
    nameRevealed.value = false;
    final exercise = _session?.current;
    _pendingCards
      ..clear()
      ..addAll(
        {
          if (exercise != null) exercise.atom,
          if (exercise?.prompt case final prompt?) prompt,
          ...?exercise?.options,
        }.where(
          (atom) =>
              !_belongsToIntro(atom) &&
              _ownAtoms.contains(atom.id) &&
              !_shownCards.contains(atom.id),
        ),
      );
    _nextCard();
  }

  static const _formsOverviewOrder = [
    LetterForm.isolated,
    LetterForm.initial,
    LetterForm.medial,
    LetterForm.finalForm,
  ];

  void _nextCard() {
    final next = _pendingCards.isEmpty ? null : _pendingCards.removeAt(0);
    card.value = next;
    formsOverview.assignAll(_formsOverviewBefore(next));
  }

  List<Atom> _formsOverviewBefore(Atom? atom) {
    final letterId = atom?.letterId;
    if (letterId == null ||
        atom?.form == null ||
        atom?.form == LetterForm.isolated ||
        _shownFormsOverviews.contains(letterId)) {
      return const [];
    }

    final forms = [
      for (final id in _curriculum.formsByLetter[letterId] ?? const <String>[])
        if (_atomById(id) case final form?) form,
    ];
    return [
      for (final position in _formsOverviewOrder)
        ...forms.where((form) => form.form == position),
    ];
  }

  /// Карточка прочитана: атом записывается как показанный, и урок
  /// возвращается к заданию.
  Future<void> dismissCard() async {
    final atom = card.value;
    if (atom == null) return;

    if (formsOverview.isNotEmpty) {
      final letterId = atom.letterId;
      if (letterId != null) _shownFormsOverviews.add(letterId);
      formsOverview.clear();
      _shownAt = DateTime.now();
      return;
    }

    if (_plan!.newAtoms.any((fresh) => fresh.id == atom.id)) {
      await _progress.record(
        AtomIntroduced(atomId: atom.id, sessionId: _sessionId, at: _clock.now),
      );
    }
    _shownCards.add(atom.id);
    _sessionIntroduced[atom.id] = atom;
    _nextCard();
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
    tracingGuideVisible.value = false;
    tracingShape.value = name == null ? null : _shapes[name];
    // Строка под сеткой — только обратная связь: что рисовать дальше
    // и что не сошлось. Само задание написано в шапке карточки, и дублировать
    // его здесь незачем.
    tracingHint.value = tracingShape.value == null ? '' : _tracingStartHint;
  }

  /// Задание, где вместо вариантов холст.
  bool get isTracingTask {
    _refresh.value;
    final exercise = current;
    return exercise != null &&
        exercise.mode.isTracing &&
        tracingShape.value != null;
  }

  /// Холст показывает контур: в режиме обводки всегда, а в режиме по памяти —
  /// после автоматической или ручной подсказки и при разборе ошибки.
  TracingMode get canvasMode {
    _refresh.value;
    return current?.mode == ExerciseMode.trace ||
            tracingGuideVisible.value ||
            wasWrong.value
        ? TracingMode.tracing
        : TracingMode.freehand;
  }

  /// Стереть нарисованное и начать букву заново. Собранные части холст
  /// откатывает сам, вслед за исчезнувшими штрихами. Открытую подсказку
  /// не прячем: человек продолжает обводить по контуру.
  void clearTracing() {
    drawing.clear();
    if (wasWrong.value || tracingGuideVisible.value) return;
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

  /// Последняя часть означает, что холст уже полностью проверил букву —
  /// и по контуру, и по памяти. Отдельное подтверждение кнопкой не нужно.
  Future<void> onTracingMerged() async {
    if (wasWrong.value) return;
    tracingDone.value = true;
    tracingHint.value = 'Буква собрана';
    await submit(directOutcome: true);
  }

  /// Холст сам показал, как пишется, после серии промахов, см.
  /// [DrawingCanvas.missesBeforeReveal]. Это не ошибка и не разбор: контур
  /// остаётся, человек обводит по нему, и собранная буква засчитывается
  /// верным ответом. Строгость проверки не меняется — подсказка честнее
  /// сниженной планки. См. SPEC.md §5.
  void onTracingRevealed() {
    if (wasWrong.value) return;
    tracingDone.value = false;
    tracingHint.value = 'Обведите по подсказке';
    tracingGuideVisible.value = true;
  }

  /// «Не помню» в режиме по памяти открывает контур без ответа и ошибки.
  /// Ответ появится только после того, как человек обведёт подсказку.
  void giveUpTracing() {
    if (current?.mode != ExerciseMode.traceFromMemory ||
        wasWrong.value ||
        wasCorrect.value ||
        tracingGuideVisible.value) {
      return;
    }
    drawing.clear();
    tracingDone.value = false;
    tracingHint.value = 'Обведите по подсказке';
    tracingGuideVisible.value = true;
  }

  /// У заданий без выбора нечего выделять — кнопка активна сразу.
  /// Исключение — письмо: там ответ готов, только когда буква собрана
  /// целиком, независимо от того, был ли перед глазами контур.
  bool get canSubmit {
    _refresh.value;
    final exercise = current;
    if (exercise == null) return false;
    if (wasCorrect.value) return true;
    if (exercise.isChoice) return selected.value != null;
    if (exercise.mode.isTracing && tracingShape.value != null) {
      return tracingDone.value || wasWrong.value;
    }
    // Голос судит сервер, кнопкой подтверждается только разбор ошибки.
    if (exercise.mode == ExerciseMode.sayName) return wasWrong.value;
    return true;
  }

  void select(int index) {
    if (wasWrong.value || wasCorrect.value) return;
    selected.value = index;
  }

  /// Четыре слота проверяются только вместе, после заполнения последнего.
  Future<void> submitFormSequence(List<Atom> placed) async {
    final exercise = _session?.current;
    if (exercise == null ||
        exercise.mode != ExerciseMode.positionToForm ||
        wasWrong.value ||
        wasCorrect.value) {
      return;
    }
    const expected = LetterForm.values;
    final atomResults = {
      for (final option in exercise.options)
        option.id: switch (placed.indexWhere(
          (placed) => placed.id == option.id,
        )) {
          final index when index >= 0 && index < expected.length =>
            option.form == expected[index],
          _ => false,
        },
    };
    final correct =
        atomResults.length == expected.length &&
        atomResults.values.every((value) => value);
    final slotResults = [
      for (final (index, position) in expected.indexed)
        index < placed.length && placed[index].form == position,
    ];
    _formSequenceSlotResults = correct ? null : List.unmodifiable(slotResults);
    _formSequenceInitialPlaced = correct
        ? const []
        : List.unmodifiable([
            for (final (index, atom) in placed.indexed)
              slotResults[index] ? atom : null,
          ]);
    _revealFormSequenceAnswer = !correct && formSequenceAttempt.value == 2;
    selected.value = correct
        ? exercise.answerIndex
        : (exercise.answerIndex + 1) % exercise.options.length;
    await submit(atomResults: atomResults);
  }

  /// Только для отладки: засчитать текущее задание верным, каким бы оно
  /// ни было. В отличие от пропуска ответ пишется в лог как чистый.
  /// Обычная кнопка оставляет окно подтверждения; [advance] нужен только
  /// программным прогонам курса без интерфейса.
  Future<void> answerCorrectly({bool advance = false}) async {
    final exercise = _session?.current;
    if (exercise == null) return;
    if (exercise.isChoice) selected.value = exercise.answerIndex;
    await submit(directOutcome: true);
    if (advance && wasCorrect.value) await submit();
  }

  /// Ответ засчитывается по нажатию «Далее», а не по тапу по карточке:
  /// иначе случайное касание стоит атому отката.
  /// Пропустить задание, не отвечая. Ответ в лог не пишется, поэтому
  /// прогресс букв не искажается. В отладке — чтобы быстро дойти до нужного
  /// экрана; в бою — когда сервер проверки голоса недоступен и задание
  /// «назови букву» выполнить нечем.
  Future<void> skipExercise({bool disablePronunciation = false}) async {
    if (stage.value != LessonStage.exercise) return;
    final session = _session;
    if (session == null || session.current == null) return;

    final exercise = session.current!;
    final mode = exercise.mode;
    session.skip();
    if (mode == ExerciseMode.sayName) {
      if (disablePronunciation) _pronunciationRequired = false;
      final disabled =
          await _pronunciationPreference?.recordSkip(
            sessionId: _pronunciationSessionId ?? _sessionId,
            failure: pronunciation.failure.value,
            explicitOptOut: disablePronunciation,
          ) ??
          false;
      if (disabled) _pronunciationRequired = false;
      _pronunciationAvailable = false;
      session.discardPendingMode(ExerciseMode.sayName);
    }
    if (mode == ExerciseMode.positionToForm) {
      final letterId = exercise.atom.letterId;
      if (letterId != null) _formSequenceLetters.add(letterId);
    }
    _firstAttemptResults.add(false);
    _countAsked(exercise.resultAtoms);
    await _afterExercise();
  }

  /// Явный отказ действует и в следующих занятиях, пока человек сам не
  /// включит голос обратно в настройках.
  Future<void> optOutOfPronunciation() =>
      skipExercise(disablePronunciation: true);

  void _countAsked(Iterable<Atom> atoms) {
    for (final atom in atoms) {
      _askedCounts.update(atom.id, (count) => count + 1, ifAbsent: () => 1);
    }
  }

  /// ВРЕМЕННОЕ. У заданий-заглушек нет своей проверки, поэтому исход
  /// задаёт кнопка: одна засчитывает верно, другая — мимо. Нужно, чтобы
  /// гонять ветку с ошибками, пока обводка и сборка не написаны.
  /// TODO(stub): убрать вместе с заглушками, см. SPEC.md §4.
  Future<void> submitStub({required bool correct}) =>
      submit(directOutcome: correct);

  /// [directOutcome] — исход задания без вариантов: обводку судит холст,
  /// а у оставшихся заглушек его задаёт кнопка.
  Future<void> submit({
    bool? directOutcome,
    Map<String, bool>? atomResults,
  }) async {
    if (stage.value != LessonStage.exercise) return;
    if (wasCorrect.value) {
      await _afterExercise();
      return;
    }

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
      if (exercise.mode == ExerciseMode.positionToForm) {
        formSequenceAttempt.value++;
      }
      _refresh.value++;
      // Холст после разбора чистый: задание осталось тем же, и человек
      // пишет букву заново, а не поверх своей ошибки. С голосом так же:
      // подсказка убрана, попытки отсчитываются заново.
      if (exercise.mode.isTracing) _syncTracing();
      if (exercise.mode == ExerciseMode.sayName) _syncPronunciation();
      return;
    }

    final elapsed = DateTime.now().difference(_shownAt);
    _answeredExercise = exercise;
    final logLength = session.log.length;
    final outcome = session.answer(
      exercise,
      choice,
      fastEnough: elapsed <= _speedLimit(exercise.mode),
      atomResults: atomResults,
    );
    _syncShortSessionTarget();

    // Пишем сразу, а не в конце сессии: лог должен пережить убитое
    // приложение, иначе ответы теряются молча.
    final addedLog = session.log.skip(logLength).toList();
    await _progress.recordAll(addedLog);
    final firstAttempt = addedLog
        .whereType<ProgressEvent>()
        .where((event) => event.attempt == 1)
        .toList();
    if (firstAttempt.isNotEmpty) {
      _firstAttemptResults.add(firstAttempt.every((event) => event.correct));
    }
    if (exercise.mode == ExerciseMode.positionToForm) {
      final letterId = exercise.atom.letterId;
      if (letterId != null) _formSequenceLetters.add(letterId);
    }

    if (outcome == AnswerOutcome.wrong) {
      unawaited(_audio.stop());
      _refresh.value++;
      wasWrong.value = true;
      return;
    }

    _countAsked(exercise.resultAtoms);

    // После проверки звук вопроса больше не должен звучать поверх обратной
    // связи — следующий запуск возможен только по ручной кнопке.
    unawaited(_audio.stop());
    wasCorrect.value = true;
    _refresh.value++;
  }

  /// TODO(speed): пороги подлежат калибровке, и у аудио с обводкой они
  /// другие. См. SPEC.md §4. Голос: нажать, сказать, дождаться сервера —
  /// на это уходят секунды, порог отсекает только брошенное задание.
  Duration _speedLimit(ExerciseMode mode) => switch (mode) {
    _ when mode.isTracing => const Duration(seconds: 40),
    ExerciseMode.sayName => const Duration(seconds: 20),
    _ => const Duration(seconds: 5),
  };

  Future<void> _finish() async {
    if (!_sessionSummaryRecorded) {
      await _progress.finishSession(
        sessionId: _sessionId,
        purpose: _sessionPurpose,
        exerciseCount: _firstAttemptResults.length,
        firstTryCorrect: _firstAttemptResults.where((result) => result).length,
        checkpointLetters: _sessionCheckpointLetters,
      );
      _sessionSummaryRecorded = true;
    }
    // «Пройден» — это факт о занятии, а не о знании: человек дошёл до конца
    // сессии. Освоенность букв добирается повторениями и на отметку
    // не влияет — иначе закрытый урок выглядит недоделанным.
    final topicId = _topicId;
    if (topicId != null && _previewPlan == null && !continuePlanning) {
      await _progress.completeTopic(topicId, sessionId: _sessionId);
    }
    stage.value = LessonStage.finished;
  }

  /// Итог урока: какие атомы поднялись до известных.
  Future<List<Atom>> learned() async {
    final progress = await _progress.progress();
    return sessionIntroduced
        .where(
          (a) =>
              (progress[a.id]?.state ?? AtomState.fresh).index >=
              AtomState.learning.index,
        )
        .toList();
  }

  String get planReason => _planReasons.join(' → ');

  @override
  void onClose() {
    drawing.dispose();
    pronunciation.dispose();
    unawaited(_audio.dispose());
    super.onClose();
  }
}
