import 'package:flutter/material.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';

class WardrobeScreen extends StatelessWidget {
  const WardrobeScreen({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });
  final String filter;
  final ValueChanged<String> onFilterChanged;
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context), text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: Row(
            children: [
              for (final value in ['All', 'Tops', 'Bottoms', 'Shoes', 'Scents'])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.sm),
                  child: Semantics(
                    selected: filter == value,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: filter == value
                            ? c.accentSubtle
                            : c.surface,
                        foregroundColor: filter == value ? c.accent : c.primary,
                        side: BorderSide(
                          color: filter == value ? c.accent : c.border,
                        ),
                        textStyle: text.labelMedium,
                      ),
                      onPressed: () => onFilterChanged(value),
                      child: Text('${filter == value ? '✓ ' : ''}$value'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '0 items',
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
                const SizedBox(height: AppSpace.md),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filter == 'Scents' ? 'Your fragrances' : 'Your clothes',
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        filter == 'Scents'
                            ? 'No fragrances added yet.'
                            : 'No clothes added yet.',
                        style: text.bodyMedium?.copyWith(color: c.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
