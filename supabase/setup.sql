-- ---------------------------------------------------------------
-- Run this once in Supabase -> SQL Editor -> New query -> Run
-- Creates the "profiles" table and the "avatars" photo bucket.
-- ---------------------------------------------------------------

-- 1. Profiles table (one row per logged-in user)
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  name        text,
  phone       text,
  email       text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- 2. Security: each user can only see and change their own row
alter table public.profiles enable row level security;

drop policy if exists "Read own profile" on public.profiles;
create policy "Read own profile" on public.profiles
  for select to authenticated using (auth.uid() = id);

drop policy if exists "Create own profile" on public.profiles;
create policy "Create own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists "Update own profile" on public.profiles;
create policy "Update own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- 3. Public bucket for profile photos
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Users can upload only inside their own folder: avatars/<user id>/...
drop policy if exists "Upload own avatar" on storage.objects;
create policy "Upload own avatar" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------
-- 4. App settings from the cloud (one row). Edit it in Table Editor:
--    maintenance_mode  true  -> everyone sees the Maintenance screen
--    app_version       latest store build number (the "+N" in pubspec version)
--    force_update      true  -> Update screen has no "Later" button
--    splash_image      full URL, or a file name inside the "app-assets" bucket
--    splash_time       seconds the splash stays on screen
-- ---------------------------------------------------------------
create table if not exists public.app_setting (
  id                  int primary key default 1 check (id = 1),  -- only one row
  maintenance_mode    boolean not null default false,
  maintenance_message text,
  app_version         int     not null default 1,
  force_update        boolean not null default false,
  android_url         text default 'https://play.google.com/store/apps/details?id=com.example.hello_world',
  ios_url             text default '',
  splash_image        text default '',
  splash_time         int     not null default 2,
  updated_at          timestamptz not null default now()
);

insert into public.app_setting (id) values (1) on conflict (id) do nothing;

-- Everyone (even before login) can read the settings; only the dashboard can change them
alter table public.app_setting enable row level security;

drop policy if exists "Anyone can read app settings" on public.app_setting;
create policy "Anyone can read app settings" on public.app_setting
  for select to anon, authenticated using (true);

-- 5. Public bucket for app images (splash image). Upload files from the dashboard.
insert into storage.buckets (id, name, public)
values ('app-assets', 'app-assets', true)
on conflict (id) do nothing;
