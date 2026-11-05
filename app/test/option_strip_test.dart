import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_remote/core/theme.dart';
import 'package:monitor_remote/ui/widgets/option_strip.dart';

Future<void> pumpStrip(WidgetTester tester, List<String> labels, {required double width}) => tester.pumpWidget(
  MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: OptionStrip(
            style: StripStyle.segments,
            selected: 1,
            onSelected: (_) {},
            options: [for (var i = 0; i < labels.length; i++) StripOption(i, labels[i])],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('compactLabels', () {
    test('drops a word every label repeats', () {
      expect(compactLabels(['Off', 'Level 1', 'Level 2', 'Level 3']), ['Off', '1', '2', '3']);
    });

    test('leaves labels alone when they share nothing', () {
      expect(compactLabels(['DisplayPort', 'HDMI-1', 'HDMI-2']), ['DisplayPort', 'HDMI-1', 'HDMI-2']);
      expect(compactLabels(['5000 K', '6500 K', 'User']), ['5000 K', '6500 K', 'User']);
    });

    test('needs at least two labels with the word', () {
      expect(compactLabels(['Off', 'Level 1']), ['Off', 'Level 1']);
    });
  });

  group('OptionStrip', () {
    testWidgets('shows "Level n" as short numbers in equal cells', (tester) async {
      // The test font draws every character as a full square, so it needs more room than a phone does.
      await pumpStrip(tester, ['Off', 'Level 1', 'Level 2', 'Level 3', 'Level 4', 'Level 5'], width: 420);

      for (final label in ['Off', '1', '2', '3', '4', '5']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(Wrap), findsNothing, reason: 'they fit in one row');
    });

    testWidgets('wraps instead of cutting labels that do not fit', (tester) async {
      await pumpStrip(tester, ['Standard', 'Reading mode', 'Movie night', 'Photo editing'], width: 240);

      expect(find.byType(Wrap), findsOneWidget);
      for (final label in ['Standard', 'Reading mode', 'Movie night', 'Photo editing']) {
        expect(find.text(label), findsOneWidget, reason: 'full label, no ellipsis');
      }
    });

    testWidgets('large system text also falls back to wrapping', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: OptionStrip(
                  style: StripStyle.segments,
                  selected: 0,
                  onSelected: (_) {},
                  options: const [StripOption(0, 'Muted'), StripOption(1, 'Unmuted'), StripOption(2, 'Speaker')],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
    });
  });
}
