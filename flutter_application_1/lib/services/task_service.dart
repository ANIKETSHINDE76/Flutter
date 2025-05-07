import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/models/task.dart';

class TaskService {
  final _supabase = Supabase.instance.client;

  Future<Task?> getCurrentTask() async {
    final response = await _supabase
        .from('tasks')
        .select()
        .eq('is_completed', false)
        .order('priority', ascending: false)
        .order('due_date', ascending: true)
        .limit(1)
        .single();
    return Task.fromJson(response);
  }

  Future<Task> createTask({
    required String name,
    String? description,
    required TaskPriority priority,
    required DateTime dueDate,
    required Duration estimatedDuration,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    
    final response = await _supabase.from('tasks').insert({
      'name': name,
      'description': description,
      'priority': priority.toString().split('.').last,
      'due_date': dueDate.toIso8601String(),
      'estimated_duration': estimatedDuration.inMinutes,
      'is_completed': false,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    return Task.fromJson(response);
  }

  Future<void> completeTask(String taskId) async {
    await _supabase
        .from('tasks')
        .update({'is_completed': true})
        .eq('id', taskId);
  }

  Future<List<Task>> getCompletedTasks() async {
    final response = await _supabase
        .from('tasks')
        .select()
        .eq('is_completed', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();
  }
} 