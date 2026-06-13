import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/department.dart';
import '../models/student.dart';
import '../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/state_views.dart';
import 'student_form_screen.dart';
import 'student_details_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchController = TextEditingController();
  String? _departmentFilter;
  int? _yearFilter;
  String? _genderFilter;
  String _sort = 'name';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<StudentProvider>().load(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm([Student? student]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentFormScreen(student: student)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final students = _visibleStudents(provider.students);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add student'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Student directory',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${students.length} of ${provider.students.length} students',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      IconButton.filledTonal(
                        tooltip: 'Manage departments',
                        onPressed: () => _showDepartments(context),
                        icon: const Icon(Icons.apartment_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search ID, name, or email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              provider.load();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) => provider.load(search: value.trim()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showFilters(provider),
                        icon: const Icon(Icons.filter_list_rounded),
                        label: Text(
                          _activeFilterCount == 0
                              ? 'Filters'
                              : 'Filters ($_activeFilterCount)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PopupMenuButton<String>(
                        initialValue: _sort,
                        onSelected: (value) => setState(() => _sort = value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'name', child: Text('Name A-Z')),
                          PopupMenuItem(
                            value: 'studentId',
                            child: Text('Student ID'),
                          ),
                          PopupMenuItem(
                            value: 'year',
                            child: Text('Study year'),
                          ),
                        ],
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sort_rounded),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _sort == 'name'
                                      ? 'Name A-Z'
                                      : _sort == 'studentId'
                                      ? 'Student ID'
                                      : 'Study year',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent(provider, isAdmin, students)),
        ],
      ),
    );
  }

  int get _activeFilterCount =>
      (_departmentFilter == null ? 0 : 1) +
      (_yearFilter == null ? 0 : 1) +
      (_genderFilter == null ? 0 : 1);

  List<Student> _visibleStudents(List<Student> source) {
    final query = _searchController.text.trim().toLowerCase();
    final students = source.where((student) {
      final matchesSearch =
          query.isEmpty ||
          student.fullName.toLowerCase().contains(query) ||
          student.studentId.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query);
      return matchesSearch &&
          (_departmentFilter == null ||
              student.department.id == _departmentFilter) &&
          (_yearFilter == null || student.year == _yearFilter) &&
          (_genderFilter == null || student.gender == _genderFilter);
    }).toList();

    students.sort((a, b) {
      if (_sort == 'studentId') {
        return a.studentId.compareTo(b.studentId);
      }
      if (_sort == 'year') {
        final yearCompare = (a.year ?? 99).compareTo(b.year ?? 99);
        return yearCompare != 0
            ? yearCompare
            : a.fullName.compareTo(b.fullName);
      }
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return students;
  }

  Widget _buildContent(
    StudentProvider provider,
    bool isAdmin,
    List<Student> students,
  ) {
    if (provider.isLoading && provider.students.isEmpty) {
      return const LoadingView(label: 'Loading students...');
    }

    if (provider.error != null && provider.students.isEmpty) {
      return ErrorPanel(
        message: provider.error!,
        onRetry: () => provider.load(search: _searchController.text.trim()),
      );
    }

    if (provider.students.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'No students found',
        message: 'Create a student or try another search.',
      );
    }

    if (students.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search_outlined,
        title: 'No matching students',
        message: 'Change the search text or clear one of the filters.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.load(search: _searchController.text.trim()),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: students.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final student = students[index];

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentDetailsScreen(student: student),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.18),
                            AppColors.cyan.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Center(
                        child: Text(
                          student.fullName.isEmpty
                              ? '?'
                              : student.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${student.studentId} - ${student.email}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            children: [
                              StatusPill(
                                label: student.department.name,
                                color: AppColors.primary,
                              ),
                              if (student.year != null)
                                StatusPill(
                                  label: 'Year ${student.year}',
                                  color: AppColors.success,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openForm(student);
                          } else if (value == 'delete') {
                            _deleteStudent(student);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.delete_outline),
                              title: Text('Delete'),
                            ),
                          ),
                        ],
                      )
                    else
                      const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showFilters(StudentProvider provider) async {
    var department = _departmentFilter ?? '';
    var year = _yearFilter ?? 0;
    var gender = _genderFilter ?? '';

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter students',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        department = '';
                        year = 0;
                        gender = '';
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: department,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All departments'),
                    ),
                    ...provider.departments.map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => department = value ?? ''),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: year,
                        decoration: const InputDecoration(
                          labelText: 'Study year',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('All years'),
                          ),
                          ...List.generate(
                            6,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('Year ${index + 1}'),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => year = value ?? 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('All genders'),
                          ),
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => gender = value ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Apply filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (apply == true && mounted) {
      setState(() {
        _departmentFilter = department.isEmpty ? null : department;
        _yearFilter = year == 0 ? null : year;
        _genderFilter = gender.isEmpty ? null : gender;
      });
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text(
          'Delete ${student.fullName}? Students with attendance, notes, or '
          'tasks cannot be deleted.',
        ),
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

    if (confirmed != true || !mounted) {
      return;
    }

    final provider = context.read<StudentProvider>();
    final success = await provider.deleteStudent(student.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Student deleted' : provider.error ?? 'Delete failed',
          ),
        ),
      );
    }
  }

  Future<void> _showDepartments(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DepartmentSheet(),
    );
  }
}

class _DepartmentSheet extends StatelessWidget {
  const _DepartmentSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Departments',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _addDepartment(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: provider.departments.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final department = provider.departments[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.apartment, size: 20),
                      ),
                      title: Text(department.name),
                      subtitle: department.description.isEmpty
                          ? null
                          : Text(department.description),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _deleteDepartment(context, department),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                ),
              ),
              if (provider.isLoading) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addDepartment(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (shouldSave != true || nameController.text.trim().length < 2) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final provider = context.read<StudentProvider>();
    final success = await provider.createDepartment(
      name: nameController.text,
      description: descriptionController.text,
    );

    if (context.mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Could not create department'),
        ),
      );
    }
  }

  Future<void> _deleteDepartment(
    BuildContext context,
    Department department,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete department?'),
        content: Text(
          'Delete ${department.name}? It cannot be deleted while students '
          'are assigned to it.',
        ),
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

    if (confirmed != true || !context.mounted) {
      return;
    }

    final provider = context.read<StudentProvider>();
    final success = await provider.deleteDepartment(department.id);

    if (context.mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Could not delete department'),
        ),
      );
    }
  }
}
