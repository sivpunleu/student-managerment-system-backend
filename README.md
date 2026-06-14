# Student Management API

Backend repository for the Student Management application.

## Technology

- Node.js and Express
- MongoDB and Mongoose
- JWT access and refresh tokens
- Docker and Render deployment

## Run Locally

```bash
cd backend
npm install
npm run dev
```

The API runs at `http://localhost:3000` by default.

## Verify

```bash
cd backend
npm run check
npm test
npm run test:integration
```

## Deployment

The root [render.yaml](render.yaml) deploys `backend/` as a Docker web service.
Required Render environment variables:

- `MONGO_URI`: MongoDB Atlas connection string
- `CORS_ORIGIN`: `*` for mobile clients, or a comma-separated web allowlist

Production API:

```text
https://student-management-api-fqf8.onrender.com
```

Health check:

```text
https://student-management-api-fqf8.onrender.com/api/health
```

See [backend/README.md](backend/README.md) for API routes and payload examples.
