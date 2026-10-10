create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'enumerator' check (role in ('admin','enumerator')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.interviews (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  enumerator_id uuid not null default auth.uid() references public.profiles(id),
  interviewer text not null,
  ward text not null,
  outcome text check (outcome in ('refused','not_resident','under_18')),
  data jsonb not null default '{}'::jsonb
);
create index interviews_ward_idx on public.interviews(ward);
create index interviews_enum_idx on public.interviews(enumerator_id);
create table public.recontacts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  enumerator_id uuid not null default auth.uid() references public.profiles(id),
  ward text, by_name text, phone text, email text
);
create table public.settings (key text primary key, value jsonb not null);

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin' and p.active); $$;
create or replace function public.is_active_user() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p where p.id = auth.uid() and p.active); $$;
create or replace function public.my_saved_count() returns integer language sql stable security definer set search_path = public as $$
  select count(*)::int from public.interviews where enumerator_id = auth.uid(); $$;

alter table public.profiles enable row level security;
alter table public.interviews enable row level security;
alter table public.recontacts enable row level security;
alter table public.settings enable row level security;

create policy profiles_self_read on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy profiles_admin_write on public.profiles for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy interviews_insert_own on public.interviews for insert to authenticated with check (enumerator_id = auth.uid() and public.is_active_user());
create policy interviews_admin_read on public.interviews for select to authenticated using (public.is_admin());
create policy interviews_admin_delete on public.interviews for delete to authenticated using (public.is_admin());
create policy recontacts_insert_own on public.recontacts for insert to authenticated with check (enumerator_id = auth.uid() and public.is_active_user());
create policy recontacts_admin_read on public.recontacts for select to authenticated using (public.is_admin());
create policy recontacts_admin_delete on public.recontacts for delete to authenticated using (public.is_admin());
create policy settings_read on public.settings for select to authenticated using (public.is_active_user());
create policy settings_admin_write on public.settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

revoke all on public.profiles, public.interviews, public.recontacts, public.settings from anon;
revoke execute on function public.is_admin(), public.is_active_user(), public.my_saved_count() from anon, public;
grant execute on function public.is_admin(), public.is_active_user(), public.my_saved_count() to authenticated;

insert into public.settings(key,value) values ('wards','["Huruma","Langas","Kiplombe","Kapsoya","Racecourse","Kimumu","Tulwet/Chuiyat","Kipkenyo","Moi''s Bridge","Ngenyilel"]'::jsonb);
