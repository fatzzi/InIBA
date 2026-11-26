import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _jwtKey = 'inIba_jwt';

class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _jwtKey);
  Future<void> save(String token) => _storage.write(key: _jwtKey, value: token);
  Future<void> clear() => _storage.delete(key: _jwtKey);
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
