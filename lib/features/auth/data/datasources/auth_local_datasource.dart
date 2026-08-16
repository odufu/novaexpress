import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheToken(String token);
  Future<String?> getToken();
  Future<void> clearCache();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage storage;

  AuthLocalDataSourceImpl(this.storage);

  @override
  Future<void> cacheToken(String token) async {
    await storage.write(key: 'auth_token', value: token);
  }

  @override
  Future<String?> getToken() async {
    return await storage.read(key: 'auth_token');
  }

  @override
  Future<void> clearCache() async {
    await storage.delete(key: 'auth_token');
  }
}
