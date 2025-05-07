
class ExcelSheet {
  final String name;
  final List<String> columns;
  final List<Map<String, dynamic>> mappedRows;

  ExcelSheet({
    required this.name,
    required this.columns,
    required this.mappedRows,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'columns': columns,
      'mappedRows': mappedRows,
    };
  }

  factory ExcelSheet.fromJson(Map<String, dynamic> json) {
    return ExcelSheet(
      name: json['name'] as String,
      columns: List<String>.from(json['columns'] as List),
      mappedRows: List<Map<String, dynamic>>.from(json['mappedRows'] as List),
    );
  }
}

class ExcelFile {
  final String name;
  final List<ExcelSheet> sheets;

  ExcelFile({
    required this.name,
    required this.sheets,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sheets': sheets.map((sheet) => sheet.toJson()).toList(),
    };
  }

  factory ExcelFile.fromJson(Map<String, dynamic> json) {
    return ExcelFile(
      name: json['name'] as String,
      sheets: (json['sheets'] as List)
          .map((sheet) => ExcelSheet.fromJson(sheet))
          .toList(),
    );
  }
} 