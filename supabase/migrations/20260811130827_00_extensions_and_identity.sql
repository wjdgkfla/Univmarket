-- Extensions
create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;

-- 10.1 University / campus / identity tables (native from day one)
create table universities (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,
  name         text not null,
  short_name   text not null,
  active       bool not null default false,
  created_at   timestamptz not null default now()
);

create table university_domains (
  domain        text primary key,
  university_id uuid not null references universities(id) on delete cascade
);

create table campuses (
  id            uuid primary key default gen_random_uuid(),
  university_id uuid not null references universities(id) on delete cascade,
  slug          text not null,
  name          text not null,
  latitude      numeric,
  longitude     numeric,
  active        bool not null default true,
  unique (university_id, slug)
);

create table pickup_zones (
  id          uuid primary key default gen_random_uuid(),
  campus_id   uuid not null references campuses(id) on delete cascade,
  slug        text not null,
  name        text not null,
  safety_note text,
  active      bool not null default true,
  unique (campus_id, slug)
);

create table university_waitlist (
  id           uuid primary key default gen_random_uuid(),
  email        text not null,
  domain       text not null,
  requested_at timestamptz not null default now()
);

-- 10.2 Identity / profiles
create table profiles (
  id                         text primary key,
  university_id              uuid not null references universities(id),
  home_campus_id             uuid references campuses(id),
  display_name               text not null check (length(display_name) <= 100),
  bio                        text not null default '',
  profile_image_url          text,
  role                       text not null default 'student' check (role in ('student','admin')),
  account_state              text not null default 'active' check (account_state in ('active','suspended','banned','deleted')),
  reputation_score           numeric(6,1) not null default 0,
  completed_transaction_count int not null default 0,
  joined_at                  timestamptz not null default now(),
  last_active_at             timestamptz not null default now(),
  deleted_at                 timestamptz
);

create function is_active_user(uid text) returns bool
  language sql stable security definer as
  $$ select exists (select 1 from profiles where id = uid and account_state = 'active') $$;
