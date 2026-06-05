import 'package:flutter/material.dart';

import '../core/enums.dart';
import 'image_detail_view.dart';

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFEDEDED),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                content ?? '',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isMine ? const Color(0xFF0054FF) : colorScheme.surface;
    final textColor = isMine ? Colors.white : colorScheme.onSurface;
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 286),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            border: isMine
                ? null
                : Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 5),
              bottomRight: Radius.circular(isMine ? 5 : 18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine && senderName != null) ...[
                  Text(
                    senderName!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (messageType == ChatMessageType.media)
                  _MediaAttachment(mediaUrl: mediaUrl)
                else
                  Text(
                    content ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textColor,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaAttachment extends StatelessWidget {
  const _MediaAttachment({required this.mediaUrl});

  final String? mediaUrl;

  @override
  Widget build(BuildContext context) {
    final label = _mediaLabel(mediaUrl);
    final colorScheme = Theme.of(context).colorScheme;

    final url = mediaUrl;
    final canRenderImage = url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));

    if (canRenderImage) {
      return GestureDetector(
        onTap: () => openImageDetailView(
          context,
          imageUrl: url,
          title: 'Photo',
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _MediaFallback(
                label: label,
                colorScheme: colorScheme,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return SizedBox(
                width: 220,
                height: 140,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes == null
                        ? null
                        : loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return _MediaFallback(label: label, colorScheme: colorScheme);
  }

  String? _mediaLabel(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final normalized = value.replaceFirst('mock-media://', '');
    return normalized.split('/').last;
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({
    required this.label,
    required this.colorScheme,
  });

  final String? label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final labelText = label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
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
              if (labelText != null) ...[
                const SizedBox(height: 2),
                Text(
                  labelText,
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
}
