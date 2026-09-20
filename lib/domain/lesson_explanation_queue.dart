import 'package:collection/collection.dart';

import 'atom.dart';
import 'curriculum.dart';
import 'exercise.dart';
import 'planner.dart';

/// Выбирает объяснения для блока и перед заданием, не управляя экраном или
/// журналом прогресса. Правила показа букв живут здесь, а не в ходе урока.
class LessonExplanationQueue {
  LessonExplanationQueue(this.curriculum);

  final Curriculum curriculum;
  final _shownCards = <String>{};
  final _shownFormsOverviews = <String>{};
  final _ownAtoms = <String>{};
  final _pendingCards = <Atom>[];

  Atom? card;
  List<Atom> formsOverview = const [];

  void activate(LessonPlan plan, {String? topicId}) {
    _ownAtoms.addAll(
      plan.isFocusedReview || topicId == null
          ? plan.newAtoms.map((atom) => atom.id)
          : curriculum.topics
                    .firstWhereOrNull((topic) => topic.id == topicId)
                    ?.counterOf ??
                const [],
    );
    card = null;
    formsOverview = const [];
  }

  List<Atom> introFor(LessonPlan plan, {String? topicId}) {
    if (plan.isFocusedReview) return const [];
    if (topicId == null) return plan.newAtoms.where(_belongsToIntro).toList();

    final inLesson = {
      for (final atom in plan.newAtoms) atom.id: atom,
      for (final id in plan.reviewAtoms)
        if (_atomById(id) case final atom?) id: atom,
    };
    final topic = curriculum.topics.firstWhereOrNull((t) => t.id == topicId);
    return [
      for (final id in topic?.counterOf ?? const <String>[])
        if (inLesson[id] case final atom?)
          if (_belongsToIntro(atom)) atom,
    ];
  }

  void prepareFor(Exercise? exercise) {
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

  void dismissOverview() {
    final letterId = card?.letterId;
    if (letterId != null) _shownFormsOverviews.add(letterId);
    formsOverview = const [];
  }

  void dismissCard() {
    final atom = card;
    if (atom == null) return;
    _shownCards.add(atom.id);
    _nextCard();
  }

  void _nextCard() {
    card = _pendingCards.isEmpty ? null : _pendingCards.removeAt(0);
    formsOverview = _formsOverviewBefore(card);
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
      for (final id in curriculum.formsByLetter[letterId] ?? const <String>[])
        if (_atomById(id) case final form?) form,
    ];
    return [
      for (final position in _formsOverviewOrder)
        ...forms.where((form) => form.form == position),
    ];
  }

  Atom? _atomById(String id) =>
      curriculum.nodes.firstWhereOrNull((node) => node.atom.id == id)?.atom;

  static bool _belongsToIntro(Atom atom) =>
      atom.form == null || atom.form == LetterForm.isolated;

  static const _formsOverviewOrder = [
    LetterForm.isolated,
    LetterForm.initial,
    LetterForm.medial,
    LetterForm.finalForm,
  ];
}
