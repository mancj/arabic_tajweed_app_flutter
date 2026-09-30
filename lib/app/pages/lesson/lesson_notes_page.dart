import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/ui_kit/next_button.dart';
import 'lesson_content_view.dart';
import 'lesson_controller.dart';

/// Прочитанные объяснения текущего занятия на отдельном маршруте.
class LessonNotesPage extends StatefulWidget {
  static const routeName = '/lesson/notes';

  const LessonNotesPage({required this.controller, super.key});

  final LessonController controller;

  @override
  State<LessonNotesPage> createState() => _LessonNotesPageState();
}

class _LessonNotesPageState extends State<LessonNotesPage> {
  late int selectedIndex;
  final _selectedTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.controller.preferredNoteIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedContext = _selectedTabKey.currentContext;
      if (mounted && selectedContext != null) {
        Scrollable.ensureVisible(selectedContext, duration: Duration.zero);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.controller.shownNotes;
    return AppScaffold(
      title: 'Конспект занятия',
      bottomBar: NextButton(
        title: widget.controller.stage.value == LessonStage.intro
            ? 'Вернуться к уроку'
            : 'Вернуться к заданию',
        onTap: () => Get.back(),
      ),
      builder: (context, insets) => Padding(
        padding: insets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notes.isNotEmpty) ...[
              SizedBox(
                height: 60,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (index, note) in notes.indexed) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Container(
                          key: index == selectedIndex ? _selectedTabKey : null,
                          child: Semantics(
                            selected: index == selectedIndex,
                            child: TextButton(
                              key: ValueKey('lesson-note-${note.id}'),
                              onPressed: () =>
                                  setState(() => selectedIndex = index),
                              style: TextButton.styleFrom(
                                backgroundColor: index == selectedIndex
                                    ? UIColors.primary
                                    : UIColors.cardBackground,
                                foregroundColor: index == selectedIndex
                                    ? UIColors.primaryButtonText
                                    : UIColors.text,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: UIColors.borders),
                                ),
                              ),
                              child: Text('${index + 1}. ${note.title}'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: LessonNoteCard(
                    key: ValueKey(notes[selectedIndex].id),
                    note: notes[selectedIndex],
                  ),
                ),
              ),
            ] else
              Expanded(
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
                          color: UIColors.secondary1,
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
          ],
        ),
      ),
    );
  }
}
