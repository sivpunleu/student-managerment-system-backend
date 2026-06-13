import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student.dart';
import '../providers/student_provider.dart';
import '../widgets/state_views.dart';

class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.student});

  final Student? student;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _studentIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  String? _departmentId;
  String? _gender;
  int? _year;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _studentIdController = TextEditingController(text: student?.studentId);
    _nameController = TextEditingController(text: student?.fullName);
    _emailController = TextEditingController(text: student?.email);
    _phoneController = TextEditingController(text: student?.phone);
    _departmentId = student?.department.id;
    _gender = student?.gender;
    _year = student?.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StudentProvider>();
      if (provider.departments.isEmpty) {
        provider.load();
      }
    });
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<StudentProvider>();
    final success = await provider.saveStudent(
      id: widget.student?.id,
      data: {
        'studentId': _studentIdController.text.trim(),
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _departmentId,
        'gender': _gender,
        'year': _year,
      },
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Could not save student')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final isEditing = widget.student != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit student' : 'New student')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  PageBanner(
                    icon: isEditing
                        ? Icons.manage_accounts_rounded
                        : Icons.person_add_alt_1_rounded,
                    title: isEditing ? 'Update student' : 'Add new student',
                    subtitle: isEditing
                        ? 'Keep this student profile accurate and up to date.'
                        : 'Create a complete academic profile for the student.',
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _studentIdController,
                              decoration: const InputDecoration(
                                labelText: 'Student ID',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) =>
                                  value == null || !value.contains('@')
                                  ? 'Enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                '${provider.departments.length}-$_departmentId',
                              ),
                              initialValue:
                                  provider.departments.any(
                                    (department) =>
                                        department.id == _departmentId,
                                  )
                                  ? _departmentId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Department',
                                prefixIcon: Icon(Icons.apartment),
                              ),
                              items: provider.departments
                                  .map(
                                    (department) => DropdownMenuItem(
                                      value: department.id,
                                      child: Text(department.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _departmentId = value),
                              validator: (value) =>
                                  value == null ? 'Select a department' : null,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _gender,
                                    decoration: const InputDecoration(
                                      labelText: 'Gender',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Male',
                                        child: Text('Male'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Female',
                                        child: Text('Female'),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _gender = value),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _year,
                                    decoration: const InputDecoration(
                                      labelText: 'Year',
                                    ),
                                    items: List.generate(
                                      6,
                                      (index) => DropdownMenuItem(
                                        value: index + 1,
                                        child: Text('Year ${index + 1}'),
                                      ),
                                    ),
                                    onChanged: (value) =>
                                        setState(() => _year = value),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: provider.isLoading ? null : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                isEditing ? 'Save changes' : 'Create student',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? 'This field is required'
        : null;
  }
}
