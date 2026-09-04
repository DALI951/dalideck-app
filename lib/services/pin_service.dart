import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinService {
  static String hashPin(String pin) {
    final bytes = utf8.encode('dalideck:$pin');
    return sha256.convert(bytes).toString();
  }

  static bool verifyPin(String pin, String? storedHash) {
    if (storedHash == null) return false;
    return hashPin(pin) == storedHash;
  }
}
