# Ward Voter Survey (Kenya)

Field survey platform: enumerators sign in and fill in the questionnaire; admins see live results, download a PDF summary report and CSV data, and manage enumerator logins.

- **Frontend:** single static page (`index.html`), Supabase JS, jsPDF.
- **Backend:** Supabase (Auth + Postgres with row-level security + one Edge Function).
- **Roles:** `enumerator` can only insert interviews; `admin` can read everything and manage users.

## Setup
1. Create a Supabase project and run `supabase/migrations/001_schema.sql`.
2. Deploy `supabase/functions/manage-users` (verify JWT on).
3. Put your project URL and publishable key in `index.html` (`SB_URL`, `SB_KEY`).
4. Create the first admin (see the SQL in the migration notes), then create enumerators from the app.
5. Deploy the folder as a static site (e.g. Vercel).

## Nationwide counties and wards (migration 003)

Enumerators pick a County, then a Ward (47 counties, 1,450 wards, from `kenya-areas.json`).
Each ward has a GPS fence in `ward_geofences`. On first admin sign-in the app creates a default
fence for every ward from its constituency centre and size; the admin can tighten any of them in
Field map > Ward GPS fences. Run `supabase/migrations/003_national_geofences.sql` before deploying this version.
