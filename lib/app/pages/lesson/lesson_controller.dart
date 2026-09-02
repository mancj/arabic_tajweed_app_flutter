import 'dart:async';

import 'package:get/get.dart';

import '../../../data/curriculum_loader.dart';
import '../../../data/progress_database.dart';
import '../../../data/progress_repository.dart';
import '../../../domain/atom.dart';
import '../../../domain/atom_state.dart';
import '../../../domain/curriculum.dart';
import '../../../domain/exercise.dart';
import '../../../domain/exercise_generator.dart';
import '../../../domain/learning_rules.dart';
import '../../../domain/lesson_session.dart';
import '../../../domain/topic_board.dart';
import '../../../domain/planner.dart';
import '../../../domain/progress_event.dart';

/// Что показывает экран прямо сейчас.
enum LessonStage { loading, intro, exercise, finished }

class LessonController extends GetxController {
  LessonController({
    LearningRules? rules,
    ProgressDatabase? database,
    Curriculum? curriculum,
    String? topicId,
  }) : rules = rules ?? const LearningRules(),
       _database = database,
       _injectedCurriculum = curriculum,
       _topicId = topicId;

  final LearningRules rules;

  /// В тестах база подставляется в памяти; в приложении берётся из Get.
  final ProgressDatabase? _database;

  /// Готовый граф вместо чтения ассета — нужен тестам.
  final Curriculum? _injectedCurriculum;

  /// Если задан, урок собирается по конкретной теме, а не спрашивается
  /// у планировщика: нажали на строку — работаем с этой темой.
  final String? _topicId;

  final stage = LessonStage.loading.obs;
  final loadError = RxnString();
  final _refresh = 0.obs;

  /// Атомы блока «новое»: показываем без проверки, потом спрашиваем.
  final introAtoms = <Atom>[].obs;
  final introIndex = 0.obs;

  /// Выбранный вариант — до нажатия «Далее» ответ ещё можно передумать.
  final selected = Rxn<int>();
  final wasWrong = false.obs;

  late final Curriculum _curriculum;
  late final ProgressRepository _progress;
  LessonSession? _session;
  LessonPlan? _plan;
  DateTime _shownAt = DateTime.now();

  /// TODO(session-id): сейчас каждая сессия считается первой. Когда появится
  /// счётчик пройденных уроков, брать номер оттуда — от него зависят
  /// откладывание атомов и гарантия темпа.
  int get _sessionId => 1;

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
    _plan = _topicId == null
        ? LessonPlanner(curriculum: _curriculum, rules: rules).plan(
            ctx: ctx,
            sessionId: _sessionId,
            // TODO(session-id): считать по истории, а не всегда 0.
            sessionsWithoutNew: 0,
          )
        : _topicPlan(ctx);

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
    if (!isTopicLesson) return plan.newAtoms;

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
          if (atom.kind == AtomKind.concept || atom.note.isNotEmpty) atom,
    ];
  }

  Atom? _atomById(String id) =>
      _curriculum.nodes.firstWhereOrNull((n) => n.atom.id == id)?.atom;

  /// Урок по теме: набор атомов задан ею, планировщик не нужен.
  LessonPlan _topicPlan(CurriculumContext ctx) {
    final topic = _curriculum.topics.firstWhere((m) => m.id == _topicId);
    return TopicBoard(_curriculum).planFor(topic, ctx);
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
    if (exercises.isEmpty) stage.value = LessonStage.finished;
    _refresh.value++;
  }

  /// У заданий без выбора нечего выделять — кнопка активна сразу.
  bool get canSubmit {
    _refresh.value;
    final exercise = _session?.current;
    if (exercise == null) return false;
    return !exercise.isChoice || selected.value != null;
  }

  void select(int index) {
    if (wasWrong.value) return;
    selected.value = index;
  }

  /// Ответ засчитывается по нажатию «Далее», а не по тапу по карточке:
  /// иначе случайное касание стоит атому отката.
  /// ВРЕМЕННОЕ. У заданий-заглушек нет своей проверки, поэтому исход
  /// задаёт кнопка: одна засчитывает верно, другая — мимо. Нужно, чтобы
  /// гонять ветку с ошибками, пока обводка и сборка не написаны.
  /// TODO(stub): убрать вместе с заглушками, см. SPEC.md §4.
  Future<void> submitStub({required bool correct}) =>
      submit(stubOutcome: correct);

  Future<void> submit({bool? stubOutcome}) async {
    final session = _session;
    final exercise = session?.current;
    if (session == null || exercise == null) return;

    // У заглушки нет своей проверки: исход приходит от кнопки, по умолчанию
    // верный. Отрицательный индекс сессия трактует как ошибку.
    final choice = exercise.isChoice
        ? selected.value
        : ((stubOutcome ?? true) ? 0 : -1);
    if (choice == null) return;

    if (wasWrong.value) {
      // Верный ответ уже показан — это подтверждение, а не новая попытка.
      wasWrong.value = false;
      selected.value = null;
      _refresh.value++;
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
    if (session.isFinished) await _finish();
  }

  /// TODO(speed): пороги подлежат калибровке, и у аудио с обводкой они
  /// другие. См. SPEC.md §4.
  Duration _speedLimit(ExerciseMode mode) => const Duration(seconds: 3);

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
}
