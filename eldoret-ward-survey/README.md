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

## Ward boundaries

`kenya-wards.json` holds simplified ward boundaries (about 55 m tolerance) for 1,436 of the 1,450 wards, with a default
centre and enclosing radius for each. Source: `tigawanna/kenya_wards_geojson_data` (MIT), itself built from the
Kenya Elections boundary data on the Humanitarian Data Exchange (IEBC). The other 14 wards use a circle around the
constituency instead. Enumerators see only the ward their phone is inside, and an interview is accepted only from inside
that ward (the server check uses a circle that encloses the ward). Check the HDX licence terms before wider redistribution.

## Questionnaires (migration 004)

Admins get a **Questionnaire** tab. Add a questionnaire (type the questions, or paste many at once), then **Make active**.
Enumerators then answer its questions after the interview details and screening; the built-in questions are used
again whenever none is active. Only drafts can be edited. When fieldwork is done, **Close** the questionnaire: it is hidden
from enumerators and its answers are kept (they appear in Results, the CSV and the JSON). **Delete** works only for a
questionnaire with no saved interviews, so data cannot be lost by accident. Run `supabase/migrations/004_questionnaires.sql` first.

Paste format: separate questions with a blank line; the first line is the question and each following line is an answer.
No answers = short text. End a question with `(multi)` or `(multi 3)` for multiple choice and with `*` if it is required.
A line starting with `#` names a section.

Questions can also be imported from a file in the editor: Word (`.docx`), text (`.txt`, `.md`), CSV or JSON. Word and text files use the
paste format above. CSV needs a header row with `Section, Question, Type, Required, Options, Max` (options separated by `|`;
type is single, multi, text or long); the editor has a template to download. JSON is a list of questions, or `{ "title", "questions" }`.
