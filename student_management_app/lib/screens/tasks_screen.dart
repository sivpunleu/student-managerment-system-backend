import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/date_utils.dart';
import '../models/student.dart';
import '../models/task_item.dart';
import '../providers/student_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/state_views.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<TaskProvider>().load();
      if (mounted && context.read<StudentProvider>().students.isEmpty) {
        await context.read<StudentProvider>().load();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final tasks = provider.tasks.where((task) {
      final matchesSearch =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query) ||
          (task.studentName?.toLowerCase().contains(query) ?? false);
      final matchesFilter = switch (_filter) {
        'overdue' => task.isOverdue,
        'today' => task.isDueToday,
        'all' => true,
        _ => task.status == _filter,
      };
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTask(),
        icon: const Icon(Icons.add_task),
        label: const Text('Add task'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
            child: Column(
              children: [
                AppSectionHeader(
                  title: 'Task planner',
                  subtitle:
                      '${provider.tasks.where((task) => !task.isCompleted).length} tasks need attention',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search task, description, or student',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onSelected: () => setState(() => _filter = 'all'),
                ),
                _FilterChip(
                  label: 'Pending',
                  selected: _filter == 'pending',
                  onSelected: () => setState(() => _filter = 'pending'),
                ),
                _FilterChip(
                  label: 'In progress',
                  selected: _filter == 'in-progress',
                  onSelected: () => setState(() => _filter = 'in-progress'),
                ),
                _FilterChip(
                  label: 'Overdue',
                  selected: _filter == 'overdue',
                  onSelected: () => setState(() => _filter = 'overdue'),
                ),
                _FilterChip(
                  label: 'Due today',
                  selected: _filter == 'today',
                  onSelected: () => setState(() => _filter = 'today'),
                ),
                _FilterChip(
                  label: 'Completed',
                  selected: _filter == 'completed',
                  onSelected: () => setState(() => _filter = 'completed'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent(provider, tasks)),
        ],
      ),
    );
  }

  Widget _buildContent(TaskProvider provider, List<TaskItem> tasks) {
    if (provider.isLoading && provider.tasks.isEmpty) {
      return const LoadingView(label: 'Loading tasks...');
    }

    if (provider.error != null && provider.tasks.isEmpty) {
      return ErrorPanel(message: provider.error!, onRetry: provider.load);
    }

    if (tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt_outlined,
        title: 'No tasks found',
        message: 'Create a task or change the selected filter.',
      );
    }

    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final task = tasks[index];
          final priorityColor = switch (task.priority) {
            'high' => Colors.red,
            'low' => Colors.green,
            _ => Colors.orange,
          };

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _editTask(task),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? AppColors.success.withValues(alpha: 0.1)
                            : priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Checkbox(
                        value: task.isCompleted,
                        onChanged: (_) => provider.toggleCompleted(task),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isCompleted
                                      ? Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.color
                                      : null,
                                ),
                          ),
                          if (task.description.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              task.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            children: [
                              StatusPill(
                                label: task.priority.toUpperCase(),
                                color: priorityColor,
                              ),
                              StatusPill(
                                label: task.isCompleted
                                    ? 'COMPLETED'
                                    : task.isOverdue
                                    ? 'OVERDUE'
                                    : task.isDueToday
                                    ? 'DUE TODAY'
                                    : formatDisplayDate(task.dueDate),
                                color: task.isCompleted
                                    ? AppColors.success
                                    : task.isOverdue
                                    ? AppColors.danger
                                    : task.isDueToday
                                    ? AppColors.warning
                                    : AppColors.primary,
                                icon: task.isCompleted
                                    ? Icons.check_rounded
                                    : task.isOverdue
                                    ? Icons.warning_amber_rounded
                                    : Icons.event_rounded,
                              ),
                              if (task.studentName != null)
                                StatusPill(
                                  label: task.studentName!,
                                  color: const Color(0xFF8B5CF6),
                                  icon: Icons.person_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editTask(task);
                        } else if (value == 'delete') {
                          _deleteTask(task);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editTask([TaskItem? task]) async {
    final result = await showDialog<_TaskInput>(
      context: context,
      builder: (_) => _TaskDialog(
        task: task,
        students: context.read<StudentProvider>().students,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final provider = context.read<TaskProvider>();
    final success = await provider.save(
      id: task?.id,
      title: result.title,
      description: result.description,
      priority: result.priority,
      status: result.status,
      dueDate: result.dueDate,
      studentId: result.studentId,
    );

    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Could not save task')),
      );
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<TaskProvider>().delete(task.id);
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _TaskInput {
  const _TaskInput({
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    this.dueDate,
    this.studentId,
  });

  final String title;
  final String description;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final String? studentId;
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.task, required this.students});

  final TaskItem? task;
  final List<Student> students;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _priority;
  late String _status;
  DateTime? _dueDate;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title);
    _descriptionController = TextEditingController(
      text: widget.task?.description,
    );
    _priority = widget.task?.priority ?? 'medium';
    _status = widget.task?.status ?? 'pending';
    _dueDate = widget.task?.dueDate;
    _studentId = widget.task?.studentId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'New task' : 'Edit task'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                      ],
                      onChanged: (value) =>
                          setState(() => _priority = value ?? 'medium'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'in-progress',
                          child: Text('In progress'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'pending'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _studentId,
                decoration: const InputDecoration(
                  labelText: 'Student (optional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No student'),
                  ),
                  ...widget.students.map(
                    (student) => DropdownMenuItem<String?>(
                      value: student.id,
                      child: Text(student.fullName),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _studentId = value),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.event_outlined),
                title: const Text('Due date'),
                subtitle: Text(formatDisplayDate(_dueDate)),
                trailing: _dueDate == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () => setState(() => _dueDate = null),
                        icon: const Icon(Icons.clear),
                      ),
                onTap: _pickDueDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _TaskInput(
                title: _titleController.text,
                description: _descriptionController.text,
                priority: _priority,
                status: _status,
                dueDate: _dueDate,
                studentId: _studentId,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (selected != null) {
      setState(() => _dueDate = selected);
    }
  }
}
