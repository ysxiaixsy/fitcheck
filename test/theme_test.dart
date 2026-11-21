import 'package:fitcheck/theme/fitcheck_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance(), b = background.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

void main() {
  for (final (name, theme) in [
    ('Light', FitCheckTheme.light),
    ('Dark', FitCheckTheme.dark),
  ]) {
    final c = theme.extension<FitCheckColors>()!;
    test('$name text pairs meet AA', () {
      for (final pair in [
        (c.primary, c.canvas),
        (c.primary, c.surface),
        (c.secondary, c.canvas),
        (c.secondary, c.surface),
        (c.accent, c.canvas),
        (c.accent, c.surface),
        (c.onAccent, c.accent),
        (c.success, c.successSubtle),
        (c.warning, c.warningSubtle),
        (c.danger, c.dangerSubtle),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    });
    test('$name has 16px body and a 12px type floor', () {
      expect(theme.textTheme.bodyMedium!.fontSize, 16);
      for (final style in [
        theme.textTheme.displayLarge,
        theme.textTheme.headlineLarge,
        theme.textTheme.titleLarge,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.bodySmall,
        theme.textTheme.labelLarge,
        theme.textTheme.labelMedium,
        theme.textTheme.labelSmall,
      ]) {
        expect(style!.fontSize, greaterThanOrEqualTo(12));
      }
    });
  }
}
