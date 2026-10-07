import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'app_haptics.dart';

class AppGestureDetector extends StatefulWidget {
  /// Временное сравнение веб-производительности: меняется только рисунок
  /// нажатия, обработчики касания и удержания остаются прежними.
  static bool animatePress = true;

  final GestureTapCallback? onTap;

  /// Палец лёг и палец поднялся — для кнопок «удерживайте»: запись голоса
  /// идёт, пока кнопка нажата. Конец приходит сразу, без задержки на
  /// анимацию нажатия, и ровно один раз на каждое начало.
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final Widget child;
  final double pressedOpacity;
  final bool hapticOnTap;

  static const _minPressedDuration = Duration(milliseconds: 100);

  const AppGestureDetector({
    Key? key,
    this.onTap,
    this.onPressStart,
    this.onPressEnd,
    required this.child,
    this.pressedOpacity = .98,
    this.hapticOnTap = true,
  }) : super(key: key);

  @override
  State<AppGestureDetector> createState() => _AppGestureDetectorState();
}

class _AppGestureDetectorState extends State<AppGestureDetector> {
  bool _isPressed = false;
  bool _holding = false;
  DateTime? _pressedAt;

  @override
  Widget build(BuildContext context) {
    // Listener даёт мгновенный отклик, не перехватывая прокрутку, как onPanDown.
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kPrimaryButton) _tapDownState();
      },
      // При быстром начале прокрутки onTapCancel может ещё не прийти.
      onPointerUp: (_) => _tapUpState(),
      onPointerCancel: (_) => _tapUpState(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.hapticOnTap) AppHaptics.tick();
          widget.onTap?.call();
        },
        onTapDown: (d) => _tapDownState(),
        onTapUp: (d) => _tapUpState(),
        onTapCancel: () => _tapUpState(),
        child: !AppGestureDetector.animatePress
            ? widget.child
            : AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: !_isPressed ? 1.0 : widget.pressedOpacity,
                curve: Curves.easeInOut,
                child: widget.child,
              ),
      ),
    );
  }

  void _tapDownState() {
    if (!_isPressed) {
      // call vibration here if you want haptic feedback
      setState(() {
        _isPressed = true;
        _pressedAt = DateTime.now();
      });
      _holding = true;
      widget.onPressStart?.call();
    }
  }

  void _tapUpState() {
    if (!_isPressed) return;
    if (_holding) {
      _holding = false;
      widget.onPressEnd?.call();
    }

    final held = DateTime.now().difference(_pressedAt ?? DateTime.now());
    final remaining = AppGestureDetector._minPressedDuration - held;
    if (remaining > Duration.zero) {
      Future.delayed(remaining, _release);
    } else {
      _release();
    }
  }

  void _release() {
    if (!mounted || !_isPressed) return;
    setState(() {
      _isPressed = false;
      _pressedAt = null;
    });
  }
}
