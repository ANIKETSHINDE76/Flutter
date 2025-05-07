import 'package:gsheets/gsheets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/student_data.dart';

class SheetsService {
  static const _storage = FlutterSecureStorage();
  static const _credentialsKey = 'google_sheets_credentials';
  
  GSheets? _gsheets;
  Worksheet? _worksheet;

  Future<void> initialize() async {
    final credentials = await _storage.read(key: _credentialsKey);
    if (credentials == null) {
      throw Exception('Google Sheets credentials not found. Please configure them in settings.');
    }
    _gsheets = GSheets(credentials);
  }

  Future<void> setCredentials(String credentials) async {
    await _storage.write(key: _credentialsKey, value: credentials);
    _gsheets = GSheets(credentials);
  }

  Future<List<StudentData>> getStudentData(String spreadsheetId) async {
    try {
      if (_gsheets == null) {
        await initialize();
      }

      final ss = await _gsheets!.spreadsheet(spreadsheetId);
      _worksheet = ss.worksheetByIndex(0);

      if (_worksheet == null) {
        throw Exception('Worksheet not found');
      }

      // Get all rows
      final rows = await _worksheet!.values.allRows();
      
      if (rows.isEmpty) {
        throw Exception('No data found in sheet');
      }

      // Validate header row
      final headers = rows.first.map((h) => h.trim()).toList();
      if (headers.length < 3 || 
          !headers.contains('Name') || 
          !headers.contains('Email') || 
          !headers.contains('Attendance')) {
        throw Exception('Invalid sheet format. Required columns: Name, Email, Attendance');
      }

      // Find column indices
      final nameIndex = headers.indexOf('Name');
      final emailIndex = headers.indexOf('Email');
      final attendanceIndex = headers.indexOf('Attendance');
      
      // Skip header row and convert to StudentData
      final students = rows.skip(1).map((row) {
        if (row.length <= [nameIndex, emailIndex, attendanceIndex].reduce((a, b) => a > b ? a : b)) {
          return null;
        }

        final name = row[nameIndex].trim() ?? '';
        final email = row[emailIndex].trim() ?? '';
        
        if (name.isEmpty || email.isEmpty || !_isValidEmail(email)) {
          return null;
        }
        
        final attendanceStr = row[attendanceIndex].toString().replaceAll('%', '').trim();
        double? attendance;
        try {
          attendance = double.parse(attendanceStr) / 100;
          if (attendance < 0 || attendance > 1) {
            return null;
          }
        } catch (e) {
          return null;
        }
        
        return StudentData(
          name: name,
          email: email,
          attendancePercentage: attendance,
        );
      }).where((student) => student != null).cast<StudentData>().toList();

      if (students.isEmpty) {
        throw Exception('No valid student data found in sheet');
      }

      return students;
    } catch (e) {
      throw Exception('Error reading Google Sheet: $e');
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  static String? extractSpreadsheetId(String url) {
    // Extract ID from various Google Sheets URL formats
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
} 