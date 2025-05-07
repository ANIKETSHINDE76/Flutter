import 'dart:io';
import 'package:excel/excel.dart';
import '../models/excel_data.dart';

class ExcelService {
  static final ExcelService instance = ExcelService._internal();
  ExcelService._internal();

  final List<ExcelFile> _excelFiles = [];
  List<ExcelFile> get excelFiles => _excelFiles;

  Future<void> loadExcelFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final fileName = file.path.split('/').last;

      final sheets = <ExcelSheet>[];
      for (var sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName]!;
        if (sheet.maxRows < 2) continue; // Skip empty sheets

        final columns = <String>[];
        final mappedRows = <Map<String, dynamic>>[];

        // Get headers from first row
        for (var cell in sheet.row(0)) {
          columns.add(cell?.value.toString() ?? '');
        }

        // Process data rows
        for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
          final row = sheet.row(rowIndex);
          final rowMap = <String, dynamic>{};
          
          for (var colIndex = 0; colIndex < columns.length; colIndex++) {
            if (colIndex < row.length) {
              rowMap[columns[colIndex]] = row[colIndex]?.value;
            }
          }
          
          if (rowMap.isNotEmpty) {
            mappedRows.add(rowMap);
          }
        }

        sheets.add(ExcelSheet(
          name: sheetName,
          columns: columns,
          mappedRows: mappedRows,
        ));
      }

      _excelFiles.add(ExcelFile(
        name: fileName,
        sheets: sheets,
      ));
    } catch (e) {
      throw Exception('Failed to load Excel file: $e');
    }
  }

  List<String> getAvailableColumns() {
    final Set<String> columns = {};
    for (var file in _excelFiles) {
      for (var sheet in file.sheets) {
        columns.addAll(sheet.columns);
      }
    }
    return columns.toList()..sort();
  }

  List<String> getCommonColumns() {
    if (_excelFiles.isEmpty) return [];

    final Map<String, int> columnCount = {};
    for (var file in _excelFiles) {
      for (var sheet in file.sheets) {
        for (var column in sheet.columns) {
          columnCount[column] = (columnCount[column] ?? 0) + 1;
        }
      }
    }

    return columnCount.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  void clearFiles() {
    _excelFiles.clear();
  }
} 