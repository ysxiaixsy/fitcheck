import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/fitcheck_theme.dart';

class AppSvg extends StatelessWidget {
  const AppSvg(
    this.name, {
    super.key,
    this.color,
    this.illustration = false,
    this.size,
  });
  final String name;
  final Color? color;
  final bool illustration;
  final double? size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size ?? (illustration ? AppSize.illustration : AppSize.icon),
      child: SvgPicture.asset(
        'assets/${illustration ? 'illustrations' : 'icons'}/$name.svg',
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
      ),
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(AppSpace.lg), child: child),
  );
}

class InlineMessage extends StatelessWidget {
  const InlineMessage(this.message, {super.key, this.isError = false});
  final String message;
  final bool isError;
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: isError ? c.dangerSubtle : c.successSubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: isError ? c.danger : c.success),
        ),
      ),
    );
  }
}

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
String readableDate(DateTime date) =>
    '${weekdayNames[date.weekday - 1]}, ${monthNames[date.month - 1]} ${date.day}';
