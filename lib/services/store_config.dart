import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppStore {
  direct,
  bazaar,
}

class StoreConfig {
  StoreConfig._();

  static const String _compileTimeStore =
      String.fromEnvironment('APP_STORE', defaultValue: 'direct');

  static AppStore get current {
    final raw = (_compileTimeStore.isNotEmpty
            ? _compileTimeStore
            : _value('APP_STORE'))
        .toLowerCase();
    return raw == 'bazaar' ? AppStore.bazaar : AppStore.direct;
  }

  static bool get isBazaar => current == AppStore.bazaar;

  static String _value(String key) {
    try {
      return dotenv.env[key]?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Cafe Bazaar RSA public key. This is a public key, not a secret.
  static String? get bazaarRsaPublicKey {
    final value = _value('BAZAAR_RSA_PUBLIC_KEY');
    return value.isEmpty ? null : value;
  }
}
