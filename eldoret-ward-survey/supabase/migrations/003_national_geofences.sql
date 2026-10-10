-- 003: nationwide county/ward selection with a GPS fence for every ward.
-- Run once in Supabase Dashboard -> SQL Editor. Safe on the current DB (ward_geofences and interviews are empty).

drop trigger if exists interviews_geofence on public.interviews;
drop table if exists public.ward_geofences;

alter table public.interviews add column county text, add column constituency text, add column ward_code integer;
create index interviews_county_idx on public.interviews(county);

create table public.ward_geofences (
  ward_code integer primary key,
  county text not null,
  constituency text,
  ward text not null,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  radius_m integer not null default 5000 check (radius_m between 100 and 200000),
  enabled boolean not null default true,
  source text not null default 'default' check (source in ('default','admin')),
  updated_at timestamptz not null default now()
);
alter table public.ward_geofences enable row level security;
create policy geofences_read on public.ward_geofences for select to authenticated using (public.is_active_user());
create policy geofences_admin_write on public.ward_geofences for all to authenticated using (public.is_admin()) with check (public.is_admin());
revoke all on public.ward_geofences from anon;

create or replace function public.enforce_ward_geofence() returns trigger
language plpgsql security definer set search_path = public as $$
declare g public.ward_geofences; d double precision;
begin
  if public.is_admin() then return new; end if;
  if new.ward_code is null then
    raise exception 'ward_required: choose a county and ward' using errcode = 'P0001';
  end if;
  select * into g from public.ward_geofences where ward_code = new.ward_code;
  if not found then
    raise exception 'fence_not_ready: GPS fences have not been set up yet, ask the admin to sign in once' using errcode = 'P0001';
  end if;
  if not g.enabled then return new; end if;
  if new.lat is null or new.lng is null then
    raise exception 'location_required: GPS location is required for %', g.ward using errcode = 'P0001';
  end if;
  d := public.distance_m(new.lat, new.lng, g.lat, g.lng);
  if d > g.radius_m then
    raise exception 'outside_ward: % m from the % area centre, allowed within % m', round(d), g.ward, g.radius_m using errcode = 'P0001';
  end if;
  return new;
end $$;
revoke execute on function public.enforce_ward_geofence() from anon, authenticated, public;
create trigger interviews_geofence before insert on public.interviews for each row execute function public.enforce_ward_geofence();
