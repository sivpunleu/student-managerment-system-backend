import 'department.dart';

class Student {
  const Student({
    required this.id,
    required this.studentId,
    required this.fullName,
    required this.email,
    required this.department,
    this.gender,
    this.phone,
    this.year,
  });

  final String id;
  final String studentId;
  final String fullName;
  final String email;
  final Department department;
  final String? gender;
  final String? phone;
  final int? year;

  factory Student.fromJson(Map<String, dynamic> json) {
    final rawDepartment = json['department'];
    final department = rawDepartment is Map<String, dynamic>
        ? Department.fromJson(rawDepartment)
        : Department(
            id: rawDepartment?.toString() ?? '',
            name: rawDepartment?.toString() ?? 'Unknown',
          );

    return Student(
      id: json['_id']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      department: department,
      gender: json['gender']?.toString(),
      phone: json['phone']?.toString(),
      year: json['year'] is num ? (json['year'] as num).toInt() : null,
    );
  }
}
