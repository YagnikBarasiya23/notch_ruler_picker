/// Notch — a scrollable ruler picker. MIT © 2026 Yagnik Barasiya.
library;

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Maps between scroll offsets and values on an evenly spaced scale.
@immutable
class RulerScale {
  const RulerScale({required this.min, required this.max, this.step = 1, this.spacing = 12})
    : assert(max > min),
      assert(step > 0),
      assert(spacing > 0);

  final double min;
  final double max;
  final double step;

  /// Pixels between neighbouring ticks.
  final double spacing;

  /// Number of ticks, including both ends.
  int get count => ((max - min) / step).round() + 1;

  /// Scroll offset that puts [value] under the centre notch.
  double offsetFor(double value) => indexFor(value) * spacing;

  /// Tick index nearest to [value], clamped to the scale.
  int indexFor(double value) => ((value.clamp(min, max) - min) / step).round();

  /// Value of tick [index]. Rounded to the step's decimals to avoid 0.30000000000000004.
  double valueAt(int index) {
    final raw = min + index.clamp(0, count - 1) * step;
    final decimals = _decimals(step);
    return double.parse(raw.toStringAsFixed(decimals));
  }

  /// Value under the centre notch at scroll [offset].
  double valueAtOffset(double offset) => valueAt((offset / spacing).round());

  /// The nearest offset that lines a tick up with the notch.
  double snap(double offset) => (offset / spacing).round().clamp(0, count - 1) * spacing;

  static int _decimals(double step) {
    final text = step.toString();
    final dot = text.indexOf('.');
    if (dot < 0 || text.endsWith('.0')) return 0;
    return text.length - dot - 1;
  }
}

/// Unit helpers for the most common ruler pickers.
abstract final class RulerUnits {
  static const double _cmPerInch = 2.54;
  static const double _kgPerLb = 0.45359237;

  /// Centimetres to whole feet and inches, e.g. 170 → (5, 7).
  static (int feet, int inches) cmToFeetInches(double cm) {
    final totalInches = (cm / _cmPerInch).round();
    return (totalInches ~/ 12, totalInches % 12);
  }

  static double feetInchesToCm(int feet, int inches) => (feet * 12 + inches) * _cmPerInch;

  static double kgToLb(double kg) => kg / _kgPerLb;

  static double lbToKg(double lb) => lb * _kgPerLb;
}

/// Label shown under major ticks.
typedef RulerLabelBuilder = String Function(double value);

/// A horizontal ruler you scroll to pick a value.
///
/// ```dart
/// NotchRulerPicker(
///   value: height,
///   min: 100,
///   max: 230,
///   majorEvery: 10,
///   onChanged: (value) => setState(() => height = value),
///   semanticLabel: 'Height in centimetres',
/// )
/// ```
class NotchRulerPicker extends StatefulWidget {
  const NotchRulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.majorEvery = 10,
    this.midEvery = 5,
    this.spacing = 12,
    this.height = 96,
    this.color = const Color(0xFFF4F4F5),
    this.mutedColor = const Color(0x66F4F4F5),
    this.notchColor = const Color(0xFFD9F99D),
    this.labelStyle = const TextStyle(fontSize: 13, color: Color(0x99F4F4F5), fontFeatures: [FontFeature.tabularFigures()]),
    this.labelBuilder,
    this.haptics = true,
    this.semanticLabel,
    this.semanticValueBuilder,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// Distance between values.
  final double step;

  /// Every n-th tick is long and labelled.
  final int majorEvery;

  /// Every n-th tick is medium length. Use 0 to turn off.
  final int midEvery;

  /// Pixels between ticks.
  final double spacing;

  /// Height of the ruler.
  final double height;

  /// Colour of ticks near the notch.
  final Color color;

  /// Colour of ticks towards the edges.
  final Color mutedColor;

  /// Colour of the centre notch.
  final Color notchColor;

  final TextStyle labelStyle;

  /// Text under major ticks. Defaults to the value without trailing zeros.
  final RulerLabelBuilder? labelBuilder;

  /// A selection click each time a new value reaches the notch.
  final bool haptics;

  /// What is being picked, for screen readers.
  final String? semanticLabel;

  /// How screen readers speak a value, e.g. `(v) => '${v.round()} centimetres'`.
  final RulerLabelBuilder? semanticValueBuilder;

  @override
  State<NotchRulerPicker> createState() => _NotchRulerPickerState();
}

class _NotchRulerPickerState extends State<NotchRulerPicker> with SingleTickerProviderStateMixin {
  late RulerScale _scale = _makeScale();
  late final ScrollController _controller = ScrollController(initialScrollOffset: _scale.offsetFor(widget.value));
  late final AnimationController _bump = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late int _index = _scale.indexFor(widget.value);
  bool _selfChange = false;

  /// How many steps `min` sits past a multiple of zero, so ticks line up with round values.
  int get _phase => (widget.min / widget.step).round();

  RulerScale _makeScale() => RulerScale(min: widget.min, max: widget.max, step: widget.step, spacing: widget.spacing);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(NotchRulerPicker old) {
    super.didUpdateWidget(old);
    if (old.min != widget.min || old.max != widget.max || old.step != widget.step || old.spacing != widget.spacing) {
      _scale = _makeScale();
      _index = _scale.indexFor(widget.value);
      if (_controller.hasClients) _controller.jumpTo(_scale.offsetFor(widget.value));
      return;
    }
    // Values set from outside (buttons, unit switches) glide the ruler there.
    if (!_selfChange && _scale.indexFor(widget.value) != _index) _moveTo(_scale.indexFor(widget.value));
    _selfChange = false;
  }

  void _onScroll() {
    final index = (_controller.offset / _scale.spacing).round().clamp(0, _scale.count - 1);
    if (index == _index) return;
    _index = index;
    if (widget.haptics) HapticFeedback.selectionClick();
    _bump.forward(from: 0);
    _selfChange = true;
    widget.onChanged(_scale.valueAt(index));
  }

  void _moveTo(int index) {
    if (!_controller.hasClients) return;
    final target = index.clamp(0, _scale.count - 1) * _scale.spacing;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.jumpTo(target);
    } else {
      final distance = (target - _controller.offset).abs();
      _controller.animateTo(
        target,
        duration: Duration(milliseconds: (180 + math.sqrt(distance) * 12).clamp(180, 520).round()),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _stepBy(int delta) {
    final next = (_index + delta).clamp(0, _scale.count - 1);
    if (next != _index) _moveTo(next);
  }

  @override
  void dispose() {
    _controller.dispose();
    _bump.dispose();
    super.dispose();
  }

  String _label(double value) =>
      widget.labelBuilder?.call(value) ?? (value == value.roundToDouble() ? value.round().toString() : value.toString());

  @override
  Widget build(BuildContext context) {
    final value = _scale.valueAt(_index);
    final speak = widget.semanticValueBuilder ?? _label;
    final canIncrease = _index < _scale.count - 1;
    final canDecrease = _index > 0;
    return Semantics(
      label: widget.semanticLabel,
      slider: true,
      value: speak(value),
      // At either end there is nowhere to go, so the action isn't offered at all.
      increasedValue: canIncrease ? speak(_scale.valueAt(_index + 1)) : null,
      decreasedValue: canDecrease ? speak(_scale.valueAt(_index - 1)) : null,
      onIncrease: canIncrease ? () => _stepBy(1) : null,
      onDecrease: canDecrease ? () => _stepBy(-1) : null,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyUpEvent) return KeyEventResult.ignored;
          final big = HardwareKeyboard.instance.isShiftPressed ? widget.majorEvery : 1;
          final delta = switch (event.logicalKey) {
            LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.arrowUp => big,
            LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowDown => -big,
            LogicalKeyboardKey.pageUp => widget.majorEvery,
            LogicalKeyboardKey.pageDown => -widget.majorEvery,
            LogicalKeyboardKey.home => -_index,
            LogicalKeyboardKey.end => _scale.count - 1 - _index,
            _ => null,
          };
          if (delta == null) return KeyEventResult.ignored;
          _stepBy(delta);
          return KeyEventResult.handled;
        },
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return SizedBox(
              height: widget.height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final half = constraints.maxWidth / 2;
                  return Stack(
                    children: [
                      ShaderMask(
                        // Ticks fade out towards both edges.
                        shaderCallback: (rect) => const LinearGradient(
                          colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
                          stops: [0, .22, .78, 1],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: ExcludeSemantics(
                          child: ListView.builder(
                            controller: _controller,
                            scrollDirection: Axis.horizontal,
                            physics: NotchSnapPhysics(scale: _scale),
                            padding: EdgeInsets.symmetric(horizontal: half - widget.spacing / 2),
                            itemExtent: widget.spacing,
                            itemCount: _scale.count,
                            itemBuilder: (context, i) {
                              // Long ticks fall on round values (70, 80…), not on every n-th tick from min.
                              final step = i + _phase;
                              final major = step % widget.majorEvery == 0;
                              return _Tick(
                                index: i,
                                scale: _scale,
                                controller: _controller,
                                kind: major
                                    ? _TickKind.major
                                    : widget.midEvery > 0 && step % widget.midEvery == 0
                                    ? _TickKind.mid
                                    : _TickKind.minor,
                                label: major ? _label(_scale.valueAt(i)) : null,
                                color: widget.color,
                                mutedColor: widget.mutedColor,
                                labelStyle: widget.labelStyle,
                              );
                            },
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Center(
                          child: ScaleTransition(
                            // The notch dips briefly as each value passes, like a detent.
                            scale: TweenSequence([
                              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.86), weight: 30),
                              TweenSequenceItem(
                                tween: Tween(begin: 0.86, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
                                weight: 70,
                              ),
                            ]).animate(_bump),
                            alignment: Alignment.topCenter,
                            child: CustomPaint(
                              size: Size(18, widget.height),
                              painter: _NotchPainter(color: widget.notchColor, focused: focused),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Scroll physics that always come to rest with a tick under the notch.
class NotchSnapPhysics extends ScrollPhysics {
  const NotchSnapPhysics({required this.scale, super.parent});

  final RulerScale scale;

  @override
  NotchSnapPhysics applyTo(ScrollPhysics? ancestor) => NotchSnapPhysics(scale: scale, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    // Let the platform decide how far a fling would travel, then round that to a tick.
    final natural = super.createBallisticSimulation(position, velocity);
    final projected = natural?.x(double.infinity) ?? position.pixels;
    final target = scale.snap(projected.clamp(position.minScrollExtent, position.maxScrollExtent));
    if ((target - position.pixels).abs() < tolerance.distance && velocity.abs() < tolerance.velocity) return null;
    return ScrollSpringSimulation(
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 100, ratio: 1.05),
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

enum _TickKind { minor, mid, major }

class _Tick extends StatelessWidget {
  const _Tick({
    required this.index,
    required this.scale,
    required this.controller,
    required this.kind,
    required this.label,
    required this.color,
    required this.mutedColor,
    required this.labelStyle,
  });

  final int index;
  final RulerScale scale;
  final ScrollController controller;
  final _TickKind kind;
  final String? label;
  final Color color;
  final Color mutedColor;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Ticks grow and brighten as they approach the notch.
        final offset = controller.hasClients ? controller.offset : 0.0;
        final distance = ((index * scale.spacing - offset) / scale.spacing).abs();
        final near = (1 - distance / 6).clamp(0.0, 1.0);
        return CustomPaint(
          painter: _TickPainter(kind: kind, near: near, label: label, color: Color.lerp(mutedColor, color, near)!, labelStyle: labelStyle),
        );
      },
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({required this.kind, required this.near, required this.label, required this.color, required this.labelStyle});

  final _TickKind kind;
  final double near;
  final String? label;
  final Color color;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final base = switch (kind) {
      _TickKind.major => 0.46,
      _TickKind.mid => 0.32,
      _TickKind.minor => 0.2,
    };
    final length = size.height * base * (1 + near * 0.18);
    final x = size.width / 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, length),
      Paint()
        ..color = color
        ..strokeWidth = kind == _TickKind.major ? 2 : 1.4
        ..strokeCap = StrokeCap.round,
    );
    if (label != null) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x - painter.width / 2, size.height * 0.64));
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.near != near || old.color != color || old.label != label || old.kind != kind;
}

class _NotchPainter extends CustomPainter {
  _NotchPainter({required this.color, required this.focused});

  final Color color;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final paint = Paint()..color = color;
    // A small downward notch with a line hanging from it.
    final notch = Path()
      ..moveTo(x - 7, 0)
      ..lineTo(x + 7, 0)
      ..lineTo(x, 9)
      ..close();
    canvas.drawPath(notch, paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.5, 4, 3, size.height * 0.58), const Radius.circular(2)), paint);
    if (focused) {
      canvas.drawCircle(
        Offset(x, 4),
        11,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_NotchPainter old) => old.color != color || old.focused != focused;
}
