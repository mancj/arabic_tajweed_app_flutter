import 'dart:async';

import 'package:get/get.dart';

import '../../../data/curriculum_loader.dart';
import '../../../data/progress_database.dart';
import '../../../data/progress_repository.dart';
import '../../../domain/curriculum.dart';
import '../../../domain/learning_rules.dart';
import '../../../domain/topic_board.dart';
import '../lesson/lesson_binding.dart';

/// Главный экран: карточка «Продолжить» и список тем.
///
/// Списка уроков здесь нет и быть не может — уроки генерируются, впереди
/// известен только следующий. Зато понятия конечны и известны заранее.
/// См. SPEC.md §8.
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

  /// Готовый граф вместо чтения ассета. Нужен тестам: rootBundle в них
  /// отдаёт файл только в первом тесте файла, дальше запрос повисает.
  final Curriculum? _injectedCurriculum;

  final loading = true.obs;
  final loadError = RxnString();
  final statuses = <TopicStatus>[].obs;

  /// TODO(streak): стрик пока не считается — нужен журнал заходов по дням.
  /// См. SPEC.md §9.
  final streakDays = 0.obs;

  late final Curriculum _curriculum;
  late final ProgressRepository _progress;

  @override
  void onInit() {
    super.onInit();
    // Ошибку загрузки нельзя глотать: экран навсегда останется на индикаторе,
    // а причина будет невидима.
    unawaited(
      refreshBoard().catchError((Object e, StackTrace st) {
        loadError.value = '$e';
        loading.value = false;
        Error.throwWithStackTrace(e, st);
      }),
    );
  }

  /// Вызывается и при первом открытии, и при возврате с урока: прогресс
  /// мог измениться, а экран должен это показать.
  Future<void> refreshBoard() async {
    if (!_ready) {
      _curriculum =
          _injectedCurriculum ?? await const CurriculumLoader().load();
      _progress = ProgressRepository(
        database: _database ?? Get.find<ProgressDatabase>(),
        rules: rules,
      );
      _ready = true;
    } else {
      await _progress.recompute();
    }

    final ctx = CurriculumContext(
      progress: await _progress.progress(),
      formsByLetter: _formsByLetter(),
    );
    final completions = await _progress.completions();
    statuses.assignAll(
      TopicBoard(_curriculum).statuses(
        ctx,
        completed: {for (final e in completions.entries) e.key: e.value.byTest},
        currentId: await _currentTopicId(completions.keys.toSet(), ctx),
      ),
    );
    loading.value = false;
  }

  bool _ready = false;

  /// Урок, к которому ведёт «Продолжить»: тот, которым занимались
  /// последним. Если такого нет — первый доступный.
  Future<String?> _currentTopicId(
    Set<String> completed,
    CurriculumContext ctx,
  ) async {
    final last = await _progress.lastActiveTopicId();
    if (last != null && !completed.contains(last)) return last;

    // Первый незакрытый урок, до которого человек уже дошёл. Условие
    // открытия — прохождение предыдущего, ровно как в списке.
    final topics = _curriculum.topics;
    for (final (index, topic) in topics.indexed) {
      if (completed.contains(topic.id)) continue;
      final previous = index == 0 ? null : topics[index - 1];
      if (previous == null || completed.contains(previous.id)) return topic.id;
      break;
    }
    return null;
  }

  TopicStatus? get currentTopic =>
      statuses.firstWhereOrNull((s) => s.state == TopicState.current);

  /// Урок, в который ведёт кнопка внизу. null, когда пройдено всё:
  /// тогда собирать занятие будет планировщик, а не список тем.
  TopicStatus? get continueTarget => currentTopic;

  /// Всё открытое пройдено — впереди только повторение.
  bool get allDone =>
      statuses.isNotEmpty && statuses.every((s) => !s.canPractice || s.isDone);

  /// Подпись кнопки. Если впереди всё закрыто и остаётся только повторять
  /// пройденное, кнопка так и говорит: обещать «продолжить» и приводить
  /// в урок с галочкой — вводить в заблуждение.
  String get continueLabel {
    final target = continueTarget;
    if (target == null) return statuses.isEmpty ? 'Начать' : 'Повторить';
    return switch (target.state) {
      TopicState.done || TopicState.passedByTest => 'Повторить',
      _ when !target.started => 'Начать',
      _ => 'Продолжить',
    };
  }

  /// Ближайшая закрытая тема и чего ей не хватает — чтобы человек понимал,
  /// ради чего повторяет.
  TopicStatus? get nextLocked =>
      statuses.firstWhereOrNull((s) => s.state == TopicState.locked);

  /// Уроки, которые начали и бросили, уйдя вперёд.
  List<TopicStatus> get unfinished =>
      statuses.where((s) => s.state == TopicState.unfinished).toList();

  bool get isStarted =>
      statuses.any((s) => s.state != TopicState.locked && s.done > 0);

  /// Нажатие по теме открывает урок именно по ней: незнакомое вводится,
  /// знакомое повторяется. Уводить отсюда туда, куда собирался планировщик,
  /// нельзя — человек нажал на конкретную тему.
  Future<void> open(TopicStatus status) async {
    if (!status.canPractice) return;
    await Get.toNamed(
      _lessonRoute,
      arguments: {LessonBinding.topicArg: status.topic.id},
    );
    await refreshBoard();
  }

  /// Кнопка внизу экрана ведёт в тот же урок, что и его строка в списке.
  ///
  /// Иначе урок открывался бы без привязки к теме, и отмечать по окончании
  /// было бы нечего: список так и показывал бы его незакрытым.
  Future<void> continueCourse() async {
    final topic =
        currentTopic ?? statuses.firstWhereOrNull((s) => s.canPractice);
    if (topic == null) return;
    await open(topic);
  }

  static const _lessonRoute = '/lesson';

  Map<String, List<String>> _formsByLetter() {
    final result = <String, List<String>>{};
    for (final node in _curriculum.nodes) {
      final letterId = node.atom.letterId;
      if (letterId == null) continue;
      (result[letterId] ??= []).add(node.atom.id);
    }
    return result;
  }

  /// Темы, сгруппированные по этапам, в порядке этапов.
  Map<int, List<TopicStatus>> get byStage {
    final result = <int, List<TopicStatus>>{};
    for (final status in statuses) {
      (result[status.topic.stage] ??= []).add(status);
    }
    return result;
  }
}
