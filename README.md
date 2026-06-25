# Michael & Son World Cup Predictor v13

Deployment-ready version.

New in v13:

- Local SQLite support still works.
- Online PostgreSQL support through `DATABASE_URL` for Supabase.
- Python backend can serve the Flutter web build, so one Render Free Web Service can host the full app.
- Public display screen at `/#/display` with huge QR + Top 10 leaderboard.
- Public leaderboard endpoint: `/public/leaderboard?limit=10`.
- Admin login is still:
  - Full name: `Admin`
  - Password: `Admin123!`

Read `DEPLOYMENT_STEPS.md` for the free Render + Supabase setup.
