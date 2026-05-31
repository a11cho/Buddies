import 'package:flutter/material.dart';

import '../../core/service_registry.dart';
import '../../services/report_service.dart';

// 채팅 메시지 신고 dialog입니다.
// reporterUserId는 보내지 않고, 서버가 JWT에서 알아낸다는 SDD 기준을 따릅니다.
class ReportDialog extends StatefulWidget {
  const ReportDialog({
    required this.lobbyId,
    required this.reportedUserId,
    required this.reportedUserName,
    this.reportedMessageId,
    this.messagePreview,
    super.key,
  });

  final int lobbyId;
  final int reportedUserId;
  final int? reportedMessageId;
  final String reportedUserName;
  final String? messagePreview;

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedReason = ReportReason.abusiveLanguage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report message'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reported user: ${widget.reportedUserName}'),
            if (widget.messagePreview != null &&
                widget.messagePreview!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.messagePreview!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: ReportReason.abusiveLanguage,
                  child: Text('Abusive language'),
                ),
                DropdownMenuItem<String>(
                  value: ReportReason.spam,
                  child: Text('Spam'),
                ),
                DropdownMenuItem<String>(
                  value: ReportReason.inappropriateContent,
                  child: Text('Inappropriate content'),
                ),
                DropdownMenuItem<String>(
                  value: ReportReason.other,
                  child: Text('Other'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedReason = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
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
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.flag_outlined),
          label: const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report description is required.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AppServices.reportService.submitReport(
        ReportRequest(
          lobbyId: widget.lobbyId,
          reportedUserId: widget.reportedUserId,
          reportedMessageId: widget.reportedMessageId,
          reason: _selectedReason,
          description: description,
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
