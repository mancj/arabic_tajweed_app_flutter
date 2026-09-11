import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';

/// Строит содержимое экрана [AppScaffold].
///
/// [contentInsets] — поля, которые содержимое обязано учесть: боковые
/// [AppScaffold.contentPadding] плюс место, занятое плавающей шапкой и нижней
/// панелью. Скроллящееся содержимое кладёт их в `padding` вьюпорта — тогда
/// контент проезжает под стеклом, а не обрывается на его границе;
/// нескроллящееся оборачивает себя в [Padding] с теми же полями.
typedef AppScaffoldContentBuilder =
    Widget Function(BuildContext context, EdgeInsets contentInsets);

/// Каркас экрана приложения: фоновый паттерн, плавающая шапка со стеклянной
/// кнопкой «назад» и опциональная закреплённая снизу панель.
///
/// Содержимое занимает всю высоту — и под шапкой, и под нижней панелью, чтобы
/// стекло преломляло живой контент, а не пустой фон. Каркас лишь считает поля
/// под своим хромом и отдаёт их в [builder]: скроллить содержимое или нет,
/// решает страница.
///
/// ```dart
/// AppScaffold(
///   title: 'Алфавит',
///   bottomBar: _NextButton(...),
///   builder: (context, insets) => SingleChildScrollView(
///     padding: insets,
///     child: Column(children: [...]),
///   ),
/// )
/// ```
class AppScaffold extends StatefulWidget {
  /// Строит содержимое по полям, занятым шапкой и нижней панелью.
  final AppScaffoldContentBuilder builder;

  /// Заголовок по центру шапки. Без него шапка остаётся только под кнопку.
  final String? title;

  /// Панель, закреплённая у нижнего края поверх скролла.
  final Widget? bottomBar;

  /// Обработчик кнопки «назад». По умолчанию — [Get.back].
  final VoidCallback? onBack;

  /// Показывать ли кнопку «назад» (на корневых экранах она не нужна).
  final bool showBackButton;

  /// Показывать бренд вместо заголовка экрана.
  final bool showBrand;

  final Color? backgroundColor;

  /// Боковые поля содержимого; вертикальные отступы прибавляются к ним.
  final EdgeInsets contentPadding;

  /// Сила прогрессивного размытия контента под шапкой и панелью.
  final double edgeBlurSigma;

  const AppScaffold({
    required this.builder,
    this.title,
    this.bottomBar,
    this.onBack,
    this.showBackButton = true,
    this.showBrand = false,
    this.backgroundColor,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.edgeBlurSigma = 4,
    Key? key,
  }) : super(key: key);

  /// Высота шапки и отступы вокруг неё.
  static const _headerHeight = 46.0;
  static const _headerTopGap = 16.0;
  static const _headerBottomGap = 0.0;

  /// Отступ нижней панели от края экрана.
  static const _bottomBarGap = 16.0;

  /// Отступ содержимого от шапки и от нижней панели.
  static const _contentGap = 16.0;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  /// Высота [AppScaffold.bottomBar] замеряется, а не задаётся константой:
  /// панели у разных экранов разной высоты, и захардкоженное значение
  /// разъезжается с реальным, оставляя контент под панелью недоступным.
  double _bottomBarHeight = 0;

  @override
  Widget build(BuildContext context) {
    // UIColors and UITextStyles follow the system brightness. This dependency
    // makes the whole screen rebuild when the device theme changes.
    MediaQuery.platformBrightnessOf(context);
    final insets = MediaQuery.paddingOf(context);

    final headerZone =
        insets.top +
        AppScaffold._headerTopGap +
        AppScaffold._headerHeight +
        AppScaffold._headerBottomGap;
    final bottomZone = widget.bottomBar == null
        ? insets.bottom
        : insets.bottom + AppScaffold._bottomBarGap + _bottomBarHeight;

    // Хром плавает поверх содержимого, поэтому занятое им место содержимое
    // обязано отступить само — иначе контент прячется под шапкой и панелью,
    // а у скролла вьюпорт во весь экран, и короткая страница не скроллится.
    final contentInsets = EdgeInsets.only(
      left: widget.contentPadding.left,
      right: widget.contentPadding.right,
      top: widget.contentPadding.top + headerZone + AppScaffold._contentGap,
      bottom:
          widget.contentPadding.bottom + bottomZone + AppScaffold._contentGap,
    );

    return Scaffold(
      backgroundColor: widget.backgroundColor ?? UIColors.pageBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Positioned.fill(
          //   child: Image.asset(
          //     'assets/img/background_grid_pattern.png',
          //     fit: BoxFit.cover,
          //   ),
          // ),
          Positioned.fill(
            child: Builder(
              builder: (context) => widget.builder(context, contentInsets),
            ),
          ),
          Positioned(
            top: insets.top + AppScaffold._headerTopGap,
            left: 0,
            right: 0,
            child: _Header(
              title: widget.title,
              showBrand: widget.showBrand,
              onBack: widget.showBackButton
                  ? (widget.onBack ?? Get.back)
                  : null,
            ),
          ),
          if (widget.bottomBar != null)
            Positioned(
              left: widget.contentPadding.left,
              right: widget.contentPadding.right,
              bottom: insets.bottom + AppScaffold._bottomBarGap,
              child: _MeasureHeight(
                onChange: (height) => setState(() => _bottomBarHeight = height),
                child: widget.bottomBar!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Шапка: заголовок по центру или бренд слева.
class _Header extends StatelessWidget {
  final String? title;
  final bool showBrand;
  final VoidCallback? onBack;

  const _Header({this.title, this.showBrand = false, this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppScaffold._headerHeight,
      child: Stack(
        children: [
          if (showBrand)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'tajweed',
                        style: TextStyle(
                          fontFamily: UITextStyles.fontOnest,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                          color: UIColors.text,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: UIColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (title != null && !showBrand)
            Center(
              child: Text(
                title!,
                style: TextStyle(
                  fontFamily: UITextStyles.fontOnest,
                  fontWeight: FontWeight.w500,
                  fontSize: 22,
                  color: UIColors.text,
                  shadows: [
                    Shadow(
                      color: UIColors.shadows,
                      offset: Offset(0, 4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GlassIconButton(
                  icon: Icon(CupertinoIcons.back, color: UIColors.text),
                  onPressed: onBack,
                  size: AppScaffold._headerHeight,
                  iconSize: 24,
                  semanticLabel: 'Назад',
                  // Линзу рисует только premium: standard — плоское матовое
                  // стекло без преломления. Вне общего слоя premium обязан
                  // рендерить собственный, иначе ассерт в debug.
                  quality: GlassQuality.premium,
                  useOwnLayer: true,
                  settings: const LiquidGlassSettings(
                    // Чем толще стекло, тем сильнее гнёт картинку под собой.
                    thickness: 24,
                    // Блюр матирует фон и съедает искажение — держим минимальным.
                    blur: 1,
                    refractiveIndex: 1.45,
                    chromaticAberration: .04,
                    lightIntensity: .8,
                    // Осветляющая вуаль iOS 26 для читаемости на светлом фоне;
                    // выше .2 стекло мутнеет и линза пропадает.
                    whitenStrength: .15,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Сообщает высоту ребёнка после каждого layout, на котором она изменилась.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onChange;

  const _MeasureHeight({required this.onChange, required Widget child})
    : super(child: child);

  @override
  _RenderMeasureHeight createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  ValueChanged<double> onChange;
  double? _reported;

  _RenderMeasureHeight(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size.height) return;
    _reported = size.height;
    // Колбэк меняет состояние родителя, поэтому вызывается после кадра:
    // setState во время layout запрещён.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onChange(size.height);
    });
  }
}
