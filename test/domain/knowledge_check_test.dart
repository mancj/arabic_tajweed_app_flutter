import 'dart:io';
import 'dart:math';

import 'package:arabic_tajweed_app/data/curriculum_loader.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/atom_state.dart';
import 'package:arabic_tajweed_app/domain/curriculum.dart';
import 'package:arabic_tajweed_app/domain/knowledge_check.dart';
import 'package:arabic_tajweed_app/domain/topic_board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Новые темы не должны добавлять в проверку будущие буквы или вопросы,
/// которые нельзя собрать из материала уже пройденного пути.
void main() {
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
      for (final question in check.questions) {
        expect(
          question.options.every((option) => allowed.contains(option.id)),
          isTrue,
          reason: topic.id,
        );
        expect(question.options.length, greaterThan(1), reason: topic.id);
        final hasAudio =
            question.atom.audioAsset != null ||
            question.atom.kind == AtomKind.letterForm;
        if (hasAudio) {
          expect(
            question.mode,
            anyOf(
              KnowledgeQuestionMode.soundToForm,
              KnowledgeQuestionMode.formToSound,
            ),
            reason: topic.id,
          );
        }
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
