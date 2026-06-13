import 'dart:convert';

import 'local_store.dart';

class CacheStore {
  CacheStore._();

  static Future<void> write(String key, Object value) {
    return LocalStore.setString('cache.$key', jsonEncode(value));
  }

  static Future<dynamic> read(String key) async {
    final value = await LocalStore.getString('cache.$key');
    if (value == null) {
      return null;
    }
    try {
      return jsonDecode(value);
    } on FormatException {
      await LocalStore.remove('cache.$key');
      return null;
    }
  }
}
