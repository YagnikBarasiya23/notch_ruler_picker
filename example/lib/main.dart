import 'package:flutter/material.dart';
import 'package:notch_ruler_picker/notch_ruler_picker.dart';

void main() => runApp(const NotchDemo());

const _bg = Color(0xFF050505);
const _panel = Color(0xFF0E0E10);
const _line = Color(0x1AFFFFFF);
const _muted = Color(0xFFA1A1AA);
const _accent = Color(0xFFD9F99D);

class NotchDemo extends StatelessWidget {
  const NotchDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notch — ruler picker for Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          surface: _panel,
          secondaryContainer: _accent,
          onSecondaryContainer: Colors.black,
        ),
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  double _heightCm = 170;
  double _weightKg = 68;
  bool _imperialHeight = false;
  bool _imperialWeight = false;

  // Imperial height is picked in whole inches; metric in centimetres.
  double get _heightValue => _imperialHeight ? (_heightCm / 2.54).roundToDouble() : _heightCm;
  double get _weightValue => _imperialWeight ? double.parse(RulerUnits.kgToLb(_weightKg).toStringAsFixed(0)) : _weightKg;

  String get _heightText {
    if (!_imperialHeight) return '${_heightCm.round()} cm';
    final (feet, inches) = RulerUnits.cmToFeetInches(_heightCm);
    return '$feet ft $inches in';
  }

  String get _weightText => _imperialWeight ? '${_weightValue.round()} lb' : '${_weightKg.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NOTCH · FLUTTER',
                    style: TextStyle(color: Color(0xFF71717A), letterSpacing: 3.5, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scroll to a number,\nfeel every step.',
                    style: TextStyle(fontSize: 44, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1.8),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'A ruler picker that snaps to each tick, clicks as values pass, and nudges its notch like a detent. Drag, fling, use the arrow keys or a screen reader.',
                    style: TextStyle(color: _muted, fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  _Card(
                    title: 'How tall are you?',
                    reading: _heightText,
                    units: const ['cm', 'ft · in'],
                    imperial: _imperialHeight,
                    onUnits: (v) => setState(() => _imperialHeight = v),
                    picker: NotchRulerPicker(
                      // A new key rebuilds the scale when the unit changes.
                      key: ValueKey('height-$_imperialHeight'),
                      value: _heightValue,
                      min: _imperialHeight ? 36 : 90,
                      max: _imperialHeight ? 96 : 244,
                      majorEvery: _imperialHeight ? 12 : 10,
                      midEvery: _imperialHeight ? 6 : 5,
                      labelBuilder: _imperialHeight ? (v) => "${v ~/ 12}'" : null,
                      semanticLabel: 'Height',
                      semanticValueBuilder: (v) =>
                          _imperialHeight ? '${v ~/ 12} feet ${(v % 12).round()} inches' : '${v.round()} centimetres',
                      onChanged: (v) => setState(() => _heightCm = _imperialHeight ? v * 2.54 : v),
                    ),
                    presets: [
                      ('Average', () => setState(() => _heightCm = 170)),
                      ('Tall', () => setState(() => _heightCm = 193)),
                      ('Short', () => setState(() => _heightCm = 152)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    title: 'What do you weigh?',
                    reading: _weightText,
                    units: const ['kg', 'lb'],
                    imperial: _imperialWeight,
                    onUnits: (v) => setState(() => _imperialWeight = v),
                    picker: NotchRulerPicker(
                      key: ValueKey('weight-$_imperialWeight'),
                      value: _weightValue,
                      min: _imperialWeight ? 66 : 30,
                      max: _imperialWeight ? 440 : 200,
                      step: _imperialWeight ? 1 : 0.1,
                      spacing: _imperialWeight ? 12 : 10,
                      majorEvery: 10,
                      midEvery: 5,
                      labelBuilder: _imperialWeight ? null : (v) => v.round().toString(),
                      semanticLabel: 'Weight',
                      semanticValueBuilder: (v) => _imperialWeight ? '${v.round()} pounds' : '${v.toStringAsFixed(1)} kilograms',
                      onChanged: (v) => setState(() => _weightKg = _imperialWeight ? RulerUnits.lbToKg(v) : v),
                    ),
                    presets: [
                      ('− 1 kg', () => setState(() => _weightKg = (_weightKg - 1).clamp(30, 200))),
                      ('+ 1 kg', () => setState(() => _weightKg = (_weightKg + 1).clamp(30, 200))),
                      ('+ 20 kg', () => setState(() => _weightKg = (_weightKg + 20).clamp(30, 200))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'MIT © 2026 Yagnik Barasiya · github.com/YagnikBarasiya23/notch_ruler_picker',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.reading,
    required this.units,
    required this.imperial,
    required this.onUnits,
    required this.picker,
    required this.presets,
  });

  final String title;
  final String reading;
  final List<String> units;
  final bool imperial;
  final ValueChanged<bool> onUnits;
  final Widget picker;
  final List<(String, VoidCallback)> presets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 22),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
                  ),
                ),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(units[0])),
                    ButtonSegment(value: true, label: Text(units[1])),
                  ],
                  selected: {imperial},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => onUnits(s.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            reading,
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),
          picker,
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              for (final (label, onTap) in presets)
                OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x38FFFFFF)),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
