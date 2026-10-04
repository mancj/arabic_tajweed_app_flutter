import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Сообщает высоту ребёнка после каждого layout, на котором она изменилась.
class MeasureHeight extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onChange;

  const MeasureHeight({
    required this.onChange,
    required Widget child,
    super.key,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderObject renderObject,
  ) {
    (renderObject as _RenderMeasureHeight).onChange = onChange;
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
    // Высота меняет состояние родителя, поэтому сообщаем её после кадра.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onChange(size.height);
    });
  }
}
