import 'dart:math';

import 'exercise.dart';
import 'learning_rules.dart';
import 'progress_event.dart';

/// Результат ответа на текущее задание.
enum AnswerOutcome { correct, wrong }

/// Один блок сессии. Ошибка не раздувает общий бюджет: показываем верный
/// ответ и, если есть добавочное задание, заменяем его повтором ошибки.
/// Обязательный материал при этом не исчезает. См. SPEC.md §5.
class LessonSession {
  LessonSession({
    required List<Exercise> exercises,
    required this.sessionId,
    this.rules = const LearningRules(),
    int? taskLimit,
    DateTime Function()? now,
  }) : _queue = List.of(exercises),
       _taskLimit = taskLimit ?? rules.tasksPerSession,
       _now = now ?? DateTime.now;

  final int sessionId;
  final LearningRules rules;
  final int _taskLimit;
  final DateTime Function() _now;

  final List<Exercise> _queue;
  final List<LogEntry> _log = [];

  /// Задания, уже поставленные на повтор. Человек остаётся на провальном
  /// задании до верного ответа, поэтому без этого каждый промах добавлял бы
  /// ещё одну копию — и хвост урока превращался в одну букву подряд.
  final Set<Exercise> _requeuedOnce = Set.identity();

  /// Сколько раз отвечали на текущее задание. Со второй попытки ответ
  /// засчитывается, но атом вперёд не двигает.
  int _attempt = 1;
  int _index = 0;
  int _requeued = 0;

  Exercise? get current => _index < _queue.length ? _queue[_index] : null;
  bool get isFinished => current == null;

  /// Знаменатель прогресса — исходная длина, а не текущая: полоса не должна
  /// ползти назад от того, что человек ошибся.
  int get total => _queue.length;
  int get position => _index;
  double get progress => total == 0 ? 1 : _index / total;

  List<LogEntry> get log => List.unmodifiable(_log);

  /// Переносит запланированное произношение к только что введённой букве.
  /// Уже пройденные задания и общее число заданий не меняются.
  void prioritizePronunciation(String atomId) {
    final at = _queue.indexWhere(
      (e) => e.atom.id == atomId && e.mode == ExerciseMode.sayName,
      _index,
    );
    if (at < 0) throw StateError('Нет произношения для $atomId');
    _queue.insert(_index, _queue.removeAt(at));
  }

  /// [fastEnough] считает вызывающий: порог зависит от режима.
  AnswerOutcome answer(
    Exercise exercise,
    int optionIndex, {
    required bool fastEnough,
    Map<String, bool>? atomResults,
  }) {
    final correct = optionIndex == exercise.answerIndex;
    final resultAtoms = exercise.resultAtoms;
    final results =
        atomResults ?? {for (final atom in resultAtoms) atom.id: correct};
    if (results.length != resultAtoms.length ||
        resultAtoms.any((atom) => !results.containsKey(atom.id)) ||
        correct != results.values.every((value) => value)) {
      throw ArgumentError.value(
        atomResults,
        'atomResults',
        'Результаты должны точно соответствовать элементам задания',
      );
    }

    final at = _now();
    _log.addAll([
      for (final atom in resultAtoms)
        ProgressEvent(
          atomId: atom.id,
          sessionId: sessionId,
          at: at,
          mode: exercise.mode,
          correct: results[atom.id]!,
          attempt: _attempt,
          fastEnough: fastEnough,
        ),
    ]);

    if (!correct) {
      _attempt++;
      _requeue(exercise);
      return AnswerOutcome.wrong;
    }

    _attempt = 1;
    _index++;
    return AnswerOutcome.correct;
  }

  /// Пропустить задание, не записывая ответ. Только для отладки: атом
  /// не двигается ни вперёд, ни назад — в логе не остаётся следа.
  void skip() {
    if (isFinished) return;
    _attempt = 1;
    _index++;
  }

  /// Убирает ещё не показанные задания режима, который технически
  /// недоступен до конца сессии. Уже пройденные позиции не трогаем,
  /// чтобы общий счётчик не откатывался назад.
  int discardPendingMode(ExerciseMode mode) {
    var removed = 0;
    for (var i = _queue.length - 1; i >= _index; i--) {
      if (_queue[i].mode != mode) continue;
      _queue.removeAt(i);
      removed++;
    }
    return removed;
  }

  /// Провалённое задание возвращается в очередь — один раз и не в самый
  /// конец, а через несколько шагов: так оно попадётся, пока разбор ещё
  /// свежий, и не соберётся в хвост из одинаковых вопросов.
  void _requeue(Exercise exercise) {
    if (!_requeuedOnce.add(exercise)) return;

    // Если такая же проверка этой буквы уже встретится ещё раз, она и будет
    // отложенным повтором. Третья копия снова превращала пару букв в A/B/A/B.
    final equivalentCount = _queue
        .where(
          (candidate) =>
              candidate.atom.id == exercise.atom.id &&
              candidate.mode == exercise.mode,
        )
        .length;
    if (equivalentCount >= _maxEquivalentExercises) return;

    // Повтор ошибки не раздувает занятие сверх его бюджета. Если
    // очередь уже полна, он вытесняет последнее добавочное задание.
    // Обязательную форму или режим выкидывать нельзя.
    if (_queue.length >= _taskLimit) {
      final removable = _queue.lastIndexWhere(
        (candidate) => !candidate.isRequired,
        _queue.length - 1,
      );
      if (removable <= _index) return;
      _queue.removeAt(removable);
    }

    final at = min(_index + _requeueGap, _queue.length);
    _queue.insert(at, exercise);
    _requeued++;
  }

  /// Через сколько заданий провал вернётся. Сразу — человек ответит по
  /// памяти, в самый конец — забудет разбор.
  static const _requeueGap = 3;
  static const _maxEquivalentExercises = 2;

  int get requeuedCount => _requeued;

  /// Порядок атомов в очереди — для тестов и отладки.
  List<String> get queueIds => [for (final e in _queue) e.atom.id];
}
