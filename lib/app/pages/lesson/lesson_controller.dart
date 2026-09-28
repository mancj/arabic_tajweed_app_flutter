import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:get/get.dart';

import '../../../data/curriculum_loader.dart';
import '../../../data/explanation_loader.dart';
import '../../../data/letter_audio.dart';
import '../../../data/lesson_audio.dart';
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
import '../../../domain/explanation_document.dart';
import '../../../domain/exercise_generator.dart';
import '../../../domain/learning_rules.dart';
import '../../../domain/letter_learning.dart';
import '../../../domain/lesson_explanation_queue.dart';
import '../../../domain/lesson_session.dart';
import '../../../domain/lesson_pacing.dart';
import '../../../domain/lesson_plan_continuation.dart';
import '../../../domain/topic_board.dart';
import '../../../domain/planner.dart';
import '../../../domain/pronunciation_attempts.dart';
import '../../../domain/progress_event.dart';
import '../../shared_state/app_clock.dart';
import '../../widgets/drawing/drawing_canvas.dart';
import 'lesson_audio_source.dart';
import 'option_audio_sequence.dart';
import 'form_sequence_task_state.dart';
import 'tracing_task_state.dart';

/// Что показывает экран прямо сейчас.
enum LessonStage { loading, intro, exercise, finished }

class LessonController extends GetxController {
  LessonController({
    LearningRules? rules,
    ProgressDatabase? database,
    Curriculum? curriculum,
    AssetBundle? explanationBundle,
    String? topicId,
    LessonPlan? plan,
    this.continuePlanning = false,
    Future<TracingShape> Function(String asset)? shapeLoader,
    LessonAudio? audio,
    VoiceRecorder? recorder,
    PronunciationRestClient? pronunciation,
    PronunciationPreference? pronunciationPreference,
    AppClock? clock,
  }) : _baseRules = rules ?? const LearningRules(),
       _database = database,
       _injectedCurriculum = curriculum,
       _explanationBundle = explanationBundle,
       _topicId = topicId,
       _previewPlan = plan,
       _injectedPronunciationPreference = pronunciationPreference,
       _clock =
           clock ??
           (Get.isRegistered<AppClock>() ? Get.find<AppClock>() : AppClock()),
       _tracing = TracingTaskState(shapeLoader: shapeLoader),
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
  final AssetBundle? _explanationBundle;
  final _explanationCards = <String, ExplanationContent>{};

  ExplanationContent? explanationFor(Atom atom) =>
      _explanationCards[atom.explanationAsset];

  ExplanationContent? formsExplanationFor(String? letterId) {
    if (letterId == null) return null;
    final isolated = _curriculum.nodes
        .firstWhereOrNull((node) => node.atom.id == '$letterId.isolated')
        ?.atom;
    return _explanationCards[isolated?.formsOverviewAsset];
  }

  /// Готовый граф вместо чтения ассета — нужен тестам.
  final Curriculum? _injectedCurriculum;
  final PronunciationPreference? _injectedPronunciationPreference;

  /// Если задан, урок собирается по конкретной теме, а не спрашивается
  /// у планировщика: нажали на строку — работаем с этой темой.
  String? _topicId;
  final LessonPlan? _previewPlan;

  final TracingTaskState _tracing;

  final stage = LessonStage.loading.obs;
  final learnedLetters = <Atom>[].obs;
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
  final _formSequence = FormSequenceTaskState();

  RxInt get formSequenceAttempt => _formSequence.attempt;
  List<bool>? get formSequenceSlotResults => _formSequence.slotResults;
  List<Atom?> get formSequenceInitialPlaced => _formSequence.initialPlaced;
  bool get revealFormSequenceAnswer => _formSequence.revealAnswer;
  int get formSequenceCorrectCount => _formSequence.correctCount;
  final sequencePlayingSlot = RxnInt();

  /// Правильный ответ показывается до перехода, чтобы человек успел увидеть
  /// результат и понять, что именно засчиталось.
  final wasCorrect = false.obs;

  /// Имя буквы в задании на слух показано по просьбе: звук выключен или
  /// не слышно. Само по себе оно в задании не появляется.
  final nameRevealed = false.obs;

  void revealName() => nameRevealed.value = true;

  DrawingController get drawing => _tracing.drawing;
  Rxn<TracingShape> get tracingShape => _tracing.shape;
  RxString get tracingHint => _tracing.hint;
  RxBool get tracingDone => _tracing.done;
  RxBool get tracingGuideVisible => _tracing.guideVisible;

  /// Карточка перед текущим заданием. Формы букв объясняются там, где
  /// впервые встречаются, а не списком в начале урока: соединение — это
  /// не десять правил подряд, а одно правило на каждую новую связку.
  final card = Rxn<Atom>();

  /// Перед первой подробной карточкой буквы показываем все её формы вместе.
  /// Это обзор, а не атом: он не пишет событие и не влияет на прогресс.
  final formsOverview = <Atom>[].obs;

  /// Голос буквы. Один плеер на урок: новое нажатие обрывает предыдущий
  /// звук, а не накладывается на него.
  /// В тестах подставляется с плеером под известным именем: у настоящего
  /// имя случайное, и его каналы нечем подменить.
  final LessonAudio _audio;
  final LessonAudioSource _audioSource = const LessonAudioSource();
  late final OptionAudioSequence _optionAudio = OptionAudioSequence(
    audio: _audio,
  );

  /// Есть ли у атома запись. У понятий, слогов и хамзы её пока нет.
  bool hasVoice(Atom atom) => _audioSource.forAtom(atom) != null;
  bool hasExerciseVoice(Exercise exercise) =>
      _audioSource.forExercise(exercise) != null;

  /// Нажатие на кнопку звучания: играет, ставит на паузу или продолжает —
  /// решает сам плеер, экрану знать об этом нечего.
  void playVoice(Atom atom) =>
      unawaited(_audio.toggleAsset(_audioSource.forAtom(atom)));
  void playExerciseVoice(Exercise exercise) =>
      unawaited(_audio.toggleAsset(_audioSource.forExercise(exercise)));

  /// Звучание при появлении буквы: всегда с начала. Нажатие звучащую букву
  /// останавливает, а показ следующей формы той же буквы — не должен.
  void startVoice(Atom atom) =>
      unawaited(_audio.playAsset(_audioSource.forAtom(atom)));
  void startExerciseVoice(Exercise exercise) =>
      unawaited(_audio.playAsset(_audioSource.forExercise(exercise)));

  /// Что сейчас звучит: форма записи и позиция. Карточка отдаёт это волне.
  ValueListenable<AudioTrack> get voiceTrack => _audio.track;

  void _onSequenceTrackChanged() {
    if (!_audio.track.value.isPlaying) sequencePlayingSlot.value = null;
  }

  Future<void> playSequenceSlot(Exercise exercise, int index) async {
    if (exercise.mode != ExerciseMode.harakaSequence ||
        index < 0 ||
        index >= exercise.sequenceOrder.length ||
        wasWrong.value ||
        wasCorrect.value) {
      return;
    }
    if (sequencePlayingSlot.value == index && _audio.track.value.isPlaying) {
      await _audio.stop();
      return;
    }
    sequencePlayingSlot.value = index;
    await _audio.playAsset(exercise.sequenceOrder[index].audioAsset);
    if (!_audio.track.value.isPlaying) sequencePlayingSlot.value = null;
  }

  void startSequenceSlot(Exercise exercise, int index) {
    if (exercise.mode != ExerciseMode.harakaSequence ||
        index < 0 ||
        index >= exercise.sequenceOrder.length ||
        wasWrong.value ||
        wasCorrect.value) {
      return;
    }
    sequencePlayingSlot.value = index;
    unawaited(_audio.playAsset(exercise.sequenceOrder[index].audioAsset));
  }

  ValueListenable<OptionPlaybackState> get optionPlayback => _optionAudio.state;

  void startOptionSequence(Exercise exercise) {
    if (exercise.mode != ExerciseMode.letterToSound) return;
    unawaited(
      _optionAudio.playAll(
        exercise.options.map(_audioSource.forAtom).toList(growable: false),
      ),
    );
  }

  void playOptionVoice(Exercise exercise, int index) {
    unawaited(
      _optionAudio.toggle(
        index: index,
        asset: _audioSource.forAtom(exercise.options[index]),
      ),
    );
  }

  /// Пороги совпадения у холста и у сообщений должны быть одни и те же.
  static const tracingMatcher = TracingTaskState.matcher;

  /// Задание «назови букву»: запись и проверка на сервере. Цепочка общая
  /// с экраном тренировки, здесь решается только, что делать с ответом.
  final PronunciationChecker pronunciation;

  final _pronunciationAttempts = PronunciationAttempts();

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
    switch (_pronunciationAttempts.evaluate(
      matched: result.matched,
      hasWarning: result.recording.warning != null,
      limit: rules.sayNameAttempts,
    )) {
      case PronunciationDecision.accepted:
        await submit(directOutcome: true);
      case PronunciationDecision.wrong:
        await submit(directOutcome: false);
      case PronunciationDecision.retry || PronunciationDecision.ignored:
        break;
    }
  }

  /// Новое задание — прошлые записи и подсказки к делу не относятся.
  void _syncPronunciation() {
    pronunciation.reset();
    _pronunciationAttempts.reset();
  }

  late final Curriculum _curriculum;
  late final LessonExplanationQueue _explanations;
  late final ProgressRepository _progress;
  LessonSession? _session;
  Exercise? _answeredExercise;
  bool _returnToIntro = false;
  LessonPlan? _plan;
  int _completedExercises = 0;
  final _askedCounts = <String, int>{};
  final _formSequenceLetters = <String>{};
  final _harakaSequenceLetters = <String>{};
  final _sessionIntroduced = <String, Atom>{};
  final _planReasons = <String>[];
  final _firstAttemptResults = <bool>[];
  final _announcedLetterIds = <String>{};
  bool _hasNewMaterial = false;
  LessonPurpose _sessionPurpose = LessonPurpose.standard;
  int? _sessionCheckpointLetters;
  bool _sessionSummaryRecorded = false;
  bool _pronunciationRequired = true;
  bool _pronunciationAvailable = true;
  bool _debugFinishingLesson = false;
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

  int get completedExerciseCount => _firstAttemptResults.length;

  int get firstTryCorrectCount =>
      _firstAttemptResults.where((result) => result).length;

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

  List<Atom> _atomsById(List<String> ids) {
    final byId = {
      for (final node in _curriculum.nodes) node.atom.id: node.atom,
    };
    return ids.map((id) => byId[id]).nonNulls.toList(growable: false);
  }

  List<Atom> get fathaIntroExamples =>
      _atomsById(const ['vowel.ba.fatha', 'vowel.ta.fatha', 'vowel.kaf.fatha']);

  List<Atom> get kasraIntroExamples => _atomsById(const [
    'vowel.mim.kasra',
    'vowel.lam.kasra',
    'vowel.nun.kasra',
  ]);

  List<Atom> get dammaIntroExamples => _atomsById(const [
    'vowel.shin.damma',
    'vowel.ayn.damma',
    'vowel.jim.damma',
  ]);

  /// Итоговая таблица: три знака на одних и тех же буквах для сравнения.
  List<Atom> get harakaSummaryExamples => _atomsById(const [
    'vowel.ba.fatha',
    'vowel.ba.kasra',
    'vowel.ba.damma',
    'vowel.ta.fatha',
    'vowel.ta.kasra',
    'vowel.ta.damma',
    'vowel.kaf.fatha',
    'vowel.kaf.kasra',
    'vowel.kaf.damma',
  ]);

  @override
  void onInit() {
    super.onInit();
    _audio.track.addListener(_onSequenceTrackChanged);
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
    final atoms = _curriculum.nodes.map((node) => node.atom);
    final explanationLoader = ExplanationLoader(bundle: _explanationBundle);
    final assets = {
      ...atoms.map((atom) => atom.explanationAsset).nonNulls,
      ...atoms.map((atom) => atom.formsOverviewAsset).nonNulls,
    };
    _explanationCards.addEntries(
      await Future.wait(
        assets.map(
          (asset) async => MapEntry(asset, await explanationLoader.load(asset)),
        ),
      ),
    );
    _explanations = LessonExplanationQueue(_curriculum);
    _progress = ProgressRepository(
      database: _database ?? Get.find<ProgressDatabase>(),
      rules: rules,
      letterFormIds: _curriculum.letterFormIds,
      baseLetterIds: _curriculum.baseLetterIds,
      now: () => _clock.now,
    );
    _announcedLetterIds.addAll(await _progress.learnedLetterIds());

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
            (continuePlanning &&
                plan.newAtoms.any((atom) => atom.kind != AtomKind.concept)));
    _topicId = plan.topicId ?? _topicId;
    _planReasons.add(plan.reason);
    _hasNewMaterial = _hasNewMaterial || plan.newAtoms.isNotEmpty;

    _explanations.activate(plan, topicId: _topicId);
    final intro = _explanations.introFor(plan, topicId: _topicId);
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
    if (stage.value != LessonStage.finished && introAtom == null) {
      _showExercise();
    }
  }

  void _showExercise() {
    _formSequence.reset();
    sequencePlayingSlot.value = null;
    _refresh.value++;
    _syncCard();
    _syncTracing();
    _syncPronunciation();
    stage.value = LessonStage.exercise;
  }

  /// После первого произношения продолжаем знакомство с остальными буквами.
  Future<void> _afterExercise() async {
    _optionAudio.cancel();
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
    final next = LessonPlanContinuation(curriculum: _curriculum, rules: rules)
        .next(
          context: ctx,
          sessionId: _sessionId,
          sessionsWithoutNew: await _progress.sessionsWithoutNew(),
          remaining: remaining,
          previousCounts: _askedCounts,
          pacing: await _progress.pacing(),
        );
    if (next == null) {
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
    final replacement =
        LessonPlanContinuation(
          curriculum: _curriculum,
          rules: rules,
        ).replaceUnavailablePronunciation(
          context: ctx,
          sessionId: _sessionId,
          remaining: remaining,
          previousCounts: _askedCounts,
          atomIds: topicIds,
        );
    if (replacement == null) return false;

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
          previousHarakaSequences: _harakaSequenceLetters,
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
    await _tracing.preload(exercises);
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

  void _syncCard() {
    nameRevealed.value = false;
    _explanations.prepareFor(_session?.current);
    _publishExplanation();
  }

  void _publishExplanation() {
    card.value = _explanations.card;
    formsOverview.assignAll(_explanations.formsOverview);
  }

  /// Карточка прочитана: атом записывается как показанный, и урок
  /// возвращается к заданию.
  Future<void> dismissCard() async {
    final atom = card.value;
    if (atom == null) return;

    if (formsOverview.isNotEmpty) {
      _explanations.dismissOverview();
      _publishExplanation();
      return;
    }

    if (_plan!.newAtoms.any((fresh) => fresh.id == atom.id)) {
      await _progress.record(
        AtomIntroduced(atomId: atom.id, sessionId: _sessionId, at: _clock.now),
      );
    }
    _sessionIntroduced[atom.id] = atom;
    _explanations.dismissCard();
    _publishExplanation();
  }

  void _syncTracing() {
    _tracing.sync(_session?.current);
  }

  /// Задание, где вместо вариантов холст.
  bool get isTracingTask {
    _refresh.value;
    return _tracing.isAvailableFor(current);
  }

  /// Холст показывает контур: в режиме обводки всегда, а в режиме по памяти —
  /// после автоматической или ручной подсказки и при разборе ошибки.
  TracingMode get canvasMode {
    _refresh.value;
    return _tracing.canvasMode(current, wasWrong: wasWrong.value);
  }

  bool get tracingIsAnchored => _tracing.isAnchored(current);

  /// Стереть нарисованное и начать букву заново. Собранные части холст
  /// откатывает сам, вслед за исчезнувшими штрихами. Открытую подсказку
  /// не прячем: человек продолжает обводить по контуру.
  void clearTracing() {
    _tracing.clear(wasWrong: wasWrong.value);
  }

  /// Части буквы засчитываются по одной — и по контуру, и по памяти:
  /// проверять нечего, ответ готов, когда собрана последняя.
  void onTracingProgress(TracingProgress progress) {
    if (wasWrong.value) return;
    _tracing.onProgress(progress);
  }

  /// Последняя часть означает, что холст уже полностью проверил букву —
  /// и по контуру, и по памяти. Отдельное подтверждение кнопкой не нужно.
  Future<void> onTracingMerged() async {
    if (wasWrong.value) return;
    _tracing.onMerged();
    await submit(directOutcome: true);
  }

  /// Холст сам показал, как пишется, после серии промахов, см.
  /// [DrawingCanvas.missesBeforeReveal]. Это не ошибка и не разбор: контур
  /// остаётся, человек обводит по нему, и собранная буква засчитывается
  /// верным ответом. Строгость проверки не меняется — подсказка честнее
  /// сниженной планки. См. SPEC.md §5.
  void onTracingRevealed() {
    if (wasWrong.value) return;
    _tracing.revealGuide();
  }

  /// «Не помню» в режиме по памяти открывает контур без ответа и ошибки.
  /// Ответ появится только после того, как человек обведёт подсказку.
  void giveUpTracing() {
    if ((current?.mode != ExerciseMode.traceFromMemory &&
            current?.mode != ExerciseMode.drawHarakaForSound) ||
        wasWrong.value ||
        wasCorrect.value ||
        tracingGuideVisible.value) {
      return;
    }
    _tracing.giveUp();
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

  /// Слоты проверяются только вместе, после заполнения последнего.
  Future<void> submitFormSequence(List<Atom> placed) async {
    final exercise = _session?.current;
    if (exercise == null ||
        (exercise.mode != ExerciseMode.positionToForm &&
            exercise.mode != ExerciseMode.harakaSequence) ||
        wasWrong.value ||
        wasCorrect.value) {
      return;
    }
    final evaluation = _formSequence.evaluate(
      options: exercise.options,
      placed: placed,
      expectedAtomIds: exercise.mode == ExerciseMode.harakaSequence
          ? exercise.sequenceOrder.map((atom) => atom.id).toList()
          : null,
    );
    selected.value = evaluation.correct
        ? exercise.answerIndex
        : (exercise.answerIndex + 1) % exercise.options.length;
    await submit(atomResults: evaluation.atomResults);
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

  bool get isDebugFinishingLesson => _debugFinishingLesson;

  /// Только для отладки: проходит остаток занятия через обычные верные
  /// ответы, включая новые блоки, карточки и пересчёт плана.
  Future<void> finishLessonCorrectly() async {
    if (!kDebugMode ||
        _debugFinishingLesson ||
        stage.value != LessonStage.exercise) {
      return;
    }
    _debugFinishingLesson = true;
    try {
      var steps = 0;
      while (stage.value != LessonStage.finished) {
        if (steps++ >= 500) {
          throw StateError('Отладочный проход урока не завершился');
        }
        if (stage.value == LessonStage.intro) {
          await nextIntro();
          continue;
        }
        while (card.value != null) {
          await dismissCard();
        }
        if (stage.value == LessonStage.exercise) {
          await answerCorrectly(advance: true);
        }
      }
    } finally {
      _debugFinishingLesson = false;
    }
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
    await _optionAudio.stop();
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
    } else if (mode == ExerciseMode.harakaSequence) {
      final letterId = exercise.atom.letterId;
      if (letterId != null) _harakaSequenceLetters.add(letterId);
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
      if (exercise.mode == ExerciseMode.positionToForm ||
          exercise.mode == ExerciseMode.harakaSequence) {
        _formSequence.retry();
      }
      _refresh.value++;
      // Холст после разбора чистый: задание осталось тем же, и человек
      // пишет букву заново, а не поверх своей ошибки. С голосом так же:
      // подсказка убрана, попытки отсчитываются заново.
      if (exercise.mode.isTracing) _syncTracing();
      if (exercise.mode == ExerciseMode.sayName) _syncPronunciation();
      if (exercise.mode == ExerciseMode.letterToSound) {
        startOptionSequence(exercise);
      }
      return;
    }

    _answeredExercise = exercise;
    final logLength = session.log.length;
    final outcome = session.answer(exercise, choice, atomResults: atomResults);
    _syncShortSessionTarget();

    // Пишем сразу, а не в конце сессии: лог должен пережить убитое
    // приложение, иначе ответы теряются молча.
    final addedLog = session.log.skip(logLength).toList();
    final beforeProgress = await _progress.progress();
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
    } else if (exercise.mode == ExerciseMode.harakaSequence) {
      final letterId = exercise.atom.letterId;
      if (letterId != null) _harakaSequenceLetters.add(letterId);
    }

    if (outcome == AnswerOutcome.wrong) {
      _optionAudio.cancel();
      unawaited(_audio.stop());
      _refresh.value++;
      wasWrong.value = true;
      return;
    }

    await _queueLearnedLetters(addedLog, beforeProgress);

    _countAsked(exercise.resultAtoms);

    // После проверки звук вопроса больше не должен звучать поверх обратной
    // связи — следующий запуск возможен только по ручной кнопке.
    _optionAudio.cancel();
    unawaited(_audio.stop());
    wasCorrect.value = true;
    _refresh.value++;
  }

  Future<void> _queueLearnedLetters(
    List<LogEntry> addedLog,
    Map<String, AtomProgress> beforeProgress,
  ) async {
    if (_debugFinishingLesson) return;
    final learning = LetterLearning(_curriculum, rules);
    final afterProgress = await _progress.progress();
    final byId = {
      for (final node in _curriculum.nodes) node.atom.id: node.atom,
    };
    final letterIds = {
      for (final event in addedLog.whereType<ProgressEvent>())
        if (event.correct && byId[event.atomId]?.letterId != null)
          byId[event.atomId]!.letterId!,
    };
    for (final letterId in letterIds) {
      if (_announcedLetterIds.contains(letterId) ||
          learning.isLearned(letterId, beforeProgress) ||
          !learning.isLearned(letterId, afterProgress)) {
        continue;
      }
      final atom = learning.displayAtom(letterId);
      if (atom == null) continue;
      await _progress.record(
        LetterLearned(atomId: letterId, sessionId: _sessionId, at: _clock.now),
      );
      _announcedLetterIds.add(letterId);
      learnedLetters.add(atom);
    }
  }

  Future<void> _finish() async {
    if (!_sessionSummaryRecorded) {
      await _progress.finishSession(
        sessionId: _sessionId,
        purpose: _sessionPurpose,
        exerciseCount: completedExerciseCount,
        firstTryCorrect: firstTryCorrectCount,
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
    _audio.track.removeListener(_onSequenceTrackChanged);
    _tracing.dispose();
    pronunciation.dispose();
    _optionAudio.dispose();
    unawaited(_audio.dispose());
    super.onClose();
  }
}
