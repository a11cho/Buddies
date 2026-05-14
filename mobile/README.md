# Buddies Mobile

Flutter SDK is not installed in the current local environment, so this folder contains a lightweight Flutter foundation instead of generated platform directories.

After installing Flutter, run:

```bash
flutter create .
flutter pub get
flutter run
```

Keep the existing `lib/main.dart` and `pubspec.yaml` content when Flutter asks about overwriting files.

Recommended next packages:

- `dio` for REST API
- `stomp_dart_client` for STOMP over WebSocket
- `flutter_secure_storage` for JWT storage
- `go_router` for route management
- `image_picker` for receipt/payment image attachments

