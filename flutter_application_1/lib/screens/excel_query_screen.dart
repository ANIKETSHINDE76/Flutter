import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:math';
import 'alert_system_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ExcelFile {
  final File file;
  final List<String> sheets;
  final Map<String, List<String>> sheetColumns;
  final Map<String, List<List<dynamic>>> sheetData;

  ExcelFile({
    required this.file,
    required this.sheets,
    required this.sheetColumns,
    required this.sheetData,
  });
}

class QueryResult {
  final List<String> columns;
  final List<List<dynamic>> rows;

  QueryResult({
    required this.columns,
    required this.rows,
  });
}

class QueryHistory {
  final String query;
  final DateTime timestamp;
  final bool success;
  final bool isFavorite;

  QueryHistory({
    required this.query,
    required this.timestamp,
    required this.success,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'timestamp': timestamp.toIso8601String(),
    'success': success,
    'isFavorite': isFavorite,
  };

  factory QueryHistory.fromJson(Map<String, dynamic> json) => QueryHistory(
    query: json['query'],
    timestamp: DateTime.parse(json['timestamp']),
    success: json['success'],
    isFavorite: json['isFavorite'] ?? false,
  );
}

class ExcelQueryScreen extends StatefulWidget {
  const ExcelQueryScreen({super.key});

  @override
  State<ExcelQueryScreen> createState() => _ExcelQueryScreenState();
}

class _ExcelQueryScreenState extends State<ExcelQueryScreen> {
  List<ExcelFile> _selectedFiles = [];
  Set<String> _availableColumns = {};
  Set<String> _selectedColumns = {};
  bool _isLoading = false;
  bool _selectAllColumns = true;
  final TextEditingController _queryController = TextEditingController();
  String? _queryError;
  QueryResult? _queryResult;
  bool _isExecuting = false;
  List<QueryHistory> _queryHistory = [];
  bool _showHistory = false;
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _loadQueryHistory();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
          _selectedColumns.clear();
          _queryController.clear();
          _queryError = null;
          _queryResult = null;
        });

        final files = result.paths.map((path) => File(path!)).toList();
        await _processFiles(files);

        setState(() {
          _selectedColumns = _availableColumns.toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking files: $e')),
      );
    }
  }

  Future<void> _processFiles(List<File> files) async {
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      final sheets = excel.tables.keys.toList();
      final sheetColumns = <String, List<String>>{};
      final sheetData = <String, List<List<dynamic>>>{};
      
      // Print sheet names for debugging
      print('Available sheets in ${file.path.split('/').last}:');
      for (final sheet in sheets) {
        print('- $sheet');
      }
      
      for (final sheetName in sheets) {
        final sheet = excel.tables[sheetName]!;
        if (sheet.maxColumns > 0) {
          final columns = sheet.row(0).map((cell) => cell?.value.toString() ?? '').toList();
          sheetColumns[sheetName] = columns;
          
          final data = <List<dynamic>>[];
          for (var i = 1; i < sheet.maxRows; i++) {
            final row = sheet.row(i).map((cell) => cell?.value).toList();
            if (row.isNotEmpty) data.add(row);
          }
          sheetData[sheetName] = data;
          
          setState(() {
            _availableColumns.addAll(columns);
          });
        }
      }

      setState(() {
        _selectedFiles.add(ExcelFile(
          file: file,
          sheets: sheets,
          sheetColumns: sheetColumns,
          sheetData: sheetData,
        ));
      });
    }
  }

  void _toggleColumnSelection(String column) {
    setState(() {
      if (_selectedColumns.contains(column)) {
        _selectedColumns.remove(column);
      } else {
        _selectedColumns.add(column);
      }
    });
  }

  void _toggleSelectAllColumns() {
    setState(() {
      _selectAllColumns = !_selectAllColumns;
      if (_selectAllColumns) {
        _selectedColumns = _availableColumns.toSet();
      } else {
        _selectedColumns.clear();
      }
    });
  }

  void _validateQuery() {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _queryError = 'Please enter a query';
      });
      return;
    }

    // Basic SQL validation
    if (!query.toLowerCase().contains('select')) {
      setState(() {
        _queryError = 'Query must contain SELECT statement';
      });
      return;
    }

    // Check if selected columns are used in the query
    for (final column in _selectedColumns) {
      if (!query.toLowerCase().contains(column.toLowerCase())) {
        setState(() {
          _queryError = 'Selected column "$column" is not used in the query';
        });
        return;
      }
    }

    setState(() {
      _queryError = null;
    });
  }

  Future<void> _executeQuery() async {
    if (_queryError != null) return;

    setState(() {
      _isExecuting = true;
      _queryResult = null;
    });

    try {
      final query = _queryController.text.trim();
      
      // Extract table name, handling quotes and special characters
      String tableName;
      if (query.contains('from "') || query.contains("from '")) {
        final quote = query.contains('from "') ? '"' : "'";
        tableName = query.split('from $quote')[1].split(quote)[0];
      } else {
        tableName = query.split('from')[1].trim();
      }
      
      // Find the matching sheet
      ExcelFile? targetFile;
      String? targetSheet;
      
      // Print available sheets for debugging
      print('Searching for table: $tableName');
      print('Available files and sheets:');
      for (final file in _selectedFiles) {
        final fileName = file.file.path.split('/').last.replaceAll('.xlsx', '').replaceAll('.xls', '');
        print('File: $fileName');
        for (final sheet in file.sheets) {
          print('- $sheet');
        }
      }
      
      // Check if table name contains file name
      for (final file in _selectedFiles) {
        final fileName = file.file.path.split('/').last.replaceAll('.xlsx', '').replaceAll('.xls', '');
        final normalizedFileName = fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final normalizedTableName = tableName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        
        if (normalizedTableName.contains(normalizedFileName)) {
          // If file name matches, look for sheet in this file
          for (final sheet in file.sheets) {
            final normalizedSheetName = sheet.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            if (normalizedTableName.endsWith(normalizedSheetName)) {
              targetFile = file;
              targetSheet = sheet;
              break;
            }
          }
        }
        if (targetFile != null) break;
      }

      if (targetFile == null || targetSheet == null) {
        final availableTables = _selectedFiles.map((file) {
          final fileName = file.file.path.split('/').last.replaceAll('.xlsx', '').replaceAll('.xls', '');
          return file.sheets.map((sheet) => '$fileName.$sheet').join(', ');
        }).join(', ');
        throw Exception('Table "$tableName" not found. Available tables: $availableTables');
      }

      final columns = targetFile.sheetColumns[targetSheet]!;
      final data = targetFile.sheetData[targetSheet]!;

      // Extract selected columns from query
      List<String> resultColumns;
      if (query.contains('select *')) {
        resultColumns = columns;
      } else {
        final selectPart = query.split('from')[0].replaceAll('select', '').trim();
        resultColumns = selectPart.split(',').map((col) => col.trim()).toList();
      }

      // Extract WHERE clause if present
      String? whereClause;
      if (query.toLowerCase().contains('where')) {
        whereClause = query.split('where')[1].trim();
      }

      // Filter data based on WHERE clause
      List<List<dynamic>> filteredData = data;
      if (whereClause != null) {
        filteredData = _applyWhereClause(data, columns, whereClause);
      }

      final result = QueryResult(
        columns: resultColumns,
        rows: filteredData.map((row) {
          final resultRow = <dynamic>[];
          for (final column in resultColumns) {
            final index = columns.indexOf(column);
            if (index != -1 && index < row.length) {
              resultRow.add(row[index]);
            } else {
              resultRow.add(null);
            }
          }
          return resultRow;
        }).toList(),
      );

      setState(() {
        _queryResult = result;
        _isExecuting = false;
        // Add to history
        _queryHistory.insert(0, QueryHistory(
          query: query,
          timestamp: DateTime.now(),
          success: true,
        ));
        _saveQueryHistory();
      });
    } catch (e) {
      setState(() {
        _queryError = 'Error executing query: $e';
        _isExecuting = false;
        // Add failed query to history
        _queryHistory.insert(0, QueryHistory(
          query: _queryController.text.trim(),
          timestamp: DateTime.now(),
          success: false,
        ));
        _saveQueryHistory();
      });
    }
  }

  List<List<dynamic>> _applyWhereClause(List<List<dynamic>> data, List<String> columns, String whereClause) {
    // Split the where clause into conditions
    final conditions = whereClause.split('and').map((c) => c.trim()).toList();
    
    return data.where((row) {
      // Check each condition
      for (final condition in conditions) {
        // Parse the condition
        final parts = condition.split(RegExp(r'[=<>!]+'));
        if (parts.length != 2) continue;
        
        final column = parts[0].trim();
        final value = parts[1].trim().replaceAll("'", '').replaceAll('"', '');
        final operator = condition.substring(parts[0].length, condition.length - parts[1].length).trim();
        
        // Find the column index
        final columnIndex = columns.indexOf(column);
        if (columnIndex == -1) continue;
        
        // Get the cell value
        final cellValue = row[columnIndex]?.toString() ?? '';
        
        // Apply the condition
        bool conditionMet = false;
        switch (operator) {
          case '=':
            conditionMet = cellValue == value;
            break;
          case '!=':
            conditionMet = cellValue != value;
            break;
          case '>':
            conditionMet = _compareValues(cellValue, value) > 0;
            break;
          case '<':
            conditionMet = _compareValues(cellValue, value) < 0;
            break;
          case '>=':
            conditionMet = _compareValues(cellValue, value) >= 0;
            break;
          case '<=':
            conditionMet = _compareValues(cellValue, value) <= 0;
            break;
        }
        
        if (!conditionMet) return false;
      }
      return true;
    }).toList();
  }

  int _compareValues(String a, String b) {
    // Try to compare as numbers
    final numA = num.tryParse(a);
    final numB = num.tryParse(b);
    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }
    // Fall back to string comparison
    return a.compareTo(b);
  }

  Future<void> _loadQueryHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('query_history') ?? [];
    setState(() {
      _queryHistory = historyJson.map((json) {
        try {
          final Map<String, dynamic> jsonMap = jsonDecode(json);
          return QueryHistory.fromJson(jsonMap);
        } catch (e) {
          print('Error parsing query history: $e');
          return null;
        }
      }).whereType<QueryHistory>().toList();
    });
  }

  Future<void> _saveQueryHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep only the last 10 queries
    final recentHistory = _queryHistory.take(10).toList();
    final historyJson = recentHistory
        .map((history) => jsonEncode(history.toJson()))
        .toList();
    await prefs.setStringList('query_history', historyJson);
  }

  Future<void> _toggleFavorite(QueryHistory history) async {
    setState(() {
      final index = _queryHistory.indexOf(history);
      if (index != -1) {
        _queryHistory[index] = QueryHistory(
          query: history.query,
          timestamp: history.timestamp,
          success: history.success,
          isFavorite: !history.isFavorite,
        );
        _saveQueryHistory();
      }
    });
  }

  void _loadQueryFromHistory(QueryHistory history) {
    setState(() {
      _queryController.text = history.query;
      _queryError = null;
      _queryResult = null;
      _showHistory = false;
      _showFavorites = false;
    });
  }

  Future<void> _deleteQuery(QueryHistory history) async {
    setState(() {
      _queryHistory.remove(history);
      _saveQueryHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel Query'),
        actions: [
          IconButton(
            icon: Icon(_showHistory ? Icons.history : Icons.history_outlined),
            onPressed: () {
              setState(() {
                _showHistory = !_showHistory;
                if (_showHistory) _showFavorites = false;
              });
            },
          ),
          IconButton(
            icon: Icon(_showFavorites ? Icons.star : Icons.star_outline),
            onPressed: () {
              setState(() {
                _showFavorites = !_showFavorites;
                if (_showFavorites) _showHistory = false;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickFiles,
              icon: const Icon(Icons.add),
              label: const Text('Add Files'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_selectedFiles.isEmpty)
              const Center(
                child: Text(
                  'No files selected. Click "Add Files" to upload Excel files.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showHistory || _showFavorites) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _showFavorites ? 'Favorite Queries' : 'Query History',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          if (_showFavorites) {
                                            _queryHistory = _queryHistory
                                                .where((h) => !h.isFavorite)
                                                .toList();
                                          } else {
                                            _queryHistory.clear();
                                          }
                                          _saveQueryHistory();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if ((_showFavorites
                                        ? _queryHistory.where((h) => h.isFavorite)
                                        : _queryHistory)
                                    .isEmpty)
                                  const Center(
                                    child: Text('No queries found'),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _showFavorites
                                        ? _queryHistory.where((h) => h.isFavorite).length
                                        : _queryHistory.length,
                                    itemBuilder: (context, index) {
                                      final history = _showFavorites
                                          ? _queryHistory.where((h) => h.isFavorite).toList()[index]
                                          : _queryHistory[index];
                                      return ListTile(
                                        leading: Icon(
                                          history.success ? Icons.check_circle : Icons.error,
                                          color: history.success ? Colors.green : Colors.red,
                                        ),
                                        title: Text(
                                          history.query,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '${history.timestamp.hour}:${history.timestamp.minute} - ${history.timestamp.day}/${history.timestamp.month}/${history.timestamp.year}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                history.isFavorite
                                                    ? Icons.star
                                                    : Icons.star_outline,
                                                color: history.isFavorite ? Colors.amber : null,
                                                size: 16,
                                              ),
                                              onPressed: () => _toggleFavorite(history),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.replay, size: 16),
                                              onPressed: () => _loadQueryFromHistory(history),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, size: 16),
                                              onPressed: () => _deleteQuery(history),
                                              color: Colors.red,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Files (${_selectedFiles.length}):',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _selectedFiles.length,
                                itemBuilder: (context, index) {
                                  final excelFile = _selectedFiles[index];
                                  return ExpansionTile(
                                    leading: const Icon(Icons.file_present),
                                    title: Text(excelFile.file.path.split('/').last),
                                    children: excelFile.sheets.map((sheetName) {
                                      return ListTile(
                                        leading: const Icon(Icons.table_chart),
                                        title: Text(sheetName),
                                        subtitle: Text(
                                          'Columns: ${excelFile.sheetColumns[sheetName]?.length ?? 0}',
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Available Columns (${_availableColumns.length}):',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  TextButton.icon(
                                    onPressed: _toggleSelectAllColumns,
                                    icon: Icon(_selectAllColumns ? Icons.check_box : Icons.check_box_outline_blank),
                                    label: Text(_selectAllColumns ? 'Deselect All' : 'Select All'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _availableColumns.length,
                                itemBuilder: (context, index) {
                                  final column = _availableColumns.elementAt(index);
                                  return CheckboxListTile(
                                    value: _selectedColumns.contains(column),
                                    onChanged: (bool? value) {
                                      _toggleColumnSelection(column);
                                    },
                                    title: Text(column),
                                    secondary: const Icon(Icons.view_column),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Selected Columns: ${_selectedColumns.length}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Query Builder:',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _queryController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Enter your SQL-like query (e.g., SELECT * FROM ...)',
                                  border: const OutlineInputBorder(),
                                  errorText: _queryError,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _validateQuery,
                                    icon: const Icon(Icons.check),
                                    label: const Text('Validate Query'),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _isExecuting ? null : _executeQuery,
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Execute Query'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isExecuting)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_queryResult != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Query Results:',
                                        style: Theme.of(context).textTheme.titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AlertSystemScreen(
                                              queryResult: _queryResult,
                                            ),
                                          ),
                                        );
                                      },
                                       label: Text('Send Alerts'),
                                        icon: const Icon(Icons.email),
                                        
                                       )
                                    
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columns: _queryResult!.columns
                                          .map((column) => DataColumn(label: Text(column)))
                                          .toList(),
                                      rows: _queryResult!.rows
                                          .map((row) => DataRow(
                                                cells: row
                                                    .map((cell) => DataCell(Text(
                                                        cell?.toString() ?? 'null')))
                                                    .toList(),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 