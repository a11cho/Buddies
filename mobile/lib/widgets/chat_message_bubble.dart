import 'package:flutter/material.dart';

import '../core/enums.dart';

// Chat 화면에서 메시지 하나를 보여줄 component입니다.
// messageType과 isMine에 따라 정렬과 표시 방식을 바꿉니다.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.messageType,
    required this.isMine,
    this.content,
    this.mediaUrl,
    this.senderName,
    super.key,
  });

  final String messageType;
  final bool isMine;
  final String? content;
  final String? mediaUrl;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    if (messageType == ChatMessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            content ?? '',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine && senderName != null) ...[
                  Text(
                    senderName!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                ],
                if (messageType == ChatMessageType.media)
                  _MediaPlaceholder(mediaUrl: mediaUrl)
                else
                  Text(content ?? ''),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.mediaUrl});

  final String? mediaUrl;

  @override
  Widget build(BuildContext context) {
    final label = _mediaLabel(mediaUrl);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: const SizedBox.square(
            dimension: 40,
            child: Icon(Icons.image_outlined, size: 22),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Photo attachment',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (label != null) ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String? _mediaLabel(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final normalized = value.replaceFirst('mock-media://', '');
    return normalized.split('/').last;
  }
}
