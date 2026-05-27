import '../services/auth_service.dart';
import '../models/user.dart';
import 'mock_data_store.dart';

class MockAuthService implements AuthService {
  MockAuthService({MockDataStore? store}) : _store = store ?? mockDataStore;

  final MockDataStore _store;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw StateError('Email and password are required.');
    }

    return AuthSession(
      accessToken: 'mock-access-token',
      tokenType: 'Bearer',
      expiresIn: 3600,
      user: _store.currentUser,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User> getMe() async => _store.currentUser;
}
