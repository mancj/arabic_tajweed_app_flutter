import 'dart:math';

import 'exercise.dart';
import 'learning_rules.dart';
import 'progress_event.dart';

/// Результат ответа на текущее задание.
enum AnswerOutcome { correct, wrong }

/// Одна сессия. Двенадцать заданий, ошибка не блокирует прохождение:
/// показываем верный ответ и отправляем задание в конец очереди.
/// Очередь растёт максимум до шестнадцати — иначе в плохой день сессия
/// становится бесконечной. См. SPEC.md §5.
class LessonSession {
  LessonSession({
    required List<Exercise> exercises,
    required this.sessionId,
    this.rules = const LearningRules(),
    DateTime Function()? now,
  }) : _queue = List.of(exercises),
       _now = now ?? DateTime.now;

  final int sessionId;
  final LearningRules rules;
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

  /// [fastEnough] считает вызывающий: порог зависит от режима.
  AnswerOutcome answer(
    Exercise exercise,
    int optionIndex, {
    required bool fastEnough,
  }) {
    final correct = optionIndex == exercise.answerIndex;

    _log.add(
      ProgressEvent(
        atomId: exercise.atom.id,
        sessionId: sessionId,
        at: _now(),
        mode: exercise.mode,
        correct: correct,
        attempt: _attempt,
        fastEnough: fastEnough,
      ),
    );

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

  /// Провалённое задание возвращается в очередь — один раз и не в самый
  /// конец, а через несколько шагов: так оно попадётся, пока разбор ещё
  /// свежий, и не соберётся в хвост из одинаковых вопросов.
  void _requeue(Exercise exercise) {
    if (_queue.length >= rules.maxTasksPerSession) return;
    if (!_requeuedOnce.add(exercise)) return;

    final at = min(_index + _requeueGap, _queue.length);
    _queue.insert(at, exercise);
    _requeued++;
  }

  /// Через сколько заданий провал вернётся. Сразу — человек ответит по
  /// памяти, в самый конец — забудет разбор.
  static const _requeueGap = 3;

  int get requeuedCount => _requeued;

  /// Порядок атомов в очереди — для тестов и отладки.
  List<String> get queueIds => [for (final e in _queue) e.atom.id];
}
