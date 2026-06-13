# Student Management Flutter App

Flutter client for the Student Management REST API in `../backend`.

## Features

- Login, registration, rotating access/refresh sessions, logout, and reset
- Encrypted Android session storage backed by Android Keystore
- Provider state management
- Named authentication routing and bottom navigation
- Dashboard with student and attendance summaries
- Student and department management for administrators
- Student details and date-range attendance reports with charts
- Daily attendance marking and summary
- Personal notes linked to students
- Tasks with priority, status, due date, completion, and Android reminders
- Offline read cache for students, attendance, notes, and tasks
- Khmer/English language settings and light/dark themes
- Custom launcher icon and Android/Flutter splash branding
- Android, iOS, Web, and Windows project targets

## Start The Backend

From the `backend` directory:

```bash
npm run dev
```

The API should be available on port `3000`.

## Run Flutter

The app uses the deployed Render backend by default:

```text
https://student-management-api-fqf8.onrender.com
```

To run against a local backend on the Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Windows or Web on the same computer:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000
```

Physical Android/iOS device:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:3000
```

The phone and computer must be on the same network. Allow port `3000` through
the computer firewall when using a physical device.

If Android Studio opened the old project path containing an invisible
character, reopen this clean path:

```text
D:\Norton main folder\software_Development\Year3\Semerter2\Advance Mobile App\StudentManagementSystem\student_management_app
```

## Roles

Public registration creates a normal `user`. Normal users can view students
and attendance and manage their own notes and tasks. Administrators can also
create, update, and delete departments, students, and attendance records.

Create or reset an administrator from the backend:

```bash
npm run create-admin
```

## Verification

```bash
flutter analyze
flutter test
```

## Android Release

Copy `android/key.properties.example` to `android/key.properties`, create a
keystore, and replace the sample values. Without that file, local release
builds fall back to the debug key for development.

Build against a deployed HTTPS backend:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Release builds reject cleartext HTTP. Debug builds keep HTTP enabled for the
Android emulator at `10.0.2.2`.
