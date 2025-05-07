import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher_string.dart';
import '../models/student_data.dart';
import '../config/email_config.dart';

class EmailSendResult {
  final bool success;
  final String? error;
  final String email;

  EmailSendResult({
    required this.success,
    this.error,
    required this.email,
  });
}

class EmailService {
  String? _smtpServer;
  String? _smtpUsername;
  String? _smtpPassword;
  String? _fromEmail;

  EmailService({
    String? smtpServer,
    String? smtpUsername,
    String? smtpPassword,
    String? fromEmail,
  })  : _smtpServer = smtpServer,
        _smtpUsername = smtpUsername,
        _smtpPassword = smtpPassword,
        _fromEmail = fromEmail;

  bool get isConfigured =>
      _smtpServer != null &&
      _smtpUsername != null &&
      _smtpPassword != null &&
      _fromEmail != null;

  Future<void> sendEmail({
    required String to,
    required String subject,
    required String message,
  }) async {
    if (!isConfigured) {
      throw Exception('Email service is not configured');
    }

    final smtpServer = SmtpServer(
      _smtpServer!,
      username: _smtpUsername!,
      password: _smtpPassword!,
    );

    final email = Message()
      ..from = Address(_fromEmail!)
      ..recipients.add(to)
      ..subject = subject
      ..text = message;

    try {
      await send(email, smtpServer);
    } catch (e) {
      throw Exception('Failed to send email: ${e.toString()}');
    }
  }

  void configure({
    required String smtpServer,
    required String smtpUsername,
    required String smtpPassword,
    required String fromEmail,
  }) {
    _smtpServer = smtpServer;
    _smtpUsername = smtpUsername;
    _smtpPassword = smtpPassword;
    _fromEmail = fromEmail;
  }

  Future<EmailSendResult> sendEmailToRecipient({
    required String recipientEmail,
    required String subject,
    required String body,
  }) async {
    try {
      final username = await EmailConfig.username;
      final password = await EmailConfig.password;

      if (username.isEmpty || password.isEmpty) {
        return EmailSendResult(
          success: false,
          error: 'Email credentials not configured. Please check settings.',
          email: recipientEmail,
        );
      }

      if (kIsWeb) {
        // Web platform: Use mailto link
        final String mailtoUrl = 'mailto:$recipientEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';

        try {
          await launchUrlString(mailtoUrl, mode: LaunchMode.platformDefault);
          return EmailSendResult(
            success: true,
            email: recipientEmail,
          );
        } catch (e) {
          return EmailSendResult(
            success: false,
            error: 'Could not launch email client: $e',
            email: recipientEmail,
          );
        }
      } else {
        // Android/Desktop platform: Use SMTP with SSL
        final smtpServer = gmail(username, password);

        final message = Message()
          ..from = Address(username, _fromEmail!)
          ..recipients.add(recipientEmail)
          ..subject = subject
          ..text = body;

        try {
          await send(message, smtpServer);
          return EmailSendResult(
            success: true,
            email: recipientEmail,
          );
        } catch (e) {
          String errorMsg = e.toString();
          if (errorMsg.contains('5.7.8')) {
            errorMsg = 'Enable less secure app access or use an App Password. Error: $e';
          } else if (errorMsg.contains('5.7.9')) {
            errorMsg = 'Username and password not accepted. Try using an App Password. Error: $e';
          }
          return EmailSendResult(
            success: false,
            error: errorMsg,
            email: recipientEmail,
          );
        }
      }
    } catch (e) {
      return EmailSendResult(
        success: false,
        error: e.toString(),
        email: recipientEmail,
      );
    }
  }

  Future<List<EmailSendResult>> sendBulkEmails({
    required List<StudentData> students,
    required List<String> subject,
    required List<String> messageTemplates,
    required void Function(int current, int total) onProgress,
  }) async {
    if (_smtpServer == null || _smtpUsername == null || _smtpPassword == null) {
      throw Exception('Email service not configured');
    }

      final results = <EmailSendResult>[];
    final total = students.length;
      
      for (var i = 0; i < students.length; i++) {
      try {
        final message = Message()
          ..from = Address(_smtpUsername!, _fromEmail!)
          ..recipients.add(students[i].email)
          ..subject = subject[i]
          ..text = messageTemplates[i];

        final smtpServer = SmtpServer(
          _smtpServer!,
          username: _smtpUsername!,
          password: _smtpPassword!,
        );

        await send(message, smtpServer);
        results.add(EmailSendResult(
          email: students[i].email,
          success: true,
        ));
        
        onProgress(i + 1, total);
      } catch (e) {
        results.add(EmailSendResult(
          email: students[i].email,
          success: false,
          error: e.toString(),
        ));
        onProgress(i + 1, total);
      }
    }
    return results;
  }
}

class EmailTemplateService {
  String? _smtpServer;
  String? _smtpUsername;
  String? _smtpPassword;
  String? _fromEmail;

  EmailTemplateService({
    String? smtpServer,
    String? smtpUsername,
    String? smtpPassword,
    String? fromEmail,
  })  : _smtpServer = smtpServer,
        _smtpUsername = smtpUsername,
        _smtpPassword = smtpPassword,
        _fromEmail = fromEmail;

  bool get isConfigured =>
      _smtpServer != null &&
      _smtpUsername != null &&
      _smtpPassword != null &&
      _fromEmail != null;

  Future<void> sendEmail({
    required String to,
    required String subject,
    required String message,
  }) async {
    if (!isConfigured) {
      throw Exception('Email service is not configured');
    }

    final smtpServer = SmtpServer(
      _smtpServer!,
      username: _smtpUsername!,
      password: _smtpPassword!,
    );

    final email = Message()
      ..from = Address(_fromEmail!)
      ..recipients.add(to)
      ..subject = subject
      ..text = message;

    try {
      await send(email, smtpServer);
    } catch (e) {
      throw Exception('Failed to send email: ${e.toString()}');
    }
  }

  void configure({
    required String smtpServer,
    required String smtpUsername,
    required String smtpPassword,
    required String fromEmail,
  }) {
    _smtpServer = smtpServer;
    _smtpUsername = smtpUsername;
    _smtpPassword = smtpPassword;
    _fromEmail = fromEmail;
  }
} 