# Loan EMI Tracker — Mobile (Flutter + Supabase)

A standalone mobile app. **Not connected to the old web app** — its own backend
(Supabase) and its own frontend (Flutter). The loan math is a faithful Dart port
of the web app's engine (verified against golden numbers; see `test/`).

## Architecture

```
Flutter app  ──>  Supabase
  loan_engine.dart   - Auth (email/password)
  (all the math       - Postgres: loans, disbursements, payments
   runs on-device)    - Row Level Security (each user sees only their data)
```
No Node server. Calculations (`buildTimeline`, `simulateLoan`, EMI/schedule) run
inside the app, exactly as the web backend did.

---

## One-time backend setup

### 1. Create the schema
Supabase Dashboard → **SQL Editor** → New query → paste all of
`supabase/schema.sql` → **Run**. Creates 3 tables + RLS policies.

### 2. Get your anon key
Dashboard → **Settings → API** → copy the **anon public** key (or the
**Publishable key** `sb_publishable_...`). Paste it into
`lib/config.dart` → `supabaseAnonKey`.

### 3. Migrate your existing data (optional)
Loads your local `db.json` (Home Loan + transactions) into Supabase.
```bash
cd tools
node --experimental-fetch migrate.js
```
Creates the owner login (default `deepak@loan.app` / `LoanApp@123` — change in
`tools/.env`) and inserts the loan, disbursements, and payments.

> 🔒 After migrating, **rotate the secret key** in Dashboard → Settings → API,
> and update `tools/.env`. It was shared in chat and should not be reused.

---

## Run the app

### 1. Install Flutter
<https://docs.flutter.dev/get-started/install/windows> — then `flutter doctor`
until Android toolchain is green (install Android Studio + an emulator, or
enable USB debugging on a phone).

### 2. Generate the platform scaffolding
From the project root (this adds `android/`, `ios/`, etc. without touching
`lib/`):
```bash
flutter create .
flutter pub get
```

### 3. Verify the engine parity (recommended)
```bash
flutter test
```
Should print **All tests passed** — that confirms the Dart math equals the web
app's numbers (₹80,71,214 total outstanding, ₹2,70,087 interest saved, etc.).

### 4. Launch
```bash
flutter run
```
Sign in with the migrated credentials (or register a new account).

### 5. Build a release APK (to install on your phone)
```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Notes
- **Auth:** old bcrypt passwords can't be imported into Supabase Auth, so the
  migration sets a fresh password for the owner. Change it any time via the
  Supabase dashboard (Authentication → Users) or add a reset flow.
- **The `test` user** from db.json had no loans and is not migrated.
- Email confirmation: if you keep it ON in Supabase, new sign-ups must confirm
  before logging in. For a personal app, turn it OFF (Auth → Providers → Email).
