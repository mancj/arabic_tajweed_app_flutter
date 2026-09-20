import 'package:get/get.dart';

import '../../../domain/atom.dart';
import '../../../domain/form_sequence_evaluation.dart';

/// Подсказки между попытками раскладки форм. Проверка самих мест живёт в
/// [FormSequenceEvaluation]; здесь только состояние текущего задания.
class FormSequenceTaskState {
  final attempt = 0.obs;
  List<bool>? slotResults;
  List<Atom?> initialPlaced = const [];
  bool revealAnswer = false;

  int get correctCount => slotResults?.where((result) => result).length ?? 0;

  void reset() {
    attempt.value = 0;
    slotResults = null;
    initialPlaced = const [];
    revealAnswer = false;
  }

  FormSequenceEvaluation evaluate({
    required List<Atom> options,
    required List<Atom> placed,
  }) {
    final evaluation = FormSequenceEvaluation.evaluate(
      options: options,
      placed: placed,
    );
    slotResults = evaluation.correct ? null : evaluation.slotResults;
    initialPlaced = evaluation.initialPlaced;
    revealAnswer = !evaluation.correct && attempt.value == 2;
    return evaluation;
  }

  void retry() => attempt.value++;
}
