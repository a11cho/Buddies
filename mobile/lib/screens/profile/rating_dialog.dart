import 'package:flutter/material.dart';

import '../../core/service_registry.dart';
import '../../models/order_history_item.dart';
import '../../services/rating_service.dart';

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
  final TextEditingController _feedbackController = TextEditingController();
  int? _targetUserId;
  int _rating = 5;
  bool _isSubmitting = false;

  List<OrderHistoryParticipant> get _targets {
    return widget.historyItem.rateableParticipants;
  }

  @override
  void initState() {
    super.initState();
    final targets = _targets;
    if (targets.isNotEmpty) {
      _targetUserId = targets.first.userId;
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets;
    return AlertDialog(
      title: const Text('Rate user'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _targetUserId,
              decoration: const InputDecoration(
                labelText: 'Target user',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final target in targets)
                  DropdownMenuItem<int>(
                    value: target.userId,
                    child: Text(target.name),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _targetUserId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _rating,
              decoration: const InputDecoration(
                labelText: 'Rating',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<int>(value: 5, child: Text('5')),
                DropdownMenuItem<int>(value: 4, child: Text('4')),
                DropdownMenuItem<int>(value: 3, child: Text('3')),
                DropdownMenuItem<int>(value: 2, child: Text('2')),
                DropdownMenuItem<int>(value: 1, child: Text('1')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _rating = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Feedback',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
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
          label: const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final targetUserId = _targetUserId;
    if (targetUserId == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AppServices.ratingService.submitRating(
        RatingRequest(
          lobbyId: widget.historyItem.lobbyId,
          targetUserId: targetUserId,
          rating: _rating,
          feedback: _feedbackController.text.trim(),
        ),
      );
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
