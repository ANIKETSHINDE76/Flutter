class MessageTemplate {
  final String subject;
  final String body;
  final Map<String, String> conditions;

  MessageTemplate({
    required this.subject,
    required this.body,
    this.conditions = const {},
  });

  String generateSubject(Map<String, dynamic> data) {
    return _replacePlaceholders(subject, data);
  }

  String generateMessage(Map<String, dynamic> data) {
    return _replacePlaceholders(body, data);
  }

  String _replacePlaceholders(String template, Map<String, dynamic> data) {
    var result = template;
    for (var entry in data.entries) {
      final placeholder = '{${entry.key}}';
      if (result.contains(placeholder)) {
        final value = entry.value;
        if (value is double) {
          // Format percentages nicely without multiplying by 100 again
          result = result.replaceAll(
            placeholder,
            '${value.toStringAsFixed(1)}%',
          );
        } else {
          result = result.replaceAll(placeholder, value.toString());
        }
      }
    }
    return result;
  }

  bool matchesConditions(Map<String, dynamic> data) {
    for (var condition in conditions.entries) {
      final value = data[condition.key]?.toString().toLowerCase();
      final target = condition.value.toLowerCase();

      if (target.startsWith('<')) {
        final threshold = double.tryParse(target.substring(1));
        final dataValue = (value != null) ? double.tryParse(value) : null;
        if (threshold == null || dataValue == null || dataValue >= threshold) {
          return false;
        }
      } else if (target.startsWith('>')) {
        final threshold = double.tryParse(target.substring(1));
        final dataValue = (value != null) ? double.tryParse(value) : null;
        if (threshold == null || dataValue == null || dataValue <= threshold) {
          return false;
        }
      } else if (!target.contains('*')) {
        if (value != target) {
          return false;
        }
      } else {
        final pattern = target.replaceAll('*', '.*');
        if (!RegExp(pattern).hasMatch(value ?? '')) {
          return false;
        }
      }
    }
    return true;
  }
} 