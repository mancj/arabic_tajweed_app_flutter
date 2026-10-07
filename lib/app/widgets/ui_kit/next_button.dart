import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
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
  final Widget? leading;
  final double height;
  final bool useGlass;

  /// Нейтральная прозрачная основа вместо градиента вне iOS.
  final bool neutralBackground;

  /// Выделенное оттенком стекло для основного действия на iOS.
  final bool glassProminent;

  /// Неактивная кнопка гасится, но остаётся на месте — иначе нижняя панель
  /// прыгает по высоте.
  final bool enabled;

  const NextButton({
    required this.title,
    this.subtitle,
    this.onTap,
    this.icon,
    this.leading,
    this.height = 56,
    this.useGlass = true,
    this.neutralBackground = false,
    this.glassProminent = false,
    this.enabled = true,
    Key? key,
  }) : super(key: key);

  static final _borderRadius = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final useLiquidGlass =
        useGlass && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
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
      final reduceMotion =
          (glassProminent || neutralBackground) &&
          GlassAccessibilityData.of(context).reduceMotion;
      // GlassButton сам анимирует линзу и свет при нажатии; дополнительный
      // AppGestureDetector конкурировал бы с его обработкой жестов.
      return GlassButton.custom(
        height: height,
        // Половина высоты даёт круглые торцы и прямые верх и низ.
        shape: const LiquidRoundedRectangle(borderRadius: 52),
        quality: GlassQuality.premium,
        useOwnLayer: true,
        style: glassProminent
            ? GlassButtonStyle.prominent
            : GlassButtonStyle.filled,
        settings: glassProminent
            ? glassSettings.copyWith(
                glassColor: UIColors.primary,
                // Точное смешивание оттенка; blur и frost сохраняют матовое стекло.
                bodyMode: GlassBodyMode.clear,
                saturation: 1,
                thickness: 12,
                refractiveIndex: 1.12,
                chromaticAberration: .02,
                rimLight: 1.2,
              )
            : glassSettings,
        interactionScale: reduceMotion ? 1 : null,
        stretch: reduceMotion ? 0 : .5,
        glowRadius: reduceMotion ? 0 : null,
        ambientBaseLight: reduceMotion ? 0 : null,
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
      pressedOpacity:
          neutralBackground && MediaQuery.disableAnimationsOf(context)
          ? 1
          : .98,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: neutralBackground ? UIColors.glassButtonTint : null,
            borderRadius: neutralBackground
                ? BorderRadius.circular(height / 2)
                : _borderRadius,
            border: neutralBackground
                ? Border.all(color: UIColors.text.withValues(alpha: .12))
                : null,
            gradient: neutralBackground
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [UIColors.primary, UIColors.primaryButtonBottom],
                    stops: const [0.25, 1],
                  ),
            boxShadow: neutralBackground
                ? null
                : [
                    BoxShadow(
                      color: UIColors.primaryButtonShadow.withValues(alpha: .3),
                      offset: const Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: _buildContent(glass: neutralBackground),
        ),
      ),
    );
  }

  Widget _buildContent({bool glass = false}) => Padding(
    padding: EdgeInsets.symmetric(horizontal: leading == null ? 0 : 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const Margin.horizontal(8),
            ] else if (icon != null) ...[
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
    ),
  );
}
