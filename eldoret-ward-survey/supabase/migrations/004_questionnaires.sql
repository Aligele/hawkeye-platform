-- Admin-managed questionnaires. Safe to run more than once.
-- While one questionnaire is "active", enumerators answer its questions after the interview details and screening.
-- When none is active, the app's built-in questions are used.

create table if not exists public.questionnaires (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  status text not null default 'draft' check (status in ('draft','active','closed')),
  questions jsonb not null default '[]'::jsonb,   -- [{id, section, text, type: single|multi|text|area, options[], max, required}]
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.questionnaires enable row level security;

drop policy if exists questionnaires_read_active on public.questionnaires;
create policy questionnaires_read_active on public.questionnaires
  for select using ((status = 'active' and public.is_active_user()) or public.is_admin());

drop policy if exists questionnaires_admin_write on public.questionnaires;
create policy questionnaires_admin_write on public.questionnaires
  for all using (public.is_admin()) with check (public.is_admin());

-- Interviews remember which questionnaire they answered. A questionnaire that still has interviews cannot be deleted
-- (close it instead: closed questionnaires are hidden from enumerators and their answers are kept).
alter table public.interviews
  add column if not exists questionnaire_id uuid references public.questionnaires(id) on delete restrict;

-- Optional hardening: at most one active questionnaire, and updated_at maintained by the database.
create unique index if not exists questionnaires_one_active on public.questionnaires ((true)) where status = 'active';

create or replace function public.touch_questionnaire() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;
drop trigger if exists questionnaires_touch on public.questionnaires;
create trigger questionnaires_touch before update on public.questionnaires
  for each row execute function public.touch_questionnaire();
