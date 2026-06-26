# Student Management API

Backend REST API for the Student Management application. It includes
JWT authentication, role authorization, students, departments, attendance,
personal notes, and personal tasks.

## Requirements

- Node.js 20.19 or newer
- MongoDB

## Setup

1. Install packages:

   ```bash
   npm install
   ```

2. Create `.env` from `.env.example` and set `MONGO_URI` and `JWT_SECRET`.

3. Migrate legacy student department names to department IDs when upgrading
   an existing database:

   ```bash
   npm run migrate-departments
   ```

4. Create the first admin account:

   ```bash
   npm run create-admin
   ```

   Create staff accounts for teachers or office users when needed:

   ```bash
   npm run create-staff
   ```

5. Start the API:

   ```bash
   npm run dev
   ```

The default base URL is `http://localhost:3000`.

## Authentication

Register and login return a short-lived access token and a rotating refresh
token. Send the access token on protected requests:

```http
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json
```

Public registration always creates a `student`. Student accounts can only
access the student profile and attendance that match their email address.
Admins can create staff accounts from the app Account screen. The
`create-admin` and `create-staff` scripts are also available for setup and
maintenance.

## API Routes

| Method | Endpoint | Access | Purpose |
| --- | --- | --- | --- |
| POST | `/api/auth/register` | Public | Register student account |
| POST | `/api/auth/staff` | Admin | Create staff account |
| POST | `/api/auth/login` | Public | Login |
| POST | `/api/auth/refresh` | Public | Rotate refresh token |
| POST | `/api/auth/forgot-password` | Public | Request reset token |
| POST | `/api/auth/reset-password` | Public | Reset password |
| GET | `/api/auth/me` | Authenticated | Current user |
| PUT | `/api/auth/profile` | Authenticated | Update profile |
| PUT | `/api/auth/profile/avatar` | Authenticated | Upload profile image (JPEG/PNG/WebP, max 2 MB) |
| DELETE | `/api/auth/profile/avatar` | Authenticated | Remove profile image |
| GET | `/api/auth/avatar/:userId` | Public | Get profile image |
| PUT | `/api/auth/change-password` | Authenticated | Change password |
| POST | `/api/auth/logout` | Authenticated | Revoke session |
| GET | `/api/users` | Admin | List Admin/Staff/Student accounts |
| PATCH | `/api/users/:id/role` | Admin | Change account role |
| PATCH | `/api/users/:id/status` | Admin | Activate or deactivate account |
| POST | `/api/users/:id/reset-password` | Admin | Reset account password |
| GET | `/api/students` | Authenticated | List/search students |
| POST | `/api/students` | Admin | Create student |
| GET | `/api/students/:id` | Authenticated | Student details |
| GET | `/api/students/:id/overview` | Authenticated | Student attendance, note, and task overview |
| PUT | `/api/students/:id` | Admin | Update student |
| DELETE | `/api/students/:id` | Admin | Delete student |
| GET | `/api/departments` | Authenticated | List departments |
| POST | `/api/departments` | Admin | Create department |
| GET | `/api/departments/:id` | Authenticated | Department details |
| PUT | `/api/departments/:id` | Admin | Update department |
| DELETE | `/api/departments/:id` | Admin | Delete department |
| GET | `/api/classes` | Authenticated | List classes/groups |
| POST | `/api/classes` | Admin | Create class/group |
| GET | `/api/classes/:id` | Authenticated | Class/group details |
| PUT | `/api/classes/:id` | Admin | Update class/group |
| DELETE | `/api/classes/:id` | Admin | Delete class/group |
| GET | `/api/attendances` | Authenticated | List attendance |
| GET | `/api/attendances/summary` | Authenticated | Daily dashboard |
| GET | `/api/attendances/report` | Authenticated | Date-range report |
| POST | `/api/attendances` | Admin | Mark attendance |
| POST | `/api/attendances/bulk` | Admin | Create or update attendance in a batch |
| PUT | `/api/attendances/:id` | Admin | Update attendance |
| DELETE | `/api/attendances/:id` | Admin | Delete attendance |
| GET/POST | `/api/notes` | Authenticated | List/create notes |
| GET/PUT/DELETE | `/api/notes/:id` | Owner/Admin | Manage note |
| GET/POST | `/api/tasks` | Authenticated | List/create tasks |
| GET/PUT/DELETE | `/api/tasks/:id` | Owner/Admin | Manage task |
| GET | `/api/health` | Public | API health |

List routes support `page` and `limit`. Students and departments support
`search`. Users support `role`, `status`, and `search`. Attendance supports
`student`, `classGroup`, `status`, `from`, and `to`. Tasks
support `student`, `status`, `priority`, and `search`.

Attendance dates must use `YYYY-MM-DD`. Summary accepts `date`. Report requires
`from` and `to`, supports an optional `student`, and allows up to 366 days.
Deleting a student or department returns `409` while related records exist.

Interactive-tool-compatible OpenAPI JSON is served at
`http://localhost:3000/api/docs/openapi.json`. A small documentation landing
page is available at `http://localhost:3000/api/docs`.

## Deployment

The repository includes a production `Dockerfile` and a Render Blueprint at
`../render.yaml`. In Render, create a Blueprint from the repository and set:

- `MONGO_URI` to a MongoDB Atlas connection string
- `CORS_ORIGIN` to the deployed client origin, or a comma-separated allowlist

`JWT_SECRET` is generated by the blueprint. The Blueprint uses the free web
service plan in Singapore. Production uses HTTPS, one-hour access tokens,
rotating refresh tokens, and the `/api/health` health check.

## Example Payloads

Create a student:

```json
{
  "studentId": "STU-001",
  "fullName": "Sok Dara",
  "gender": "Male",
  "email": "dara@example.com",
  "phone": "012345678",
  "department": "MONGODB_DEPARTMENT_ID",
  "classGroup": "MONGODB_CLASS_ID",
  "year": 3,
  "createAccount": true,
  "accountPassword": "password123"
}
```

When `createAccount` is `true`, the API creates a `student` login account with
the same email as the student profile. If a student login account already exists
for that email, the profile is created and linked by email.

Create a class/group:

```json
{
  "name": "IT-Y3-A",
  "department": "MONGODB_DEPARTMENT_ID",
  "year": 3,
  "shift": "Morning",
  "description": "Year 3 IT morning class"
}
```

Mark attendance:

```json
{
  "student": "MONGODB_STUDENT_ID",
  "date": "2026-06-13",
  "status": "present",
  "note": ""
}
```

Create a task:

```json
{
  "title": "Finish mobile UI",
  "description": "Complete the attendance screen",
  "dueDate": "2026-06-20",
  "priority": "high",
  "status": "pending"
}
```

## Verification

```bash
npm run check
npm test
npm run test:integration
```
