import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_scaffold.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/form_sequence_exercise.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/next_button.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:flutter/material.dart';

/// Отдельный стенд для проверки механики и анимаций выбора форм буквы.
class FormSequenceDebugPage extends StatefulWidget {
  static const routeName = '/debug/form-sequence';

  const FormSequenceDebugPage({super.key});

  @override
  State<FormSequenceDebugPage> createState() => _FormSequenceDebugPageState();
}

class _FormSequenceDebugPageState extends State<FormSequenceDebugPage> {
  static const _forms = [
    Atom(
      id: 'debug.ba.isolated',
      kind: AtomKind.letterForm,
      display: 'ب',
      label: 'Ба',
      letterId: 'ba',
      form: LetterForm.isolated,
    ),
    Atom(
      id: 'debug.ba.initial',
      kind: AtomKind.letterForm,
      display: 'بـ',
      label: 'Ба',
      letterId: 'ba',
      form: LetterForm.initial,
    ),
    Atom(
      id: 'debug.ba.medial',
      kind: AtomKind.letterForm,
      display: 'ـبـ',
      label: 'Ба',
      letterId: 'ba',
      form: LetterForm.medial,
    ),
    Atom(
      id: 'debug.ba.final',
      kind: AtomKind.letterForm,
      display: 'ـب',
      label: 'Ба',
      letterId: 'ba',
      form: LetterForm.finalForm,
    ),
  ];

  int _round = 0;
  List<Atom>? _answer;

  List<Atom> get _options => [
    for (var index = 0; index < _forms.length; index++)
      _forms[(index + _round + 1) % _forms.length],
  ];

  bool get _isCorrect =>
      _answer?.indexed.every((item) => item.$2.form == _forms[item.$1].form) ??
      false;

  void _reset() {
    setState(() {
      _round++;
      _answer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Формы буквы',
      bottomBar: NextButton(
        title: _answer == null ? 'Сбросить' : 'Повторить',
        onTap: _reset,
      ),
      builder: (_, insets) => SingleChildScrollView(
        padding: insets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Расставьте формы буквы «Ба»', style: UITextStyles.semibold17),
            const SizedBox(height: 20),
            FormSequenceExercise(
              key: ValueKey('form-sequence-debug-$_round'),
              options: _options,
              onCompleted: (answer) => setState(() => _answer = answer),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _answer == null
                  ? Text(
                      'Результат появится после заполнения четырёх слотов',
                      key: const ValueKey('form-sequence-debug-pending'),
                      style: UITextStyles.hint,
                    )
                  : Text(
                      _isCorrect ? 'Верно' : 'Неверный порядок',
                      key: const ValueKey('form-sequence-debug-result'),
                      style: UITextStyles.semibold17.copyWith(
                        color: _isCorrect
                            ? UIColors.primary
                            : UIColors.secondary2,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
