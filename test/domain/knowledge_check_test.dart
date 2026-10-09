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
/// буквам не должны возвращаться в чужих для них режимах.
void main() {
  // Смена порядка генератора не должна снова ставить две проверки
  // одного элемента рядом; обе встречи и прежние форматы сохраняются.
  test('вопросы перемешаны, повтор одного элемента не идёт подряд', () {
    final curriculum = CurriculumLoader.merge([
      for (final asset in CurriculumLoader.defaultAssets)
        CurriculumLoader.parse(File(asset).readAsStringSync()),
    ]);
    for (final topic in curriculum.topics.skip(1)) {
      for (var seed = 0; seed < 10; seed++) {
        final check = KnowledgeCheck(
          curriculum: curriculum,
          topic: topic,
          context: CurriculumContext(
            progress: const {},
            formsByLetter: curriculum.formsByLetter,
          ),
          random: Random(seed),
        );
        final ids = check.questions.map((q) => q.atom.id).toList();
        for (final atom in check.checkedAtoms) {
          expect(ids.where((id) => id == atom.id), hasLength(2));
        }
        if (check.checkedAtoms.length > 1) {
          for (var i = 1; i < ids.length; i++) {
            expect(ids[i], isNot(ids[i - 1]), reason: '${topic.id}, $seed');
          }
        }
      }
    }
  });

  test('каждый перескок использует доступные варианты знакомых заданий', () {
    final curriculum = CurriculumLoader.merge([
      for (final asset in CurriculumLoader.defaultAssets)
        CurriculumLoader.parse(File(asset).readAsStringSync()),
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
