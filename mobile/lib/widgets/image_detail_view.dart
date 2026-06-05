import 'package:flutter/material.dart';

class ImageDetailView extends StatelessWidget {
  const ImageDetailView({
    required this.imageUrl,
    this.title = 'Image',
    super.key,
  });

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Image could not be loaded.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return const CircularProgressIndicator(color: Colors.white);
            },
          ),
        ),
      ),
    );
  }
}

Future<void> openImageDetailView(
  BuildContext context, {
  required String imageUrl,
  String title = 'Image',
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => ImageDetailView(
        imageUrl: imageUrl,
        title: title,
      ),
    ),
  );
}
