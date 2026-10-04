import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Общая поверхность плитки для сборки форм, букв и огласовок.
class ExerciseTileSurface extends StatelessWidget {
  const ExerciseTileSurface({
    required this.glyph,
    this.selected = false,
    this.accent,
    this.height = 72,
    super.key,
  });

  final String glyph;
  final bool selected;
  final Color? accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final highlight = accent ?? (selected ? UIColors.primary : null);
    final tint = highlight == UIColors.primary
        ? UIColors.primary10
        : highlight?.withValues(alpha: .12);
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      height: height,
      decoration: SquircleBorders.squircleBorder(
        color: tint == null
            ? UIColors.cardBackground
            : Color.alphaBlend(tint, UIColors.cardBackground),
        borderRadius: 18,
        borderSide: BorderSide(
          color: highlight ?? UIColors.borders,
          width: highlight == null ? 1 : 1.5,
        ),
        shadows: [
          BoxShadow(
            color: UIColors.shadows,
            offset: const Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            glyph,
            textDirection: TextDirection.rtl,
            style: UITextStyles.arabicRegular38Compact,
          ),
        ),
      ),
    );
  }
}

/// Плитки появляются по порядку только при создании нового набора.
/// Перестройка выбора меняет цвет, не перезапуская появление.
class ExerciseChoiceTile extends StatelessWidget {
  const ExerciseChoiceTile({
    required this.glyph,
    required this.index,
    required this.onTap,
    this.selected = false,
    this.accent,
    this.height = 72,
    super.key,
  });

  final String glyph;
  final int index;
  final VoidCallback? onTap;
  final bool selected;
  final Color? accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tile = IgnorePointer(
      ignoring: onTap == null,
      child: AppGestureDetector(
        pressedOpacity: .96,
        onTap: onTap,
        child: ExerciseTileSurface(
          glyph: glyph,
          selected: selected,
          accent: accent,
          height: height,
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return tile;
    return tile
        .animate(delay: Duration(milliseconds: index * 70))
        .fadeIn(duration: 280.ms, curve: Curves.easeOut)
        .slideY(
          begin: .18,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        )
        .scaleXY(
          begin: .94,
          end: 1,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
