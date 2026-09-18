create table listings (
  id                text primary key default gen_random_uuid()::text,
  seller_id         text not null references profiles(id),
  university_id     uuid not null references universities(id),
  campus_id         uuid references campuses(id),
  pickup_zone_id    uuid references pickup_zones(id),
  title             text not null,
  description       text not null,
  price             numeric(10,2) not null default 0,
  category          text not null default 'other',
  condition         text not null default 'good',
  status            text not null default 'available' check (status in ('available','reserved','sold')),
  moderation_state  text not null default 'visible' check (moderation_state in ('visible','flagged','hidden')),
  listing_kind      text not null default 'sell' check (listing_kind in ('sell','wanted')),
  accepts_trades    bool not null default false,
  image_urls        text[] not null default '{}',
  cover_image_url   text,
  tags              text[] not null default '{}',
  course_code       text,
  course_code_normalized text,
  professor_name    text,
  edition           text,
  bundle_notes      text,
  favorite_count    int not null default 0,
  view_count        int not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  expires_at        timestamptz,
  last_refreshed_at timestamptz,
  deleted_at        timestamptz,
  deleted_by        text,
  delete_reason     text
);

create index listings_university_status_created_idx on listings (university_id, status, created_at desc, id desc);
create index listings_category_idx on listings (category);
create index listings_campus_idx on listings (campus_id);
create index listings_moderation_idx on listings (moderation_state);

create function increment_view_count(p_listing_id text) returns void
  language sql security definer as
  $$ update listings set view_count = view_count + 1 where id = p_listing_id $$;
