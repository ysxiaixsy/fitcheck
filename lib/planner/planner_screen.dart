import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, this.now});
  final DateTime? now;
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late DateTime _selected, _month;
  @override
  void initState() {
    super.initState();
    _selected = dateOnly(widget.now ?? DateTime.now());
    _month = DateTime(_selected.year, _selected.month);
  }

  void _move(int offset) =>
      setState(() => _month = DateTime(_month.year, _month.month + offset));
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context), text = Theme.of(context).textTheme;
    final today = dateOnly(widget.now ?? DateTime.now());
    final first = DateTime(_month.year, _month.month, 2 - _month.weekday);
    final count =
        ((_month.weekday - 1 + DateTime(_month.year, _month.month + 1, 0).day) /
                7)
            .ceil() *
        7;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _move(-1),
                  icon: AppSvg('previous', color: c.primary),
                ),
                Expanded(
                  child: Text(
                    '${monthNames[_month.month - 1]} ${_month.year}',
                    key: const Key('calendar-month'),
                    textAlign: TextAlign.center,
                    style: text.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => _move(1),
                  icon: AppSvg('next', color: c.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(
                constraints.maxWidth - AppSpace.xxl,
                AppSize.touch * 7,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final day in weekdayNames)
                            Expanded(
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: text.labelSmall?.copyWith(
                                  color: c.secondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.xs),
                      for (var row = 0; row < count ~/ 7; row++)
                        Row(
                          children: List.generate(7, (column) {
                            final date = DateTime(
                              first.year,
                              first.month,
                              first.day + row * 7 + column,
                            );
                            final selected = date == _selected,
                                isToday = date == today;
                            return Expanded(
                              child: Semantics(
                                button: true,
                                selected: selected,
                                label: readableDate(date),
                                child: ExcludeSemantics(
                                  child: InkWell(
                                    key: ValueKey(
                                      'calendar-${date.toIso8601String()}',
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                    onTap: () => setState(() {
                                      _selected = date;
                                      _month = DateTime(date.year, date.month);
                                    }),
                                    child: SizedBox(
                                      height: AppSize.touch,
                                      child: Center(
                                        child: Container(
                                          width: AppSize.dateCircle,
                                          height: AppSize.dateCircle,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: selected ? c.accent : null,
                                            border: isToday && !selected
                                                ? Border.all(
                                                    color: c.accent,
                                                    width: AppSize.focus,
                                                  )
                                                : null,
                                          ),
                                          child: Text(
                                            '${date.day}',
                                            style: text.bodyMedium?.copyWith(
                                              color: selected
                                                  ? c.onAccent
                                                  : date.month == _month.month
                                                  ? c.primary
                                                  : c.secondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(readableDate(_selected), style: text.titleLarge),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'No plan for this day.',
                    style: text.bodyMedium?.copyWith(color: c.secondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
