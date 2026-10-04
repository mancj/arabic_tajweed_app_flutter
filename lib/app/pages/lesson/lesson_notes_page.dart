import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/ui_kit/notes_pager.dart';
import 'lesson_content_view.dart';
import 'lesson_controller.dart';

/// Объяснения и повторы текущего занятия на отдельном маршруте.
class LessonNotesPage extends StatelessWidget {
  static const routeName = '/lesson/notes';

  const LessonNotesPage({required this.controller, super.key});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final notes = controller.lessonNotes;
    return AppScaffold(
      title: 'Конспект занятия',
      builder: (context, insets) => notes.isNotEmpty
          ? NotesPager(
              items: [
                for (final note in notes) (id: note.id, title: note.title),
              ],
              insets: insets,
              initialIndex: controller.preferredNoteIndex < 0
                  ? 0
                  : controller.preferredNoteIndex,
              tabKeyPrefix: 'lesson-note',
              itemBuilder: (context, index, active) =>
                  LessonNoteCard(note: notes[index]),
            )
          : Padding(
              padding: EdgeInsets.only(top: insets.top, bottom: insets.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: insets.left,
                        right: insets.right,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                UISVGAssets.notes,
                                width: 48,
                                height: 48,
                                colorFilter: ColorFilter.mode(
                                  UIColors.secondary1,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Здесь появятся конспекты',
                                style: UITextStyles.semibold20,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Конспекты появятся здесь после того, как они появятся в ходе урока.',
                                style: UITextStyles.regular15,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
