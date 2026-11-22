-- Open sign-up: anyone can register, but the account stays inactive ("pending") until an admin approves it.
alter table public.profiles add column if not exists pending boolean not null default false;
alter table public.profiles add column if not exists note text;
