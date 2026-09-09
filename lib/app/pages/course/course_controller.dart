import 'dart:async';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../../../data/curriculum_loader.dart';
import '../../../data/progress_database.dart';
import '../../../data/progress_repository.dart';
import '../../../domain/atom.dart';
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
        TopicBoard(curriculum).statuses(
          context,
          completed: completions.map((id, c) => MapEntry(id, c.byTest)),
          currentId: plan.topicId,
        ),
      );
      nextPlan.value = plan;
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
    await _openPlan(nextPlan.value!);
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

  Future<void> _openPlan(LessonPlan plan) async {
    if (opening.value) return;
    opening.value = true;
    try {
      await Get.toNamed('/lesson', arguments: {LessonBinding.planArg: plan});
      await refreshBoard();
    } finally {
      opening.value = false;
    }
  }
}
