# Student Management System

This workspace contains:

- `backend/`: Express, MongoDB, and JWT REST API
- `student_management_app/`: Flutter mobile, web, and desktop client

The system includes rotating authentication sessions, encrypted Android
storage, role-based student and attendance management, reports, offline cache,
task reminders, Khmer/English settings, dark mode, API documentation, tests,
and deployment configuration.

## Start The System

Start the backend:

```bash
cd backend
npm run dev
```

Run the Flutter app in another terminal:

```bash
cd student_management_app
flutter run
```

The app uses the deployed Render API by default:

```text
https://student-management-api-fqf8.onrender.com
```

To use a local backend on Android Emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

To use a local backend on Windows or Web:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000
```

See each project's README for setup, roles, API routes, and verification.

## Deploy

`render.yaml` deploys the backend as a Docker web service. Build the Android
release against its HTTPS URL:

Before creating the Render Blueprint:

1. Push this project to a GitHub, GitLab, or Bitbucket repository.
2. Create a MongoDB Atlas database and copy its application connection string.
3. In Render, create a Blueprint from the repository.
4. Enter the Atlas connection string for `MONGO_URI`.
5. Set `CORS_ORIGIN` to `*` for the mobile-only app, or to a comma-separated
   allowlist when a web client is deployed.

The Blueprint uses Render's free web-service plan in the Singapore region.
After deployment, verify `https://YOUR-SERVICE.onrender.com/api/health`.

```bash
cd student_management_app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```
