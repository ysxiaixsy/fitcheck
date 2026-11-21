import 'package:flutter/material.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';

class TodayWeekStrip extends StatelessWidget {
  const TodayWeekStrip({super.key, required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final today = dateOnly(date);
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final colors = FitCheckColors.of(context),
        text = Theme.of(context).textTheme;
    return Row(
      children: List.generate(7, (i) {
        final day = DateTime(monday.year, monday.month, monday.day + i);
        final selected = day == today;
        return Expanded(
          child: Semantics(
            label: readableDate(day),
            selected: selected,
            child: ExcludeSemantics(
              child: Column(
                children: [
                  Text(
                    weekdayNames[i],
                    style: text.labelSmall?.copyWith(
                      color: selected ? colors.accent : colors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Container(
                    width: AppSize.dateCircle,
                    height: AppSize.dateCircle,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? colors.accent : null,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: (selected ? text.labelLarge : text.bodyMedium)
                          ?.copyWith(
                            color: selected ? colors.onAccent : colors.primary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
