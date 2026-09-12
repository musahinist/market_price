import 'package:flutter/services.dart';

/// Bağlantıyı cihazın tarayıcısında açar.
///
/// Eklenti yerine uygulamanın kendi platform kanalını kullanır.
class UrlOpener {
  static const _channel = MethodChannel('market_price/url');

  /// Açılabildiyse true döner.
  static Future<bool> open(String url) async {
    try {
      return await _channel.invokeMethod<bool>('open', {'url': url}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
