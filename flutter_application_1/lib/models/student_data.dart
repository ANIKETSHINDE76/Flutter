class StudentData {
  final String name;
  final String email;
  final double attendancePercentage;

  StudentData({
    required this.name,
    required this.email,
    required this.attendancePercentage,
  });

  factory StudentData.fromXml(Map<String, String?> data) {
    final name = data['name'] ?? '';
    final email = data['email'] ?? '';
    final attendanceStr = (data['attendance_percentage'] ?? '0').replaceAll('%', '');

    if (name.isEmpty || email.isEmpty) {
      throw Exception('Invalid student data: name and email are required');
    }

    double attendance;
    try {
      attendance = double.parse(attendanceStr) / 100;
      if (attendance < 0 || attendance > 1) {
        throw Exception('Invalid attendance percentage: must be between 0 and 100');
      }
    } catch (e) {
      throw Exception('Invalid attendance format: $attendanceStr');
    }

    return StudentData(
      name: name,
      email: email,
      attendancePercentage: attendance,
    );
  }

  bool needsAlert() {
    return attendancePercentage < 0.75; // Alert if attendance is below 75%
  }
} 