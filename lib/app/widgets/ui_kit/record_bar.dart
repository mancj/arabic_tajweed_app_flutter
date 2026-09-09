import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/ui_kit/circle_button.dart';
import 'package:flutter/cupertino.dart';

/// Нижняя панель записи голоса: кнопка, которую держат, пока говорят.
/// Отпустили — запись ушла. Пока идёт проверка, кнопка не отвечает.
/// Состояние приходит снаружи: панель ничего не знает о сервере.
class RecordBar extends StatelessWidget {
  final bool recording;
  final bool checking;

  /// Что написано над кнопкой в покое: «Удерживайте и назовите букву».
  final String idleHint;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  /// Слот под кнопкой — например «Пропустить задание», когда сервера нет.
  final Widget? footer;

  const RecordBar({
    required this.recording,
    required this.checking,
    required this.idleHint,
    this.onPressStart,
    this.onPressEnd,
    this.footer,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = switch ((recording, checking)) {
      (true, _) => 'Слушаю… отпустите, когда назовёте',
      (_, true) => 'Проверяю…',
      _ => idleHint,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(status, style: UITextStyles.hint, textAlign: TextAlign.center),
        const Margin.vertical(12),
        AnimatedScale(
          scale: recording ? 1.15 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: CircleButton(
            size: 72,
            onPressStart: checking ? null : onPressStart,
            onPressEnd: onPressEnd,
            child: Icon(
              checking ? CupertinoIcons.hourglass : CupertinoIcons.mic_fill,
              size: 30,
              color: UIColors.white,
            ),
          ),
        ),
        if (footer case final footer?) ...[const Margin.vertical(8), footer],
      ],
    );
  }
}
