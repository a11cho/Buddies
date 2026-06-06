import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/service_registry.dart';
import '../../models/order_history_item.dart';
import '../../services/rating_service.dart';
import '../../widgets/buddies_style.dart';

// 닫힌 Lobby에 함께 있었던 사용자를 평가하는 dialog입니다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    required this.historyItem,
    super.key,
  });

  final OrderHistoryItem historyItem;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  final Map<int, TextEditingController> _feedbackControllers = {};
  final Map<int, int> _ratingsByUserId = {};
  final Set<int> _selectedUserIds = {};
  bool _isSubmitting = false;

  List<OrderHistoryParticipant> get _targets {
    final byUserId = <int, OrderHistoryParticipant>{};
    for (final participant in widget.historyItem.rateableParticipants) {
      byUserId.putIfAbsent(participant.userId, () => participant);
    }
    return byUserId.values.toList();
  }

  @override
  void initState() {
    super.initState();
    for (final target in _targets) {
      _selectedUserIds.add(target.userId);
      _ratingsByUserId[target.userId] = 5;
      _feedbackControllers[target.userId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _feedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets;

    return BuddiesStyleScope(
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Rate members',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (targets.isEmpty)
                  const Text('No members are available to rate.')
                else
                  for (final target in targets) ...[
                    _TargetRatingEditor(
                      target: target,
                      isSelected: _selectedUserIds.contains(target.userId),
                      rating: _ratingsByUserId[target.userId] ?? 5,
                      feedbackController: _feedbackControllers[target.userId]!,
                      isEnabled: !_isSubmitting,
                      onSelectedChanged: (isSelected) {
                        setState(() {
                          if (isSelected) {
                            _selectedUserIds.add(target.userId);
                          } else {
                            _selectedUserIds.remove(target.userId);
                          }
                        });
                      },
                      onRatingChanged: (rating) {
                        setState(() {
                          _ratingsByUserId[target.userId] = rating;
                          _selectedUserIds.add(target.userId);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                _isSubmitting ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _isSubmitting || targets.isEmpty ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.star_outline),
            label: Text(
              _selectedUserIds.length > 1
                  ? 'Submit ${_selectedUserIds.length}'
                  : 'Submit',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final selectedTargets = _targets
        .where((target) => _selectedUserIds.contains(target.userId))
        .toList();
    if (selectedTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member to rate.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      for (final target in selectedTargets) {
        await AppServices.ratingService.submitRating(
          RatingRequest(
            lobbyId: widget.historyItem.lobbyId,
            targetUserId: target.userId,
            rating: _ratingsByUserId[target.userId] ?? 5,
            feedback: _feedbackControllers[target.userId]?.text.trim() ?? '',
          ),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

class _TargetRatingEditor extends StatelessWidget {
  const _TargetRatingEditor({
    required this.target,
    required this.isSelected,
    required this.rating,
    required this.feedbackController,
    required this.isEnabled,
    required this.onSelectedChanged,
    required this.onRatingChanged,
  });

  final OrderHistoryParticipant target;
  final bool isSelected;
  final int rating;
  final TextEditingController feedbackController;
  final bool isEnabled;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<int> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isEnabled ? () => onSelectedChanged(!isSelected) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        activeColor: AppColors.primaryBlue,
                        value: isSelected,
                        onChanged: isEnabled
                            ? (value) => onSelectedChanged(value ?? false)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              target.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '#${target.userId}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _StarRatingSelector(
              rating: rating,
              isEnabled: isEnabled,
              onChanged: onRatingChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              enabled: isEnabled && isSelected,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRatingSelector extends StatelessWidget {
  const _StarRatingSelector({
    required this.rating,
    required this.isEnabled,
    required this.onChanged,
  });

  final int rating;
  final bool isEnabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Rating'),
      child: Wrap(
        spacing: 2,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var value = 1; value <= 5; value += 1)
            IconButton(
              tooltip: '$value stars',
              onPressed: isEnabled ? () => onChanged(value) : null,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                value <= rating ? Icons.star : Icons.star_border,
                color: value <= rating ? AppColors.primaryBlue : null,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '$rating/5',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
