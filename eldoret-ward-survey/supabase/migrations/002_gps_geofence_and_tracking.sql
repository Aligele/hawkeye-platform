alter table public.interviews add column lat double precision, add column lng double precision, add column accuracy_m real;

create table public.ward_geofences (
  ward text primary key,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  radius_m integer not null default 3000 check (radius_m between 100 and 50000),
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
create table public.locations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  enumerator_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  accuracy_m real,
  ward text
);
create index locations_enum_time_idx on public.locations(enumerator_id, created_at desc);
create index locations_time_idx on public.locations(created_at desc);

alter table public.ward_geofences enable row level security;
alter table public.locations enable row level security;
create policy geofences_read on public.ward_geofences for select to authenticated using (public.is_active_user());
create policy geofences_admin_write on public.ward_geofences for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy locations_insert_own on public.locations for insert to authenticated with check (enumerator_id = auth.uid() and public.is_active_user());
create policy locations_admin_read on public.locations for select to authenticated using (public.is_admin());
create policy locations_admin_delete on public.locations for delete to authenticated using (public.is_admin());
revoke all on public.ward_geofences, public.locations from anon;

create or replace function public.distance_m(lat1 double precision, lng1 double precision, lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 2 * 6371000 * asin(sqrt(power(sin(radians(lat2 - lat1) / 2), 2) + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)));
$$;

create or replace function public.enforce_ward_geofence() returns trigger language plpgsql security definer set search_path = public as $$
declare g public.ward_geofences; d double precision;
begin
  if public.is_admin() then return new; end if;
  select * into g from public.ward_geofences where ward = new.ward and enabled;
  if not found then return new; end if;
  if new.lat is null or new.lng is null then
    raise exception 'location_required: GPS location is required for ward %', new.ward using errcode = 'P0001';
  end if;
  d := public.distance_m(new.lat, new.lng, g.lat, g.lng);
  if d > g.radius_m then
    raise exception 'outside_ward: % m from % centre, allowed within % m', round(d), new.ward, g.radius_m using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger interviews_geofence before insert on public.interviews for each row execute function public.enforce_ward_geofence();
revoke execute on function public.enforce_ward_geofence() from anon, authenticated, public;
