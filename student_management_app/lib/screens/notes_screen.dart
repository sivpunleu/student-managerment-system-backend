import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/note_item.dart';
import '../models/student.dart';
import '../providers/note_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/state_views.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<NoteProvider>().load();
      if (mounted && context.read<StudentProvider>().students.isEmpty) {
        await context.read<StudentProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NoteProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editNote(),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Add note'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AppSectionHeader(
              title: 'Notes workspace',
              subtitle: '${provider.notes.length} notes saved and organized',
            ),
          ),
          Expanded(child: _buildContent(provider)),
        ],
      ),
    );
  }

  Widget _buildContent(NoteProvider provider) {
    if (provider.isLoading && provider.notes.isEmpty) {
      return const LoadingView(label: 'Loading notes...');
    }

    if (provider.error != null && provider.notes.isEmpty) {
      return ErrorPanel(message: provider.error!, onRetry: provider.load);
    }

    if (provider.notes.isEmpty) {
      return const EmptyState(
        icon: Icons.note_alt_outlined,
        title: 'No notes yet',
        message: 'Create notes for yourself or link one to a student.',
      );
    }

    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: provider.notes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final note = provider.notes[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _editNote(note),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppIconBox(
                      icon: Icons.sticky_note_2_rounded,
                      color: AppColors.warning,
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            note.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (note.studentName != null) ...[
                            const SizedBox(height: 10),
                            StatusPill(
                              label: note.studentName!,
                              color: AppColors.primary,
                              icon: Icons.person_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editNote(note);
                        } else if (value == 'delete') {
                          _deleteNote(note);
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

  Future<void> _editNote([NoteItem? note]) async {
    final result = await showDialog<_NoteInput>(
      context: context,
      builder: (_) => _NoteDialog(
        note: note,
        students: context.read<StudentProvider>().students,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final provider = context.read<NoteProvider>();
    final success = await provider.save(
      id: note?.id,
      title: result.title,
      content: result.content,
      studentId: result.studentId,
    );

    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Could not save note')),
      );
    }
  }

  Future<void> _deleteNote(NoteItem note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('Delete "${note.title}"?'),
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
      await context.read<NoteProvider>().delete(note.id);
    }
  }
}

class _NoteInput {
  const _NoteInput({
    required this.title,
    required this.content,
    this.studentId,
  });

  final String title;
  final String content;
  final String? studentId;
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.note, required this.students});

  final NoteItem? note;
  final List<Student> students;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title);
    _contentController = TextEditingController(text: widget.note?.content);
    _studentId = widget.note?.studentId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? 'New note' : 'Edit note'),
      content: SizedBox(
        width: 460,
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
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                minLines: 4,
                maxLines: 7,
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
            if (_titleController.text.trim().isEmpty ||
                _contentController.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _NoteInput(
                title: _titleController.text,
                content: _contentController.text,
                studentId: _studentId,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
