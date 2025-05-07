import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EmailConfig {
  static const _storage = FlutterSecureStorage();
  
  // Default values
  static const String defaultSmtpHost = 'smtp.gmail.com';
  static const int defaultSmtpPort = 465;  // Using SSL port instead of TLS
  static const String defaultSenderName = 'LazyBot Attendance System';

  static Future<String> get smtpHost async {
    final value = await _storage.read(key: 'email_smtp_host');
    return value ?? defaultSmtpHost;
  }

  static Future<int> get smtpPort async {
    final value = await _storage.read(key: 'email_smtp_port');
    return int.tryParse(value ?? '') ?? defaultSmtpPort;
  }

  static Future<String> get senderName async {
    final value = await _storage.read(key: 'email_sender_name');
    return value ?? defaultSenderName;
  }

  static Future<String> get username async {
    final value = await _storage.read(key: 'email_username');
    return value ?? '';
  }

  static Future<String> get password async {
    final value = await _storage.read(key: 'email_password');
    return value ?? '';
  }

  // Helper method to validate email settings
  static Future<bool> validateSettings() async {
    final user = await username;
    final pass = await password;
    return user.isNotEmpty && 
           pass.isNotEmpty && 
           user.contains('@') &&
           user.contains('.');
  }

  // Helper method to save all settings
  static Future<void> saveSettings({
    required String username,
    required String password,
    required String smtpHost,
    required int smtpPort,
    required String senderName,
  }) async {
    await _storage.write(key: 'email_username', value: username);
    await _storage.write(key: 'email_password', value: password);
    await _storage.write(key: 'email_smtp_host', value: smtpHost);
    await _storage.write(key: 'email_smtp_port', value: smtpPort.toString());
    await _storage.write(key: 'email_sender_name', value: senderName);
  }
} 