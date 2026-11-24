import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

final apiClientProvider = Provider<Dio>((ref) => createApiClient());

Dio createApiClient() {
  return Dio(
    BaseOptions(
      baseUrl: '${AppConfig.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 5),
      headers: const {'Accept': 'application/json'},
    ),
  );
}

final apiHealthProvider = FutureProvider.autoDispose<bool>((ref) async {
  final response = await ref
      .read(apiClientProvider)
      .get<Map<String, dynamic>>('/health');
  return response.statusCode == 200 && response.data?['status'] == 'ok';
});
