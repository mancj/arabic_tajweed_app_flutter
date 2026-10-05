import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/inner_shadow.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';

/// Кнопка перехода к следующему шагу: Liquid Glass на iOS,
/// градиент с тенями из макета на остальных платформах.
///
/// [subtitle] опционален — без него заголовок центрируется по кнопке.
class NextButton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Неактивная кнопка гасится, но остаётся на месте — иначе нижняя панель
  /// прыгает по высоте.
  final bool enabled;

  const NextButton({
    required this.title,
    this.subtitle,
    this.onTap,
    this.icon,
    this.enabled = true,
    Key? key,
  }) : super(key: key);

  static final _borderRadius = BorderRadius.circular(16);

  /// Тени под кнопкой из макета: (прозрачность, сдвиг вниз, размытие).
  static const _shadows = [
    (0.15, 3.0, 7.0),
    (0.1, 1.0, 3.0),
    (0.09, 6.0, 6.0),
    (0.05, 13.0, 8.0),
    (0.02, 24.0, 10.0),
  ];

  @override
  Widget build(BuildContext context) {
    final useLiquidGlass =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (useLiquidGlass) {
      final glassSettings = LiquidGlassSettings(
        glassColor: UIColors.glassButtonTint,
        fresnelStrength: 1,
        refractiveIndex: 0,
        blur: 8,
        frost: 8,
        chromaticAberration: .6,
        lightIntensity: .2,
        rimLight: 2,
      );
      // GlassButton сам анимирует линзу и свет при нажатии; дополнительный
      // AppGestureDetector конкурировал бы с его обработкой жестов.
      return GlassButton.custom(
        height: 56,
        // Половина высоты даёт круглые торцы и прямые верх и низ.
        shape: const LiquidRoundedRectangle(borderRadius: 52),
        quality: GlassQuality.premium,
        useOwnLayer: true,
        settings: glassSettings,
        enabled: enabled && onTap != null,
        onTap: () {
          AppHaptics.tick();
          onTap?.call();
        },
        child: _buildContent(glass: true),
      );
    }

    return AppGestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: _borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [UIColors.primary, UIColors.primaryButtonBottom],
              stops: const [0.234, 1],
            ),
            boxShadow: [
              for (final (alpha, dy, blur) in _shadows)
                BoxShadow(
                  color: UIColors.primaryButtonShadow.withValues(alpha: alpha),
                  offset: Offset(0, dy),
                  blurRadius: blur,
                ),
            ],
          ),
          child: InnerShadows(
            borderRadius: _borderRadius,
            shadows: [
              InnerShadow(
                color: UIColors.primaryButtonShadow.withValues(alpha: 0.2),
                offset: const Offset(0, -3),
                blur: 6,
              ),
              InnerShadow(
                color: UIColors.primaryButtonHighlight,
                offset: const Offset(0, -3),
                blur: 2,
              ),
            ],
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent({bool glass = false}) => Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: glass ? UIColors.text : UIColors.primaryButtonText,
            ),
            const Margin.horizontal(8),
          ],
          Flexible(
            child: Text(
              title,
              style: UITextStyles.semibold16Compact.copyWith(
                color: glass ? UIColors.text : UIColors.primaryButtonText,
              ),
            ),
          ),
        ],
      ),
      if (subtitle != null)
        Text(
          subtitle!,
          style: UITextStyles.semibold13.copyWith(
            color: glass
                ? UIColors.secondary1
                : UIColors.highlightArea.withValues(alpha: .5),
          ),
        ),
    ],
  );
}
