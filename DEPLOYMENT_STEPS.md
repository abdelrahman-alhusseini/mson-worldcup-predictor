# Free deployment plan: Render + Supabase

This version can run locally with SQLite and online with Supabase PostgreSQL.
It can also serve the Flutter web build from the same Python backend, so you only need one Render Web Service.

## 1) Supabase database

1. Open Supabase.
2. Create a new project.
3. Go to Project Settings → Database.
4. Copy a PostgreSQL connection string. Use the pooled connection string if available.
5. Keep the database password private.

You will paste this full value into Render as `DATABASE_URL`.

Example format:

```text
postgresql://postgres.xxxxx:YOUR_PASSWORD@aws-xxxxx.pooler.supabase.com:6543/postgres
```

Add `?sslmode=require` at the end if Supabase did not include SSL mode:

```text
postgresql://.../postgres?sslmode=require
```

## 2) Test locally first

Backend:

```powershell
cd backend
py main.py
```

Frontend:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Admin login:

```text
Full name: Admin
Password: Admin123!
```

## 3) Build the Flutter website for the live server

From the project root:

```powershell
cd frontend
flutter clean
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=
```

This creates:

```text
frontend/build/web
```

The Python backend will serve that folder online.

## 4) Push project to GitHub

From the project root:

```powershell
git init
git add .
git commit -m "Deploy Michael and Son World Cup Predictor"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/mson-worldcup-predictor.git
git push -u origin main
```

## 5) Create Render Web Service

1. Open Render.
2. New → Web Service.
3. Connect your GitHub repo.
4. Use these settings:

```text
Root Directory: backend
Build Command: pip install -r requirements.txt
Start Command: python main.py
Plan: Free
```

Environment variables:

```text
PYTHON_VERSION=3.11.11
HOST=0.0.0.0
STATIC_DIR=../frontend/build/web
DATABASE_URL=your Supabase PostgreSQL connection string
```

## 6) Live URLs

Main prediction site:

```text
https://YOUR-RENDER-SERVICE.onrender.com/
```

Display screen with QR and Top 10 leaderboard:

```text
https://YOUR-RENDER-SERVICE.onrender.com/#/display
```

The QR code automatically points to the same live website unless you build with a custom value:

```powershell
flutter build web --release --dart-define=API_BASE_URL= --dart-define=DISPLAY_QR_URL=https://YOUR-LINK.onrender.com/
```

## Notes

- Render Free Web Services can sleep after inactivity, so the first load may be slow.
- Supabase keeps the online database separate from the server files, so users/predictions/leaderboard data are not lost when Render restarts.
- Passwords are hashed. Admin can reset passwords but cannot view original passwords.
