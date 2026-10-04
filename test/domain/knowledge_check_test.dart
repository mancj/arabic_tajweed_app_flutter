import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/knowledge_check.dart';
import 'package:arabic_tajweed_app/domain/progress_event.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Новые темы не должны добавлять в проверку будущие буквы или вопросы,
/// которые нельзя собрать из материала уже пройденного пути. Вопросы по
/// буквам и хамзе не должны возвращаться в чужих для них режимах.
void main() {
  test('только недостающие формы хамзы не создают чужие упражнения', () {
    final curriculum = CurriculumLoader.merge([
      for (final stage in [1, 2, 3])
        CurriculumLoader.parse(
          File('assets/curriculum/stage$stage.json').readAsStringSync(),
        ),
    ]);
    final context = CurriculumContext(
      progress: {
        for (final node in curriculum.nodes)
          if (node.atom.letterId != 'hamza' || node.atom.kind != AtomKind.sign)
            node.atom.id: const AtomProgress(state: AtomState.known),
      },
      formsByLetter: curriculum.formsByLetter,
    );
    final check = KnowledgeCheck(
      curriculum: curriculum,
      topic: curriculum.topics.firstWhere((t) => t.id == 'm.haraka.intro'),
      context: context,
      random: Random(0),
    );
    expect(check.questions, isEmpty);
    expect(check.inferredAtoms, hasLength(5));
    expect(check.isCondensed, isFalse);
  });

  test('каждый перескок использует доступные варианты знакомых заданий', () {
    final curriculum = CurriculumLoader.merge([
      for (final stage in [1, 2, 3])
        CurriculumLoader.parse(
          File('assets/curriculum/stage$stage.json').readAsStringSync(),
        ),
    ]);
    final context = CurriculumContext(
      progress: const {},
      formsByLetter: curriculum.formsByLetter,
    );

    for (final (index, topic) in curriculum.topics.indexed.skip(1)) {
      final check = KnowledgeCheck(
        curriculum: curriculum,
        topic: topic,
        context: context,
        random: Random(index),
      );
      final allowed = {
        for (final previous in curriculum.topics.take(index))
          ...previous.counterOf,
        for (final atom in check.atoms) atom.id,
      };
      expect(check.questions.length, lessThanOrEqualTo(20), reason: topic.id);
      expect(
        check.questions.any(
          (q) => q.atom.kind == AtomKind.sign && q.atom.letterId == 'hamza',
        ),
        isFalse,
        reason: topic.id,
      );
      for (final question in check.questions) {
        expect(
          question.options.every(
            (option) =>
                allowed.contains(option.id) ||
                (question.atom.kind == AtomKind.syllable &&
                    option.id.startsWith('${question.atom.id}.')),
          ),
          isTrue,
          reason: topic.id,
        );
        expect(question.options.length, greaterThan(1), reason: topic.id);
        final hasAudio =
            question.atom.audioAsset != null ||
            question.atom.kind == AtomKind.letterForm;
        if (question.atom.kind == AtomKind.letterForm) {
          expect(question.mode, ExerciseMode.soundToLetter, reason: topic.id);
        } else if (hasAudio) {
          expect(
            question.mode,
            anyOf(ExerciseMode.soundToLetter, ExerciseMode.letterToSound),
            reason: topic.id,
          );
        }
      }
      if (topic.id == 'm.haraka.intro') {
        expect(
          check.inferredAtoms
              .where(
                (atom) =>
                    atom.kind == AtomKind.sign && atom.letterId == 'hamza',
              )
              .length,
          5,
        );
      }
      final afterCheck = CurriculumContext(
        progress: {
          for (final atom in check.atoms)
            atom.id: AtomProgress(
              state: atom.kind == AtomKind.concept
                  ? AtomState.introduced
                  : AtomState.known,
              weak: atom.kind != AtomKind.concept,
            ),
        },
        formsByLetter: curriculum.formsByLetter,
      );
      final status = TopicBoard(curriculum).statuses(afterCheck)[index];
      expect(status.canPractice, isTrue, reason: topic.id);
    }
  });
}
