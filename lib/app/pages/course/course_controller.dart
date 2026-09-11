import 'dart:async';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../../../data/curriculum_loader.dart';
import '../../../data/progress_database.dart';
import '../../../data/progress_repository.dart';
import '../../../domain/atom.dart';
import '../../../domain/atom_state.dart';
import '../../../domain/curriculum.dart';
import '../../../domain/learning_rules.dart';
import '../../../domain/planner.dart';
import '../../../domain/topic_board.dart';
import '../lesson/lesson_binding.dart';

/// Один следующий план для карточки на главном и запуска занятия.
/// Темы показывают освоенность; число занятий заранее неизвестно.
class CourseController extends GetxController {
  CourseController({
    LearningRules? rules,
    ProgressDatabase? database,
    Curriculum? curriculum,
  }) : rules = rules ?? const LearningRules(),
       _database = database,
       _injectedCurriculum = curriculum;

  final LearningRules rules;
  final ProgressDatabase? _database;
  final Curriculum? _injectedCurriculum;
  final loading = true.obs;
  final opening = false.obs;
  final loadError = RxnString();
  final statuses = <TopicStatus>[].obs;
  final nextPlan = Rxn<LessonPlan>();
  final upcomingTopic = Rxn<TopicStatus>();
  final activityDays = <DateTime>[].obs;
  late Curriculum curriculum;
  late ProgressRepository repository;
  late CurriculumContext context;
  bool _ready = false;

  @override
  void onInit() {
    super.onInit();
    unawaited(refreshBoard());
  }

  Future<void> refreshBoard() async {
    loadError.value = null;
    try {
      if (!_ready) {
        curriculum =
            _injectedCurriculum ?? await const CurriculumLoader().load();
        repository = ProgressRepository(
          database: _database ?? Get.find<ProgressDatabase>(),
          rules: rules,
          letterFormIds: curriculum.letterFormIds,
        );
        _ready = true;
      }
      await repository.recompute();
      context = CurriculumContext(
        progress: await repository.progress(),
        formsByLetter: curriculum.formsByLetter,
      );
      final plan = await planFor();
      final completions = await repository.completions();
      statuses.assignAll(
        TopicBoard(curriculum, rules: rules).statuses(
          context,
          completed: completions.map((id, c) => MapEntry(id, c.byTest)),
          currentId: plan.topicId,
        ),
      );
      nextPlan.value = plan;
      activityDays.assignAll(await repository.activityDays());
      upcomingTopic.value = await _upcomingAfter(plan);
    } catch (e) {
      loadError.value = '$e';
      nextPlan.value = null;
    } finally {
      loading.value = false;
    }
  }

  Future<LessonPlan> planFor({Set<String>? topicIds}) async =>
      LessonPlanner(curriculum: curriculum, rules: rules).plan(
        ctx: context,
        sessionId: await repository.nextSessionId(),
        sessionsWithoutNew: await repository.sessionsWithoutNew(),
        topicIds: topicIds,
      );

  TopicStatus? get currentTopic =>
      statuses.firstWhereOrNull((s) => s.topic.id == nextPlan.value?.topicId);
  bool get allDone => statuses.isNotEmpty && statuses.every((s) => s.isDone);
  bool get hasStarted => activityDays.isNotEmpty;

  int get knownLetters => context.knownLetterCount;
  int get totalLetters => curriculum.formsByLetter.length;

  List<Atom> atomsFor(TopicStatus topic) => curriculum.nodes
      .where((n) => topic.topic.counterOf.contains(n.atom.id))
      .map((n) => n.atom)
      .where((a) => a.kind != AtomKind.concept)
      .toList();

  List<Atom> get lessonAtoms {
    final plan = nextPlan.value;
    if (plan == null) return [];
    final fresh = plan.newAtoms
        .where((a) => a.kind != AtomKind.concept)
        .toList();
    return fresh.isNotEmpty
        ? fresh
        : curriculum.nodes
              .where((n) => plan.reviewAtoms.contains(n.atom.id))
              .map((n) => n.atom)
              .where((a) => a.kind != AtomKind.concept)
              .toList();
  }

  Atom? get featuredAtom => lessonAtoms.firstOrNull;

  String get lessonSource {
    final atom = featuredAtom;
    if (atom == null) return '';
    if (atom.kind == AtomKind.syllable) return atom.display.split('').join(' ');
    if (atom.form != null && atom.form != LetterForm.isolated) {
      return curriculum.nodes
              .firstWhereOrNull(
                (n) =>
                    n.atom.letterId == atom.letterId &&
                    n.atom.form == LetterForm.isolated,
              )
              ?.atom
              .display ??
          '';
    }
    return lessonAtoms.skip(1).take(2).map((a) => a.display).join(' ');
  }

  String get lessonFocus {
    if (nextPlan.value?.isFocusedReview ?? false) return 'Закрепление и новое';
    if (nextPlan.value?.newAtoms.isEmpty ?? true) {
      return 'Тренируем знакомый материал';
    }
    if (lessonAtoms.any((a) => a.form == LetterForm.isolated)) {
      return 'Пишем и называем вслух';
    }
    if (lessonAtoms.any((a) => a.form != null)) return 'Все формы этого блока';
    if (featuredAtom?.kind == AtomKind.syllable) {
      return 'Учимся читать соединения';
    }
    return 'Знакомимся с новым правилом';
  }

  String get lessonDetail {
    final plan = nextPlan.value;
    if (plan == null) return '';
    if (plan.isFocusedReview) {
      final count = plan.reviewCounts.values.sum;
      final word = count == 1
          ? 'задание'
          : count < 5
          ? 'задания'
          : 'заданий';
      return '$count $word по пробелам, затем новое и повторение';
    }
    if (plan.newAtoms.isEmpty) return 'Узнаём увереннее, вспоминаем быстрее';
    if (plan.spacedReview.isNotEmpty || plan.reviewAtoms.isNotEmpty) {
      return 'И повторяем знакомый материал';
    }
    if (lessonAtoms.any((a) => a.form == LetterForm.isolated)) {
      return 'С обводкой и по памяти';
    }
    if (lessonAtoms.any((a) => a.form != null)) {
      return 'Покажем и проверим каждую';
    }
    return 'Разбираем правило и тренируемся';
  }

  /// Прогноз после закрепления всего материала карточки. Используем тот же
  /// планировщик, поэтому прогноз сохраняет порядок оглавления и этапов.
  /// Это только витрина — записи прогресса здесь не меняются.
  Future<TopicStatus?> _upcomingAfter(LessonPlan plan) async {
    if (allDone) return null;
    final ids = {...plan.newAtoms.map((a) => a.id), ...plan.reviewAtoms};
    final projected = CurriculumContext(
      formsByLetter: context.formsByLetter,
      progress: {
        ...context.progress,
        for (final node in curriculum.nodes.where(
          (n) => ids.contains(n.atom.id),
        ))
          node.atom.id: (context.progress[node.atom.id] ?? const AtomProgress())
              .copyWith(
                state: node.atom.kind == AtomKind.concept
                    ? AtomState.introduced
                    : AtomState.known,
                successfulModes: {
                  ...?context.progress[node.atom.id]?.successfulModes,
                  ...rules.requiredPracticeModes(node.atom),
                },
                clearDeferred: true,
              ),
      },
    );
    final after = LessonPlanner(curriculum: curriculum, rules: rules).plan(
      ctx: projected,
      sessionId: await repository.nextSessionId(),
      sessionsWithoutNew: rules.sessionsWithoutNewBeforeForcing,
    );
    return statuses.firstWhereOrNull(
          (s) => s.topic.id == after.topicId && s.topic.id != plan.topicId,
        ) ??
        statuses.firstWhereOrNull(
          (s) => !s.isDone && s.topic.id != plan.topicId,
        );
  }

  bool get canStart =>
      !loading.value &&
      !opening.value &&
      nextPlan.value != null &&
      (nextPlan.value!.newAtoms.isNotEmpty ||
          nextPlan.value!.reviewAtoms.isNotEmpty);

  String get lessonTitle {
    final plan = nextPlan.value;
    if (plan == null) return 'Готовим занятие';
    if (plan.newAtoms.isEmpty) return 'Закрепим знакомое';
    if (plan.topicId == 'm.join') return 'Соединяем первые буквы';
    return currentTopic?.topic.title ?? 'Познакомимся с новым';
  }

  String get lessonDescription {
    final plan = nextPlan.value;
    if (plan == null) return '';
    if (plan.newAtoms.isEmpty) {
      return 'Повторим материал, который стоит закрепить.';
    }
    final forms = plan.newAtoms
        .where((a) => a.form != null && a.form != LetterForm.isolated)
        .length;
    if (forms > 0) {
      return 'Разберём все формы этого блока и проверим каждую. Затем повторим знакомое.';
    }
    if (plan.newAtoms.any((a) => a.form == LetterForm.isolated)) {
      return 'Познакомимся с буквами, напишем с обводкой и по памяти, назовём вслух. Затем повторим знакомое.';
    }
    return 'Разберём правило, потренируемся и повторим знакомое.';
  }

  Map<int, List<TopicStatus>> get byStage =>
      groupBy(statuses, (s) => s.topic.stage);
  static String stageTitle(int stage) => switch (stage) {
    1 => 'Буквы и их формы',
    2 => 'Соединение букв',
    3 => 'Огласовки',
    4 => 'Знаки чтения',
    5 => 'Чтение слов',
    _ => 'Правила письма',
  };

  Future<void> continueCourse() async {
    if (!canStart) return;
    await _openPlan(nextPlan.value!, continuePlanning: true);
  }

  Future<void> open(TopicStatus status) async {
    if (!status.canPractice || opening.value) return;
    final plan = TopicBoard(curriculum).planFor(
      status.topic,
      context,
      sessionId: await repository.nextSessionId(),
      rules: rules,
    );
    await _openPlan(plan);
  }

  Future<void> openStage(int stage) async {
    if (opening.value) return;
    await _openPlan(
      await planFor(
        topicIds: byStage[stage]!
            .where((s) => s.canPractice)
            .map((s) => s.topic.id)
            .toSet(),
      ),
    );
  }

  Future<void> _openPlan(
    LessonPlan plan, {
    bool continuePlanning = false,
  }) async {
    if (opening.value) return;
    opening.value = true;
    try {
      await Get.toNamed(
        '/lesson',
        arguments: {
          LessonBinding.planArg: plan,
          LessonBinding.continuePlanningArg: continuePlanning,
        },
      );
      await refreshBoard();
    } finally {
      opening.value = false;
    }
  }
}
