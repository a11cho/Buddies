import 'package:flutter_test/flutter_test.dart';

import 'package:buddies_mobile/api_client.dart';

const liveApiBaseUrl = String.fromEnvironment('LIVE_API_BASE_URL');

void main() {
  test(
    'loads lobbies from a running Buddies backend',
    () async {
      final client = BuddiesApiClient(baseUrl: liveApiBaseUrl);

      final lobbies = await client.getLobbies();

      expect(lobbies, isA<List<LobbySummary>>());
    },
    skip: liveApiBaseUrl.isEmpty ? 'Set LIVE_API_BASE_URL to run against a real backend.' : false,
  );
}
