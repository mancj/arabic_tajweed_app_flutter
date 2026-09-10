import 'package:flutter/material.dart';

import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';

/// Раскладывание трёх соединённых форм одной буквы по позициям.
///
/// Слоты заполняются строго по очереди. Заполненный слот можно очистить
/// тапом и вернуть его плитку. После третьего выбора весь порядок отправляется
/// наружу одним ответом — промежуточные тапы не проверяются.
class FormSequenceExercise extends StatefulWidget {
  const FormSequenceExercise({
    required this.options,
    required this.onCompleted,
    super.key,
  });

  final List<Atom> options;
  final ValueChanged<List<Atom>> onCompleted;

  @override
  State<FormSequenceExercise> createState() => _FormSequenceExerciseState();
}

class _FormSequenceExerciseState extends State<FormSequenceExercise> {
  final _placed = List<Atom?>.filled(_positions.length, null);
  bool _completed = false;

  void _place(Atom atom) {
    if (_completed || _placed.contains(atom)) return;
    final activeIndex = _placed.indexWhere((placed) => placed == null);
    if (activeIndex == -1) return;
    setState(() {
      _placed[activeIndex] = atom;
      _completed = _placed.every((placed) => placed != null);
    });
    if (_completed) {
      widget.onCompleted(List.unmodifiable(_placed.whereType<Atom>()));
    }
  }

  void _remove(int index) {
    if (_completed || _placed[index] == null) return;
    setState(() => _placed[index] = null);
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _placed.indexWhere((placed) => placed == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, position) in _positions.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: _FormSlot(
                  position: position,
                  atom: _placed[index],
                  active: index == activeIndex && !_completed,
                  onTap: () => _remove(index),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text('Выберите форму для выделенного слота', style: UITextStyles.hint),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (index, atom) in widget.options.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: _FormTile(
                  atom: atom,
                  used: _placed.contains(atom),
                  onTap: () => _place(atom),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

const _positions = [
  LetterForm.initial,
  LetterForm.medial,
  LetterForm.finalForm,
];

class _FormSlot extends StatelessWidget {
  const _FormSlot({
    required this.position,
    required this.atom,
    required this.active,
    required this.onTap,
  });

  final LetterForm position;
  final Atom? atom;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placedAtom = atom;
    final slot = AnimatedContainer(
      key: ValueKey('form-slot-${position.name}'),
      duration: const Duration(milliseconds: 180),
      height: 108,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: SquircleBorders.squircleBorder(
        color: active ? UIColors.primary10 : UIColors.cardBackground,
        borderRadius: 18,
        borderSide: BorderSide(
          color: active ? UIColors.primary : UIColors.borders,
          width: active ? 2 : 1,
        ),
        shadows: active
            ? [
                BoxShadow(
                  color: UIColors.primary20,
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Text(
            position.title,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: UITextStyles.regular12.copyWith(
              color: active ? UIColors.text : UIColors.secondary2,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Expanded(
            child: Center(
              child: placedAtom == null
                  ? Text(
                      '?',
                      style: UITextStyles.cardTitle.copyWith(
                        color: active
                            ? UIColors.primary
                            : UIColors.backgroundShapes2,
                      ),
                    )
                  : _Glyph(placedAtom.display),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: 'Слот: ${position.title}',
      hint: placedAtom == null ? null : 'Нажмите, чтобы убрать форму',
      selected: active,
      button: placedAtom != null,
      child: placedAtom == null
          ? slot
          : AppGestureDetector(onTap: onTap, child: slot),
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({
    required this.atom,
    required this.used,
    required this.onTap,
  });

  final Atom atom;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Форма ${atom.display}',
      enabled: !used,
      child: IgnorePointer(
        ignoring: used,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: used ? 0 : 1,
          child: AppGestureDetector(
            key: ValueKey('form-tile-${atom.id}'),
            onTap: onTap,
            child: Container(
              height: 72,
              decoration: SquircleBorders.squircleBorder(
                color: UIColors.cardBackground,
                borderRadius: 18,
                borderSide: BorderSide(color: UIColors.borders),
                shadows: [
                  BoxShadow(
                    color: UIColors.shadows,
                    offset: const Offset(0, 2),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Center(child: _Glyph(atom.display)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        color: UIColors.text,
        fontFamily: UITextStyles.fontScheherazadeNew,
        fontSize: 38,
        height: 1,
      ),
    );
  }
}
