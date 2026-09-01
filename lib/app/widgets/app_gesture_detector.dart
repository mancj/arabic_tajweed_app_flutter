import 'package:flutter/cupertino.dart';

class AppGestureDetector extends StatefulWidget {
  final GestureTapCallback? onTap;
  final Widget child;
  final double pressedOpacity;

  const AppGestureDetector({
    Key? key,
    this.onTap,
    required this.child,
    this.pressedOpacity = .95,
  }) : super(key: key);

  @override
  State<AppGestureDetector> createState() => _AppGestureDetectorState();
}

class _AppGestureDetectorState extends State<AppGestureDetector> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onPanDown: (d) => _tapDownState(),
      onTapDown: (d) => _tapDownState(),
      onTapUp: (d) => _tapUpState(),
      onTapCancel: () => _tapUpState(),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: !_isPressed ? 1.0 : widget.pressedOpacity,
        child: widget.child,
      
        curve: Curves.easeInOut,
      ),
    );
  }

  void _tapDownState() {
    if (!_isPressed) {
      // call vibration here if you want haptic feedback
      setState(() {
        _isPressed = true;
      });
    }
  }

  void _tapUpState() {
    if (_isPressed) {
      setState(() {
        _isPressed = false;
      });
    }
  }
}
