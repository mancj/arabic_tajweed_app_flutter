import 'connection_build_question.dart';
import 'haraka_syllables.dart';
import 'word_build_question.dart';

/// Ответ собирается двумя проходами. После ошибки очищаются только
/// неверные части. Состояние одинаково для курса и отдельного просмотра.
class ConnectedBuildAnswer {
  ConnectedBuildAnswer.connection(ConnectionBuildQuestion question)
    : connection = question,
      word = null,
      formIds = [null],
      markIds = [null];
  ConnectedBuildAnswer.word(WordBuildQuestion question)
    : word = question,
      connection = null,
      formIds = List.filled(question.steps.length, null),
      markIds = List.filled(question.steps.length, null);

  final ConnectionBuildQuestion? connection;
  final WordBuildQuestion? word;
  final List<String?> formIds;
  final List<String?> markIds;
  ConnectionBuildEvaluation? connectionEvaluation;
  WordBuildEvaluation? wordEvaluation;
  int? changedIndex;
  int revision = 0;

  bool get isComplete => !formIds.contains(null) && !markIds.contains(null);
  bool get correct =>
      connectionEvaluation?.correct ?? wordEvaluation?.correct ?? false;
  WordBuildPhase get phase =>
      formIds.contains(null) ? WordBuildPhase.forms : WordBuildPhase.marks;
  int get activeIndex {
    final index = (phase == WordBuildPhase.forms ? formIds : markIds).indexOf(
      null,
    );
    return index < 0 ? changedIndex ?? 0 : index;
  }

  bool selectForm(int index, String id) {
    if (isComplete ||
        index != activeIndex ||
        (word != null && phase != WordBuildPhase.forms)) {
      return false;
    }
    final options = connection?.formOptions ?? word!.steps[index].formOptions;
    if (!options.any((atom) => atom.id == id)) return false;
    formIds[index] = id;
    changedIndex = index;
    _evaluate();
    return true;
  }

  bool selectMark(int index, String id) {
    if (isComplete ||
        phase != WordBuildPhase.marks ||
        index != activeIndex ||
        !HarakaSyllables.marks.any((mark) => mark.id == id)) {
      return false;
    }
    markIds[index] = id;
    changedIndex = index;
    _evaluate();
    return true;
  }

  void _evaluate() {
    if (!isComplete) return;
    connectionEvaluation = connection?.evaluate(
      formId: formIds.single!,
      markId: markIds.single!,
    );
    wordEvaluation = word?.evaluate(
      formIds.cast<String>(),
      markIds.cast<String>(),
    );
  }

  Map<String, bool> get atomResults => connection != null
      ? connection!.atomResults(connectionEvaluation!)
      : word!.atomResults(wordEvaluation!);

  void retry() {
    if (!isComplete || correct) return;
    final letters = wordEvaluation?.letters ?? [connectionEvaluation!];
    for (final (index, result) in letters.indexed) {
      if (!result.formCorrect) formIds[index] = null;
      if (!result.harakaCorrect) markIds[index] = null;
    }
    connectionEvaluation = null;
    wordEvaluation = null;
    changedIndex = null;
    revision++;
  }

  void answerCorrectly() {
    for (var index = 0; index < formIds.length; index++) {
      formIds[index] =
          connection?.expectedFormId ?? word!.steps[index].expectedFormId;
      markIds[index] =
          connection?.expectedMarkId ?? word!.steps[index].expectedMarkId;
    }
    _evaluate();
  }
}
