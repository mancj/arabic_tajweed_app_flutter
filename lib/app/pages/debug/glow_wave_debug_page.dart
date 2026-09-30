import 'package:flutter/material.dart';

import '../../resources/ui_resources.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/margin.dart';
import '../../widgets/ui_kit/glow_wave_widget.dart';
import '../../widgets/ui_kit/mono_text_button.dart';
import '../../widgets/ui_kit/rule_card.dart';
import '../../widgets/ui_kit/segmented_tabs.dart';

class GlowWaveDebugPage extends StatefulWidget {
  static const routeName = '/debug/glow-wave';

  const GlowWaveDebugPage({super.key});

  @override
  State<GlowWaveDebugPage> createState() => _GlowWaveDebugPageState();
}

class _GlowWaveDebugPageState extends State<GlowWaveDebugPage> {
  double _speed = 1;
  double _amplitude = 16;
  double _glowIntensity = 1;
  double _glowSpread = 1;
  double _lineWidth = .6;
  int _pairCount = 11;
  bool _playing = true;
  int _colorIndex = 0;
  int _restart = 0;

  void _reset() => setState(() {
    _speed = 1;
    _amplitude = 16;
    _glowIntensity = 1;
    _glowSpread = 1;
    _lineWidth = .6;
    _pairCount = 11;
    _playing = true;
    _colorIndex = 0;
    _restart++;
  });

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Волна',
    builder: (context, insets) => SingleChildScrollView(
      padding: insets,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: UIColors.cardBackground,
                  child: SizedBox(
                    height: 240,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Center(
                        child: GlowWaveWidget(
                          key: ValueKey(_restart),
                          height: 128,
                          pairCount: _pairCount,
                          amplitude: _amplitude,
                          glowIntensity: _glowIntensity,
                          glowSpread: _glowSpread,
                          lineWidth: _lineWidth,
                          period: Duration(
                            microseconds: (1750000 / _speed).round(),
                          ),
                          color: _colorIndex == 0
                              ? UIColors.text
                              : UIColors.primary,
                          playing: _playing,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Margin.vertical(8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  MonoTextButton(
                    title: _playing ? 'Пауза' : 'Продолжить',
                    icon: _playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onPressed: () => setState(() => _playing = !_playing),
                  ),
                  MonoTextButton(
                    title: 'Сбросить',
                    icon: Icons.restart_alt_rounded,
                    onPressed: _reset,
                  ),
                ],
              ),
              const Margin.vertical(24),
              RuleCard(
                title: 'Настройки',
                contentPadding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WaveSlider(
                      title: 'Сила ореола',
                      label: '${(_glowIntensity * 100).round()}%',
                      value: _glowIntensity,
                      min: 0,
                      max: 2,
                      divisions: 20,
                      onChanged: (value) =>
                          setState(() => _glowIntensity = value),
                    ),
                    const Margin.vertical(16),
                    _WaveSlider(
                      title: 'Размер ореола',
                      label: '${(_glowSpread * 100).round()}%',
                      value: _glowSpread,
                      min: .5,
                      max: 2,
                      divisions: 15,
                      onChanged: (value) => setState(() => _glowSpread = value),
                    ),
                    const Margin.vertical(16),
                    _WaveSlider(
                      title: 'Толщина линий',
                      label: '${_lineWidth.toStringAsFixed(1)} px',
                      value: _lineWidth,
                      min: 0,
                      max: 3,
                      divisions: 30,
                      onChanged: (value) => setState(() => _lineWidth = value),
                    ),
                    const Margin.vertical(16),
                    _WaveSlider(
                      title: 'Скорость',
                      label: '${_speed.toStringAsFixed(2)}×',
                      value: _speed,
                      min: .25,
                      max: 2,
                      divisions: 7,
                      onChanged: (value) => setState(() => _speed = value),
                    ),
                    const Margin.vertical(16),
                    _WaveSlider(
                      title: 'Высота волны',
                      label: '${(_amplitude * 2).round()}',
                      value: _amplitude,
                      min: 8,
                      max: 48,
                      divisions: 20,
                      onChanged: (value) => setState(() => _amplitude = value),
                    ),
                    const Margin.vertical(16),
                    _WaveSlider(
                      title: 'Количество пар',
                      label: '$_pairCount',
                      value: _pairCount.toDouble(),
                      min: 5,
                      max: 21,
                      divisions: 16,
                      onChanged: (value) =>
                          setState(() => _pairCount = value.round()),
                    ),
                    const Margin.vertical(16),
                    Text('Цвет', style: UITextStyles.medium15),
                    const Margin.vertical(12),
                    SegmentedTabs(
                      labels: const ['Белый', 'Акцентный'],
                      selected: _colorIndex,
                      onChanged: (value) => setState(() => _colorIndex = value),
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

class _WaveSlider extends StatelessWidget {
  const _WaveSlider({
    required this.title,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(title, style: UITextStyles.medium15)),
          Text(label, style: UITextStyles.monoRegular14),
        ],
      ),
      Semantics(
        label: title,
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: UIColors.primary,
          inactiveColor: UIColors.primary20,
          semanticFormatterCallback: (_) => label,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}
