import '../models/student_data.dart';

class EmailTemplateService {
  String _template = '''
Dear {name},

We noticed that your attendance is currently at {attendance}%. 
Please note that maintaining regular attendance is crucial for academic success.

Best regards,
School Administration
''';

  String get template => _template;
  String get defaultTemplate => _template;

  set template(String value) {
    if (!isTemplateValid(value)) {
      throw Exception('Template must contain {name} and {attendance} variables');
    }
    _template = value;
  }

  bool isTemplateValid([String? templateToCheck]) {
    final template = templateToCheck ?? _template;
    return template.contains('{name}') && 
           template.contains('{attendance}');
  }

  String generatePreview(StudentData student) {
    return _template
        .replaceAll('{name}', student.name)
        .replaceAll('{attendance}', '${(student.attendancePercentage * 100).toStringAsFixed(1)}%');
  }

  List<String> generateEmailMessages(List<StudentData> students) {
    return students.map((student) => generatePreview(student)).toList();
  }
} 