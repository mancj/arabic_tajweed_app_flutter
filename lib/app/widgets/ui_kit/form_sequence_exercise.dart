import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:arabic_tajweed_app/app/media/single_sound_effect.dart';
import 'package:arabic_tajweed_app/app/resources/ui_resources.dart';
import 'package:arabic_tajweed_app/app/widgets/app_gesture_detector.dart';
import 'package:arabic_tajweed_app/app/widgets/app_haptics.dart';
import 'package:arabic_tajweed_app/app/widgets/margin.dart';
import 'package:arabic_tajweed_app/app/widgets/squircle_borders.dart';
import 'package:arabic_tajweed_app/domain/atom.dart';
import 'package:arabic_tajweed_app/domain/haraka_syllables.dart';

import 'exercise_tile.dart';

/// Один слот раскладки: подпись не раскрывает ответ, а правильный атом
/// задаётся отдельно. У звукового слота есть запись для подсказки.
@immutable
class SequenceSlot {
  const SequenceSlot({
    required this.id,
    required this.title,
    required this.expectedAtomId,
    this.audioAsset,
    this.baseGlyph,
  });

  final String id;
  final String title;
  final String expectedAtomId;
  final String? audioAsset;
  final String? baseGlyph;

  String? glyphFor(Atom? answer) => baseGlyph == null
      ? answer?.display
      : answer == null
      ? baseGlyph
      : HarakaSyllables.applyMark(baseGlyph!, answer);
}

/// Временная шкала перелёта. Границы этапов задаются долями от 0 до 1.
@immutable
class FormSequenceMotion {
  const FormSequenceMotion({
    this.duration = const Duration(milliseconds: 500),
    this.movementStart = 0,
    this.movementEnd = .5,
    this.fadeInStart = 0,
    this.fadeInEnd = .1,
    this.morphStart = .05,
    this.morphEnd = .15,
    this.fadeOutStart = .97,
    this.fadeOutEnd = 1,
    this.pulseStart = .3,
    this.pulseEnd = 1,
    this.interactionLockEnd = .5,
  }) : assert(movementStart >= 0 && movementStart <= movementEnd),
       assert(movementEnd <= 1),
       assert(fadeInStart >= 0 && fadeInStart <= fadeInEnd),
       assert(fadeInEnd <= 1),
       assert(morphStart >= 0 && morphStart <= morphEnd),
       assert(morphEnd <= 1),
       assert(fadeOutStart >= 0 && fadeOutStart <= fadeOutEnd),
       assert(fadeOutEnd <= 1),
       assert(pulseStart >= 0 && pulseStart <= pulseEnd),
       assert(pulseEnd <= 1),
       assert(interactionLockEnd >= 0 && interactionLockEnd <= 1);

  final Duration duration;
  final double movementStart;
  final double movementEnd;
  final double fadeInStart;
  final double fadeInEnd;
  final double morphStart;
  final double morphEnd;
  final double fadeOutStart;
  final double fadeOutEnd;
  final double pulseStart;
  final double pulseEnd;

  /// Доля общей длительности, после которой снова разрешаются тапы.
  final double interactionLockEnd;

  Duration timeAt(double progress) => duration * progress;

  Duration durationBetween(double start, double end) =>
      duration * (end - start);

  Duration get interactionLockDuration => timeAt(interactionLockEnd);
}

/// Раскладывание двух или четырёх форм одной буквы по позициям.
///
/// Слоты заполняются строго по очереди. Заполненный слот можно очистить
/// тапом и вернуть его плитку. После последнего выбора порядок отправляется
/// наружу одним ответом — промежуточные тапы не проверяются.
class FormSequenceExercise extends StatefulWidget {
  const FormSequenceExercise({
    required this.options,
    required this.onCompleted,
    this.initialPlaced = const [],
    this.slotResults,
    this.revealCorrectOrder = false,
    this.motion = const FormSequenceMotion(),
    this.slots,
    this.instruction = 'Выберите форму для выделенного слота',
    this.optionNoun = 'Форма',
    this.onPlaySlot,
    this.onActiveSlotChanged,
    this.playingSlotIndex,
    this.reusableOptions = false,
    super.key,
  }) : assert(
         initialPlaced.length == 0 ||
             initialPlaced.length == (slots?.length ?? options.length),
       ),
       assert(
         slotResults == null ||
             slotResults.length == (slots?.length ?? options.length),
       );

  final List<Atom> options;
  final ValueChanged<List<Atom>> onCompleted;
  final List<Atom?> initialPlaced;
  final List<bool>? slotResults;
  final bool revealCorrectOrder;
  final FormSequenceMotion motion;
  final List<SequenceSlot>? slots;
  final String instruction;
  final String optionNoun;
  final ValueChanged<int>? onPlaySlot;
  final ValueChanged<int>? onActiveSlotChanged;
  final int? playingSlotIndex;
  final bool reusableOptions;

  @override
  State<FormSequenceExercise> createState() => _FormSequenceExerciseState();
}

class _FormSequenceExerciseState extends State<FormSequenceExercise>
    with TickerProviderStateMixin {
  late final List<SequenceSlot> _slots;
  late final List<Atom?> _placed;
  late final Set<int> _lockedPositions;
  final _tileAnchors = <String, GlobalKey>{};
  final _tileSnapshots = <String, ui.Image>{};
  late final List<GlobalKey> _slotAnchors;
  late final SingleSoundEffect _landingSound;
  final _flightControllers = <AnimationController>{};
  final _flightOverlays = <OverlayEntry>{};
  bool _interactionLocked = false;
  int _interactionLockRevision = 0;
  String? _landingTarget;
  int _landingRevision = 0;
  bool _completed = false;
  bool _revealingAnswer = false;
  Timer? _answerRevealTimer;

  @override
  void initState() {
    super.initState();
    _slots =
        widget.slots ??
        [
          for (final form in _positions.where(
            (form) => widget.options.any((atom) => atom.form == form),
          ))
            SequenceSlot(
              id: form.name,
              title: form.title,
              expectedAtomId: widget.options
                  .firstWhere((atom) => atom.form == form)
                  .id,
            ),
        ];
    _placed = widget.initialPlaced.isEmpty
        ? List.filled(_slots.length, null)
        : List.of(widget.initialPlaced);
    _lockedPositions = {
      for (final (index, atom) in _placed.indexed)
        if (atom != null) index,
    };
    _slotAnchors = List.generate(_slots.length, (_) => GlobalKey());
    _landingSound = SingleSoundEffect(assetPath: 'audio/crispy_click.m4a');
    unawaited(_landingSound.init());
    if (widget.revealCorrectOrder) _startAnswerReveal();
    if (!widget.revealCorrectOrder) _notifyActiveSlot();
  }

  void _notifyActiveSlot() {
    final active = _placed.indexWhere((atom) => atom == null);
    if (active < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_revealingAnswer &&
          _placed.indexWhere((atom) => atom == null) == active) {
        widget.onActiveSlotChanged?.call(active);
      }
    });
  }

  void _startAnswerReveal() {
    _revealingAnswer = true;
    _lockedPositions.clear();
    for (final (index, slot) in _slots.indexed) {
      _placed[index] = widget.options.firstWhere(
        (atom) => atom.id == slot.expectedAtomId,
      );
    }
    _answerRevealTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _placed.fillRange(0, _placed.length, null);
        _revealingAnswer = false;
      });
      _notifyActiveSlot();
    });
  }

  Future<void> _place(Atom atom) async {
    if (_completed ||
        _revealingAnswer ||
        _interactionLocked ||
        (!widget.reusableOptions && _placed.contains(atom))) {
      return;
    }
    final activeIndex = _placed.indexWhere((placed) => placed == null);
    if (activeIndex == -1) return;

    _lockInteractions();
    final tileAnchor = _tileAnchors[atom.id];
    final snapshot = tileAnchor == null
        ? null
        : await _snapshotOf(atom.id, tileAnchor);
    if (!mounted) return;
    final flight = tileAnchor == null
        ? null
        : _flightBetween(from: tileAnchor, to: _slotAnchors[activeIndex]);
    Future<void>? landingPulse;
    void startLandingPulse() {
      landingPulse ??= _startLandingPulse('slot-$activeIndex');
    }

    var completedWithThisPlacement = false;
    setState(() {
      _placed[activeIndex] = atom;
      completedWithThisPlacement = _placed.every((placed) => placed != null);
      _completed = completedWithThisPlacement;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final slotSnapshot = await _capture(_slotAnchors[activeIndex]);
    if (!mounted) {
      slotSnapshot?.dispose();
      return;
    }
    if (flight != null) {
      try {
        final flightFuture = _fly(
          atom,
          flight.$1,
          flight.$2,
          source: _flightTile(atom, snapshot),
          target: slotSnapshot == null
              ? _FormSlotSurface(
                  slot: _slots[activeIndex],
                  atom: atom,
                  active: false,
                )
              : _flightImage(slotSnapshot),
          onLanding: startLandingPulse,
        );
        _scheduleInteractionUnlock();
        await flightFuture;
      } finally {
        slotSnapshot?.dispose();
      }
    } else {
      slotSnapshot?.dispose();
      _unlockInteractions();
    }
    if (!mounted) return;

    startLandingPulse();
    if (completedWithThisPlacement) {
      await landingPulse!;
      if (!mounted) return;
      widget.onCompleted(List.unmodifiable(_placed.whereType<Atom>()));
    } else {
      _notifyActiveSlot();
    }
  }

  Future<void> _remove(int index) async {
    final atom = _placed[index];
    if (_completed ||
        _revealingAnswer ||
        _interactionLocked ||
        _lockedPositions.contains(index) ||
        atom == null) {
      return;
    }

    _lockInteractions();
    final tileAnchor = _tileAnchors[atom.id];
    final snapshot = _tileSnapshots[atom.id];
    final slotSnapshot = await _capture(_slotAnchors[index]);
    if (!mounted) {
      slotSnapshot?.dispose();
      return;
    }
    final flight = tileAnchor == null
        ? null
        : _flightBetween(from: _slotAnchors[index], to: tileAnchor);
    Future<void>? landingPulse;
    void startLandingPulse() {
      landingPulse ??= _startLandingPulse('tile-${atom.id}');
    }

    setState(() => _placed[index] = null);
    if (flight != null) {
      try {
        final flightFuture = _fly(
          atom,
          flight.$1,
          flight.$2,
          source: slotSnapshot == null
              ? _FormSlotSurface(slot: _slots[index], atom: atom, active: false)
              : _flightImage(slotSnapshot),
          target: _flightTile(atom, snapshot),
          onLanding: startLandingPulse,
        );
        _scheduleInteractionUnlock();
        await flightFuture;
      } finally {
        slotSnapshot?.dispose();
      }
    } else {
      slotSnapshot?.dispose();
      _unlockInteractions();
    }
    if (!mounted) return;

    startLandingPulse();
    _notifyActiveSlot();
  }

  void _lockInteractions() {
    _interactionLocked = true;
    _interactionLockRevision++;
  }

  void _scheduleInteractionUnlock() {
    final revision = _interactionLockRevision;
    Future<void>.delayed(widget.motion.interactionLockDuration, () {
      if (mounted && revision == _interactionLockRevision) {
        _interactionLocked = false;
      }
    });
  }

  void _unlockInteractions() {
    _interactionLockRevision++;
    _interactionLocked = false;
  }

  Future<void> _startLandingPulse(String target) {
    if (!mounted) return Future.value();
    AppHaptics.tick();
    unawaited(_landingSound.play());
    setState(() {
      _landingTarget = target;
      _landingRevision++;
    });
    return Future<void>.delayed(
      widget.motion.durationBetween(
        widget.motion.pulseStart,
        widget.motion.pulseEnd,
      ),
    );
  }

  (Rect, Rect)? _flightBetween({
    required GlobalKey from,
    required GlobalKey to,
  }) {
    final overlayBox = Overlay.of(context).context.findRenderObject();
    final fromBox = from.currentContext?.findRenderObject();
    final toBox = to.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox ||
        fromBox is! RenderBox ||
        toBox is! RenderBox) {
      return null;
    }

    Rect boundsOf(RenderBox box) {
      final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
      return origin & box.size;
    }

    return (boundsOf(fromBox), boundsOf(toBox));
  }

  Widget _flightTile(Atom atom, ui.Image? snapshot) => snapshot == null
      ? ExerciseTileSurface(glyph: atom.display)
      : _flightImage(snapshot);

  Widget _flightImage(ui.Image image) => RawImage(
    image: image,
    fit: BoxFit.fill,
    filterQuality: FilterQuality.medium,
  );

  Widget _withLandingPulse({required String target, required Widget child}) {
    if (_landingTarget != target) return child;

    return KeyedSubtree(
      key: ValueKey('form-landing-pulse-$target'),
      child: child
          .animate(key: ValueKey('form-landing-$target-$_landingRevision'))
          .custom(
            duration: widget.motion.durationBetween(
              widget.motion.pulseStart,
              widget.motion.pulseEnd,
            ),
            builder: _buildLandingPulse,
          ),
    );
  }

  Widget _buildLandingPulse(
    BuildContext context,
    double progress,
    Widget child,
  ) {
    const peak = .055;
    const growPart = .38;
    final shrinking = progress > growPart;
    final phase = shrinking
        ? (progress - growPart) / (1 - growPart)
        : progress / growPart;
    final eased = Curves.easeOutCubic.transform(phase);
    final scale = shrinking ? 1 + peak * (1 - eased) : 1 + peak * eased;
    return Transform.scale(scale: scale, child: child);
  }

  Future<ui.Image?> _snapshotOf(String id, GlobalKey tileAnchor) async {
    final cached = _tileSnapshots[id];
    if (cached != null) return cached;

    final image = await _capture(tileAnchor);
    if (image == null) return null;
    if (!mounted) {
      image.dispose();
      return null;
    }
    _tileSnapshots[id] = image;
    return image;
  }

  Future<ui.Image?> _capture(GlobalKey anchor) async {
    final boundary = anchor.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    try {
      return await boundary.toImage(
        pixelRatio: View.of(context).devicePixelRatio,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fly(
    Atom atom,
    Rect from,
    Rect to, {
    required Widget source,
    required Widget target,
    required VoidCallback onLanding,
  }) async {
    final motion = widget.motion;
    final flightController = AnimationController(
      vsync: this,
      duration: motion.duration,
    );
    _flightControllers.add(flightController);
    final movement = CurvedAnimation(
      parent: flightController,
      curve: Interval(
        motion.movementStart,
        motion.movementEnd,
        curve: Curves.easeOutCubic,
      ),
    );
    final animatedSurface = IgnorePointer(
      child: KeyedSubtree(
        key: ValueKey('form-flight-${atom.id}'),
        child:
            KeyedSubtree(
                  key: ValueKey('form-flight-source-${atom.id}'),
                  child: _FlightSurface(naturalSize: from.size, child: source),
                )
                .animate(autoPlay: false, controller: flightController)
                .fadeIn(
                  delay: motion.timeAt(motion.fadeInStart),
                  duration: motion.durationBetween(
                    motion.fadeInStart,
                    motion.fadeInEnd,
                  ),
                )
                .crossfade(
                  delay: motion.timeAt(motion.morphStart),
                  duration: motion.durationBetween(
                    motion.morphStart,
                    motion.morphEnd,
                  ),
                  curve: Curves.easeInOut,
                  builder: (_) => KeyedSubtree(
                    key: ValueKey('form-flight-target-${atom.id}'),
                    child: _FlightSurface(naturalSize: to.size, child: target),
                  ),
                )
                .fadeOut(
                  delay: motion.timeAt(motion.fadeOutStart),
                  duration: motion.durationBetween(
                    motion.fadeOutStart,
                    motion.fadeOutEnd,
                  ),
                )
                .custom(
                  delay: motion.timeAt(motion.pulseStart),
                  duration: motion.durationBetween(
                    motion.pulseStart,
                    motion.pulseEnd,
                  ),
                  builder: _buildLandingPulse,
                )
                .callback(
                  delay: motion.timeAt(motion.pulseStart),
                  duration: Duration.zero,
                  callback: (_) => onLanding(),
                ),
      ),
    );
    final entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: flightController,
        child: animatedSurface,
        builder: (_, child) {
          final movementProgress = movement.value;
          return Positioned.fromRect(
            rect: Rect.lerp(from, to, movementProgress)!,
            child: child!,
          );
        },
      ),
    );
    _flightOverlays.add(entry);
    Overlay.of(context).insert(entry);
    try {
      await flightController.forward().orCancel;
    } on TickerCanceled {
      return;
    } finally {
      if (_flightOverlays.remove(entry)) {
        if (entry.mounted) entry.remove();
        entry.dispose();
      }
      if (_flightControllers.remove(flightController)) {
        flightController.dispose();
      }
    }
  }

  @override
  void dispose() {
    _answerRevealTimer?.cancel();
    for (final entry in _flightOverlays) {
      if (entry.mounted) entry.remove();
      entry.dispose();
    }
    _flightOverlays.clear();
    for (final controller in _flightControllers) {
      controller.dispose();
    }
    _flightControllers.clear();
    unawaited(_landingSound.dispose());
    for (final image in _tileSnapshots.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _placed.indexWhere((placed) => placed == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, slot) in _slots.indexed) ...[
              if (index > 0) const Margin.horizontal(8),
              Expanded(
                child: _withLandingPulse(
                  target: 'slot-$index',
                  child: _FormSlot(
                    slot: slot,
                    anchorKey: _slotAnchors[index],
                    atom: _placed[index],
                    active:
                        index == activeIndex &&
                        !_completed &&
                        !_revealingAnswer,
                    locked: _lockedPositions.contains(index),
                    result: widget.slotResults?[index],
                    revealingAnswer: _revealingAnswer,
                    playing: widget.playingSlotIndex == index,
                    onPlay: slot.audioAsset == null
                        ? null
                        : () => widget.onPlaySlot?.call(index),
                    onTap: _lockedPositions.contains(index)
                        ? null
                        : () => _remove(index),
                  ),
                ),
              ),
            ],
          ],
        ),
        const Margin.vertical(16),
        Text(
          _revealingAnswer
              ? 'Запомните правильный порядок'
              : widget.instruction,
          key: ValueKey(
            _revealingAnswer ? 'form-answer-reveal' : 'form-instruction',
          ),
          style: UITextStyles.monoRegular14.copyWith(
            color: UIColors.secondary2,
          ),
        ),
        const Margin.vertical(8),
        Row(
          children: [
            for (final (index, atom) in widget.options.indexed) ...[
              if (index > 0) const Margin.horizontal(8),
              Expanded(
                child: _withLandingPulse(
                  target: 'tile-${atom.id}',
                  child: _FormTile(
                    anchorKey: _tileAnchors.putIfAbsent(atom.id, GlobalKey.new),
                    atom: atom,
                    noun: widget.optionNoun,
                    used: !widget.reusableOptions && _placed.contains(atom),
                    onTap: () => _place(atom),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Не даёт исходному и целевому виджетам перевёрстываться на промежуточной
/// высоте полёта: каждый рисуется в родном размере и только масштабируется.
class _FlightSurface extends StatelessWidget {
  const _FlightSurface({required this.naturalSize, required this.child});

  final Size naturalSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox.fromSize(size: naturalSize, child: child),
    );
  }
}

const _positions = [
  LetterForm.isolated,
  LetterForm.initial,
  LetterForm.medial,
  LetterForm.finalForm,
];

class _FormSlot extends StatelessWidget {
  const _FormSlot({
    required this.anchorKey,
    required this.slot,
    required this.atom,
    required this.active,
    required this.locked,
    required this.result,
    required this.revealingAnswer,
    required this.playing,
    required this.onPlay,
    required this.onTap,
  });

  final GlobalKey anchorKey;
  final SequenceSlot slot;
  final Atom? atom;
  final bool active;
  final bool locked;
  final bool? result;
  final bool revealingAnswer;
  final bool playing;
  final VoidCallback? onPlay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final placedAtom = atom;
    final slot = _FormSlotSurface(
      key: ValueKey('form-slot-${this.slot.id}'),
      slot: this.slot,
      atom: placedAtom,
      active: active,
      playing: playing,
      onPlay: onPlay,
      feedback: revealingAnswer || locked
          ? _FormSlotFeedback.correct
          : switch (result) {
              true => _FormSlotFeedback.correct,
              false => _FormSlotFeedback.wrong,
              null => _FormSlotFeedback.none,
            },
    );
    return RepaintBoundary(
      key: anchorKey,
      child: Semantics(
        label: 'Слот: ${this.slot.title}',
        hint: placedAtom == null
            ? null
            : locked
            ? 'Ответ уже на правильном месте'
            : 'Нажмите, чтобы убрать ответ',
        selected: active,
        button: placedAtom != null && onTap != null,
        child: placedAtom == null || onTap == null
            ? slot
            : AppGestureDetector(onTap: onTap!, child: slot),
      ),
    );
  }
}

class _FormSlotSurface extends StatelessWidget {
  const _FormSlotSurface({
    required this.slot,
    required this.atom,
    required this.active,
    this.playing = false,
    this.onPlay,
    this.feedback = _FormSlotFeedback.none,
    super.key,
  });

  final SequenceSlot slot;
  final Atom? atom;
  final bool active;
  final bool playing;
  final VoidCallback? onPlay;
  final _FormSlotFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final feedbackColor = switch (feedback) {
      _FormSlotFeedback.correct => UIColors.success,
      _FormSlotFeedback.wrong => UIColors.error,
      _FormSlotFeedback.none => null,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: slot.audioAsset == null ? 108 : 132,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: SquircleBorders.squircleBorder(
        color:
            feedbackColor?.withValues(alpha: .12) ??
            (active ? UIColors.primary10 : UIColors.cardBackground),
        borderRadius: 18,
        borderSide: BorderSide(
          color:
              feedbackColor ?? (active ? UIColors.primary : UIColors.borders),
          width: active || feedbackColor != null ? 2 : 1,
        ),
        shadows: active
            ? [
                BoxShadow(
                  color: UIColors.primary20,
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Text(
                slot.title,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style:
                    (active ? UITextStyles.semibold12 : UITextStyles.regular12)
                        .copyWith(
                          color: active ? UIColors.text : UIColors.secondary2,
                        ),
              ),
              Expanded(
                child: Center(
                  child: slot.glyphFor(atom) == null
                      ? Text(
                          '?',
                          style: UITextStyles.semibold22.copyWith(
                            color: active
                                ? UIColors.primary
                                : UIColors.backgroundShapes2,
                          ),
                        )
                      : _Glyph(slot.glyphFor(atom)!),
                ),
              ),
              if (slot.audioAsset != null)
                AnimatedScale(
                  scale: playing ? 1.12 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: IconButton(
                    tooltip: 'Прослушать ${slot.title.toLowerCase()}',
                    onPressed: onPlay,
                    icon: Icon(
                      playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                      color: active ? UIColors.primary : UIColors.text,
                    ),
                  ),
                ),
            ],
          ),
          if (feedback != _FormSlotFeedback.none)
            Align(
              alignment: slot.audioAsset == null
                  ? Alignment.bottomCenter
                  : Alignment.bottomRight,
              child: Icon(
                feedback == _FormSlotFeedback.correct
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                key: ValueKey('form-slot-${feedback.name}-${slot.id}'),
                size: 16,
                color: feedbackColor,
              ),
            ),
        ],
      ),
    );
  }
}

enum _FormSlotFeedback { none, correct, wrong }

class _FormTile extends StatelessWidget {
  const _FormTile({
    required this.anchorKey,
    required this.atom,
    required this.noun,
    required this.used,
    required this.onTap,
  });

  final GlobalKey anchorKey;
  final Atom atom;
  final String noun;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$noun ${atom.display}',
      enabled: !used,
      child: IgnorePointer(
        ignoring: used,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: used ? 0 : 1,
          child: AppGestureDetector(
            key: ValueKey('form-tile-${atom.id}'),
            onTap: onTap,
            child: RepaintBoundary(
              key: anchorKey,
              child: ExerciseTileSurface(glyph: atom.display),
            ),
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textDirection: TextDirection.rtl,
      style: UITextStyles.arabicRegular38Compact,
    );
  }
}
