import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class BuddiesSelectOption<T> {
  const BuddiesSelectOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class BuddiesSelectField<T> extends StatelessWidget {
  const BuddiesSelectField({
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.options,
    required this.onChanged,
    this.prefixIcon,
    this.dense = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final T value;
  final String valueLabel;
  final List<BuddiesSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final IconData? prefixIcon;
  final bool dense;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color:
          enabled ? AppColors.inputFill : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: enabled ? AppColors.inputBorder : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => _openOptions(context) : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 14,
            vertical: dense ? 9 : 12,
          ),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(
                  prefixIcon,
                  size: dense ? 18 : 20,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.outline,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valueLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: AppColors.primaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openOptions(BuildContext context) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BuddiesSelectOptionRow<T>(
                      option: option,
                      isSelected: option.value == value,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && selected != value) {
      onChanged(selected);
    }
  }
}

class _BuddiesSelectOptionRow<T> extends StatelessWidget {
  const _BuddiesSelectOptionRow({
    required this.option,
    required this.isSelected,
  });

  final BuddiesSelectOption<T> option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.softBlue : AppColors.inputFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? AppColors.primaryBlue : AppColors.inputBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, option.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20,
                color: isSelected ? AppColors.primaryBlue : Colors.black38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
