import 'package:flutter/material.dart';
import '../services/email_service.dart';
import '../models/student_data.dart';
import '../config/email_config.dart';
import 'excel_query_screen.dart';
import 'email_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AlertSystemScreen extends StatefulWidget {
  final QueryResult? queryResult;

  const AlertSystemScreen({Key? key, this.queryResult}) : super(key: key);

  @override
  State<AlertSystemScreen> createState() => _AlertSystemScreenState();
}

class EmailTemplate {
  final String subject;
  final String message;
  final DateTime timestamp;
  final bool isFavorite;

  EmailTemplate({
    required this.subject,
    required this.message,
    required this.timestamp,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory EmailTemplate.fromJson(Map<String, dynamic> json) => EmailTemplate(
    subject: json['subject'],
    message: json['message'],
    timestamp: DateTime.parse(json['timestamp']),
    isFavorite: json['isFavorite'] ?? false,
  );
}

class _AlertSystemScreenState extends State<AlertSystemScreen> {
  final _emailService = EmailService();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;
  String? _error;
  List<EmailSendResult> _sendResults = [];
  bool _isConfigured = false;
  List<EmailTemplate> _savedTemplates = [];
  String? _selectedTemplate;
  double _sendingProgress = 0.0;
  bool _isCancelled = false;
  int _totalEmails = 0;
  int _sentEmails = 0;
  bool _showTemplates = false;
  bool _showFavoriteTemplates = false;

  @override
  void initState() {
    super.initState();
    _checkEmailConfiguration();
    _loadSavedTemplates();
  }

  Future<void> _loadSavedTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = prefs.getStringList('email_templates') ?? [];
    setState(() {
      _savedTemplates = templatesJson.map((json) {
        try {
          final Map<String, dynamic> jsonMap = jsonDecode(json);
          return EmailTemplate.fromJson(jsonMap);
        } catch (e) {
          print('Error parsing email template: $e');
          return null;
        }
      }).whereType<EmailTemplate>().toList();
    });
  }

  Future<void> _saveTemplate() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) {
      setState(() {
        _error = 'Please enter both subject and message before saving';
      });
      return;
    }

    final template = EmailTemplate(
      subject: _subjectController.text,
      message: _messageController.text,
      timestamp: DateTime.now(),
    );

    final prefs = await SharedPreferences.getInstance();
    final templates = _savedTemplates;
    templates.insert(0, template);
    // Keep only the last 10 templates
    final recentTemplates = templates.take(10).toList();
    final templatesJson = recentTemplates
        .map((template) => jsonEncode(template.toJson()))
        .toList();
    await prefs.setStringList('email_templates', templatesJson);

    setState(() {
      _savedTemplates = recentTemplates;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template saved successfully')),
      );
    }
  }

  Future<void> _toggleTemplateFavorite(EmailTemplate template) async {
    setState(() {
      final index = _savedTemplates.indexOf(template);
      if (index != -1) {
        _savedTemplates[index] = EmailTemplate(
          subject: template.subject,
          message: template.message,
          timestamp: template.timestamp,
          isFavorite: !template.isFavorite,
        );
        _saveTemplates();
      }
    });
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = _savedTemplates
        .map((template) => jsonEncode(template.toJson()))
        .toList();
    await prefs.setStringList('email_templates', templatesJson);
  }

  void _loadTemplate(EmailTemplate template) {
    setState(() {
      _subjectController.text = template.subject;
      _messageController.text = template.message;
      _selectedTemplate = jsonEncode(template.toJson());
      _showTemplates = false;
      _showFavoriteTemplates = false;
    });
  }

  Future<void> _deleteTemplate(EmailTemplate template) async {
    setState(() {
      _savedTemplates.remove(template);
      _saveTemplates();
    });
  }

  Future<void> _checkEmailConfiguration() async {
    try {
      final username = await EmailConfig.username;
      final password = await EmailConfig.password;
      final smtpHost = await EmailConfig.smtpHost;
      final smtpPort = await EmailConfig.smtpPort;
      final senderName = await EmailConfig.senderName;

      if (username.isNotEmpty && password.isNotEmpty) {
        _emailService.configure(
          smtpServer: smtpHost,
          smtpUsername: username,
          smtpPassword: password,
          fromEmail: senderName,
        );
        setState(() {
          _isConfigured = true;
        });
      } else {
        setState(() {
          _error = 'Email settings not configured. Please configure email settings first.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error checking email configuration: $e';
      });
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendEmails() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter subject and message')),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _sendingProgress = 0.0;
      _isCancelled = false;
      _totalEmails = widget.queryResult!.rows.length;
      _sentEmails = 0;
    });

    try {
      // Find email column
      final emailColumnIndex = widget.queryResult!.columns.indexWhere(
        (col) => col.toLowerCase().contains('email'),
      );

      if (emailColumnIndex == -1) {
        throw Exception('No email column found in the results');
      }

      // Prepare messages for each recipient
      final messages = widget.queryResult!.rows.map((row) {
        String message = _messageController.text;
        String subject = _subjectController.text;
        
        // Replace column placeholders with actual values in both subject and message
        for (var i = 0; i < widget.queryResult!.columns.length; i++) {
          final columnName = widget.queryResult!.columns[i];
          final value = row[i]?.toString() ?? '';
          message = message.replaceAll('{$columnName}', value);
          subject = subject.replaceAll('{$columnName}', value);
        }
        return {'subject': subject, 'message': message};
      }).toList();

      // Send emails
      final results = await _emailService.sendBulkEmails(
        students: widget.queryResult!.rows.map((row) {
          return StudentData(
            name: row[0]?.toString() ?? 'Unknown',
            email: row[emailColumnIndex]?.toString() ?? '',
            attendancePercentage: 0.0,
          );
        }).toList(),
        subject: messages.map((m) => m['subject']!).toList(),
        messageTemplates: messages.map((m) => m['message']!).toList(),
        onProgress: (current, total) {
          if (!_isCancelled) {
            setState(() {
              _sentEmails = current;
              _sendingProgress = current / total;
            });
          }
        },
      );

      if (!_isCancelled) {
        final successCount = results.where((r) => r.success).length;
        final failureCount = results.length - successCount;

        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                'Emails sent: $successCount successful, $failureCount failed',
              ),
          ),
        );
        }
      }
    } catch (e) {
      if (!_isCancelled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending emails: $e')),
        );
      }
    } finally {
      if (mounted) {
    setState(() {
          _isSending = false;
          _sendingProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert System'),
        actions: [
          IconButton(
            icon: Icon(_showTemplates ? Icons.history : Icons.history_outlined),
            onPressed: () {
              setState(() {
                _showTemplates = !_showTemplates;
                if (_showTemplates) _showFavoriteTemplates = false;
              });
            },
          ),
          IconButton(
            icon: Icon(_showFavoriteTemplates ? Icons.star : Icons.star_outline),
            onPressed: () {
              setState(() {
                _showFavoriteTemplates = !_showFavoriteTemplates;
                if (_showFavoriteTemplates) _showTemplates = false;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmailSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isSending
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Sending Emails...',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: _sendingProgress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$_sentEmails of $_totalEmails emails sent',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isCancelled = true;
                      });
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            if (_showTemplates || _showFavoriteTemplates) ...[
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
                            _showFavoriteTemplates ? 'Favorite Templates' : 'Template History',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                if (_showFavoriteTemplates) {
                                  _savedTemplates = _savedTemplates
                                      .where((t) => !t.isFavorite)
                                      .toList();
                                } else {
                                  _savedTemplates.clear();
                                }
                                _saveTemplates();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if ((_showFavoriteTemplates
                              ? _savedTemplates.where((t) => t.isFavorite)
                              : _savedTemplates)
                          .isEmpty)
                        const Center(
                          child: Text('No templates found'),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _showFavoriteTemplates
                              ? _savedTemplates.where((t) => t.isFavorite).length
                              : _savedTemplates.length,
                          itemBuilder: (context, index) {
                            final template = _showFavoriteTemplates
                                ? _savedTemplates.where((t) => t.isFavorite).toList()[index]
                                : _savedTemplates[index];
                            return ListTile(
                              leading: Icon(
                                Icons.email,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Text(
                                template.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${template.timestamp.hour}:${template.timestamp.minute} - ${template.timestamp.day}/${template.timestamp.month}/${template.timestamp.year}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      template.isFavorite
                                          ? Icons.star
                                          : Icons.star_outline,
                                      color: template.isFavorite ? Colors.amber : null,
                                      size: 16,
                                    ),
                                    onPressed: () => _toggleTemplateFavorite(template),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.replay, size: 16),
                                    onPressed: () => _loadTemplate(template),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 16),
                                    onPressed: () => _deleteTemplate(template),
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
            if (!_isConfigured)
                Card(
                color: Colors.orange.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                        'Email settings not configured',
                          style: TextStyle(
                          color: Colors.orange,
                            fontWeight: FontWeight.bold,
                        ),
                          ),
                        const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmailSettingsScreen(),
                            ),
                          );
                        },
                        child: const Text('Configure Email Settings'),
                          ),
                      ],
                    ),
                  ),
              )
            else if (widget.queryResult == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No query results available. Please run a query in the Excel Query screen first.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Query Results Summary:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Columns: ${widget.queryResult!.columns.join(', ')}'),
                      Text('Rows: ${widget.queryResult!.rows.length}'),
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
                          Flexible(
                            child: Text(
                              'Message Template:',
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_savedTemplates.isNotEmpty)
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.4,
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedTemplate,
                                  hint: const Text('Load Template'),
                                  isDense: true,
                                  isExpanded: true,
                                  items: _savedTemplates.map((template) {
                                    return DropdownMenuItem<String>(
                                      value: jsonEncode(template.toJson()),
                                      child: Text(
                                        template.subject,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _loadTemplate(EmailTemplate.fromJson(jsonDecode(value)));
                                    }
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Email Subject',
                          hintText: 'Enter email subject with {column_name} placeholders',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.3,
                        ),
                        child: SingleChildScrollView(
                          child: TextField(
                            controller: _messageController,
                            maxLines: null,
                            decoration: InputDecoration(
                              labelText: 'Message Template',
                              hintText: 'Enter message template with {column_name} placeholders',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        ),
                        const SizedBox(height: 8),
                      Text(
                        'Available columns: ${widget.queryResult!.columns.map((c) => '{$c}').join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _saveTemplate,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Template'),
                        ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              if (_error != null)
                Card(
                  color: Colors.red.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              if (_sendResults.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        Text(
                          'Send Results:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _sendResults.length,
                          itemBuilder: (context, index) {
                            final result = _sendResults[index];
                            return ListTile(
                              leading: Icon(
                                result.success ? Icons.check_circle : Icons.error,
                                color: result.success ? Colors.green : Colors.red,
                              ),
                              title: Text(result.email),
                              subtitle: result.error != null
                                  ? Text(result.error!)
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
                  const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _sendEmails,
                icon: const Icon(Icons.send),
                label: Text('Send Emails'),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 