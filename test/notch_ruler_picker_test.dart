import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notch_ruler_picker/notch_ruler_picker.dart';

class _Host extends StatefulWidget {
  const _Host({this.initial = 170, this.step = 1});

  final double initial;
  final double step;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double value = widget.initial;
  final changes = <double>[];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('value ${value.toString()}'),
                NotchRulerPicker(
                  key: const Key('ruler'),
                  value: value,
                  min: 100,
                  max: 230,
                  step: widget.step,
                  haptics: false,
                  semanticLabel: 'Height',
                  semanticValueBuilder: (v) => '${v.round()} centimetres',
                  onChanged: (v) => setState(() {
                    value = v;
                    changes.add(v);
                  }),
                ),
                TextButton(onPressed: () => setState(() => value = 200), child: const Text('set 200')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('RulerScale', () {
    const scale = RulerScale(min: 100, max: 230, spacing: 12);

    test('maps values and offsets both ways', () {
      expect(scale.count, 131);
      expect(scale.offsetFor(170), 840);
      expect(scale.valueAtOffset(840), 170);
      expect(scale.valueAtOffset(845), 170);
      expect(scale.valueAtOffset(847), 171);
    });

    test('clamps to the ends and snaps to ticks', () {
      expect(scale.indexFor(50), 0);
      expect(scale.indexFor(999), 130);
      expect(scale.snap(-40), 0);
      expect(scale.snap(5000), 1560);
      expect(scale.snap(845), 840);
    });

    test('fractional steps stay tidy', () {
      const kg = RulerScale(min: 30, max: 200, step: 0.1);
      expect(kg.count, 1701);
      expect(kg.valueAt(3), 30.3);
      expect(kg.valueAt(1), 30.1);
      expect(kg.indexFor(72.46), 425);
    });
  });

  group('RulerUnits', () {
    test('converts height and weight', () {
      expect(RulerUnits.cmToFeetInches(170), (5, 7));
      expect(RulerUnits.cmToFeetInches(182.88), (6, 0));
      expect(RulerUnits.feetInchesToCm(5, 7), closeTo(170.18, 1e-9));
      expect(RulerUnits.kgToLb(68), closeTo(149.914, 1e-3));
      expect(RulerUnits.lbToKg(150), closeTo(68.039, 1e-3));
    });
  });

  group('NotchRulerPicker', () {
    testWidgets('dragging changes the value and settles on a tick', (tester) async {
      await tester.pumpWidget(const _Host());
      expect(find.text('value 170.0'), findsOneWidget);
      await tester.drag(find.byKey(const Key('ruler')), const Offset(-60, 0));
      await tester.pumpAndSettle();
      final state = tester.state<_HostState>(find.byType(_Host));
      expect(state.value, 175);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.pixels % 12, 0);
    });

    testWidgets('a fling travels further and still lands on a tick', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.fling(find.byKey(const Key('ruler')), const Offset(-200, 0), 1500);
      await tester.pumpAndSettle();
      final state = tester.state<_HostState>(find.byType(_Host));
      expect(state.value, greaterThan(190));
      expect(state.value, state.value.roundToDouble());
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels % 12, 0);
    });

    testWidgets('an outside value change glides the ruler there', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.tap(find.text('set 200'));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels, 1200);
      expect(find.text('value 200.0'), findsOneWidget);
    });

    testWidgets('arrow keys step by one, shift steps by a major tick', (tester) async {
      await tester.pumpWidget(const _Host());
      Focus.of(tester.element(find.byType(ListView))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('value 171.0'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('value 161.0'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(find.text('value 230.0'), findsOneWidget);
    });

    testWidgets('behaves as a slider for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const _Host());
      final node = find.bySemanticsLabel('Height');
      expect(
        tester.getSemantics(node),
        matchesSemantics(
          label: 'Height',
          value: '170 centimetres',
          increasedValue: '171 centimetres',
          decreasedValue: '169 centimetres',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('Height'));
      await tester.pumpAndSettle();
      expect(find.text('value 171.0'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('fractional steps report tidy values', (tester) async {
      await tester.pumpWidget(const _Host(initial: 170, step: 0.5));
      await tester.drag(find.byKey(const Key('ruler')), const Offset(-36, 0));
      await tester.pumpAndSettle();
      expect(tester.state<_HostState>(find.byType(_Host)).value, 171.5);
    });
  });
}
