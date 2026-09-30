import 'package:flutter/material.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/mono_text_button.dart';
import '../../widgets/ui_kit/orbital_rings_widget.dart';
import '../../widgets/ui_kit/rule_card.dart';

class OrbitalRingsDebugPage extends StatefulWidget {
  static const routeName = '/debug/orbital-rings';

  const OrbitalRingsDebugPage({super.key});

  @override
  State<OrbitalRingsDebugPage> createState() => _OrbitalRingsDebugPageState();
}

class _OrbitalRingsDebugPageState extends State<OrbitalRingsDebugPage> {
  bool _playing = true;
  bool _loaded = false;
  int _restart = 0;
  Color _color = UIColors.white;
  double _ringThickness = 1;
  double _dashThickness = 1;
  final _hexController = TextEditingController(text: '#FFFFFF');
  String? _colorError;

  void _selectColor(Color color) {
    setState(() {
      _color = color;
      _colorError = null;
      _hexController.text =
          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    });
  }

  void _applyHexColor() {
    final hex = _hexController.text.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      setState(() => _colorError = 'Введите 6 символов, например #FF8844');
      return;
    }
    _selectColor(Color(0xFF000000 | int.parse(hex, radix: 16)));
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AppScaffold(
      title: 'Орбитальные кольца',
      builder: (context, insets) => SingleChildScrollView(
        padding: insets,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: OrbitalRingsWidget(
                    key: ValueKey(_restart),
                    color: _color,
                    ringThickness: _ringThickness,
                    dashThickness: _dashThickness,
                    playing: _playing,
                    onLoaded: () {
                      if (mounted) setState(() => _loaded = true);
                    },
                  ),
                ),
                const Margin.vertical(8),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  children: [
                    MonoTextButton(
                      title: _playing ? 'Пауза' : 'Продолжить',
                      icon: _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: _loaded && !reduceMotion
                          ? () => setState(() => _playing = !_playing)
                          : null,
                    ),
                    MonoTextButton(
                      title: 'Сначала',
                      icon: Icons.restart_alt_rounded,
                      onPressed: _loaded
                          ? () => setState(() {
                              _restart++;
                              _playing = true;
                              _loaded = false;
                            })
                          : null,
                    ),
                  ],
                ),
                if (reduceMotion) ...[
                  const Margin.vertical(8),
                  Text(
                    'Анимации отключены в настройках устройства.',
                    textAlign: TextAlign.center,
                    style: UITextStyles.regular15,
                  ),
                ],
                const Margin.vertical(16),
                RuleCard(
                  title: 'Настройки анимации',
                  contentPadding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Толщина колец',
                              style: UITextStyles.medium15,
                            ),
                          ),
                          Text(
                            _ringThickness.toStringAsFixed(1),
                            style: UITextStyles.monoRegular14,
                          ),
                        ],
                      ),
                      Semantics(
                        label: 'Толщина колец',
                        child: Slider(
                          value: _ringThickness,
                          min: 1,
                          max: 3,
                          divisions: 20,
                          activeColor: UIColors.primary,
                          inactiveColor: UIColors.primary20,
                          semanticFormatterCallback: (value) =>
                              value.toStringAsFixed(1),
                          onChanged: (value) =>
                              setState(() => _ringThickness = value),
                        ),
                      ),
                      const Margin.vertical(8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Толщина штрихов',
                              style: UITextStyles.medium15,
                            ),
                          ),
                          Text(
                            _dashThickness.toStringAsFixed(1),
                            style: UITextStyles.monoRegular14,
                          ),
                        ],
                      ),
                      Semantics(
                        label: 'Толщина штрихов',
                        child: Slider(
                          value: _dashThickness,
                          min: 1,
                          max: 3,
                          divisions: 20,
                          activeColor: UIColors.primary,
                          inactiveColor: UIColors.primary20,
                          semanticFormatterCallback: (value) =>
                              value.toStringAsFixed(1),
                          onChanged: (value) =>
                              setState(() => _dashThickness = value),
                        ),
                      ),
                      const Margin.vertical(16),
                      Text('Цвет', style: UITextStyles.medium15),
                      const Margin.vertical(12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final (name, color) in <(String, Color)>[
                            ('Белый', UIColors.white),
                            ('Оранжевый', UIColors.primary),
                            ('Голубой', const Color(0xFF60CCFF)),
                            ('Зелёный', UIColors.success),
                            ('Розовый', const Color(0xFFFF77B8)),
                            ('Фиолетовый', const Color(0xFFB898FF)),
                          ])
                            Semantics(
                              label: name,
                              button: true,
                              selected: _color == color,
                              child: InkWell(
                                onTap: () => _selectColor(color),
                                borderRadius: BorderRadius.circular(24),
                                child: SizedBox.square(
                                  dimension: 48,
                                  child: Center(
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _color == color
                                              ? UIColors.text
                                              : UIColors.secondary1,
                                          width: _color == color ? 2 : 1,
                                        ),
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Margin.vertical(16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _hexController,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              style: UITextStyles.monoRegular14,
                              decoration: InputDecoration(
                                labelText: 'HEX-код',
                                hintText: '#FFFFFF',
                                errorText: _colorError,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                if (_colorError != null) {
                                  setState(() => _colorError = null);
                                }
                              },
                              onSubmitted: (_) => _applyHexColor(),
                            ),
                          ),
                          const Margin.horizontal(12),
                          MonoTextButton(
                            title: 'Применить',
                            onPressed: _applyHexColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
