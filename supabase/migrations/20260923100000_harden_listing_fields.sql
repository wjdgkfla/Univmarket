-- Enforce the app's listing limits at the database boundary, so a modified
-- client cannot store oversized text, out-of-range prices, or photos that
-- point outside the seller's own storage folder. Live rows were checked
-- against every rule before this migration.
alter table public.listings
  add constraint listings_title_length
    check (length(btrim(title)) between 3 and 100),
  add constraint listings_description_length
    check (length(btrim(description)) between 10 and 2000),
  add constraint listings_price_range
    check (price between 0 and 100000),
  -- 'other' is the column default used by older rows and test fixtures.
  add constraint listings_category_known
    check (category in ('Textbooks','Electronics','Furniture','Bikes','Dorm','Apparel','Bags','other')),
  add constraint listings_condition_known
    check (condition in ('fair','good','like_new')),
  -- A photo is an object path in the private listing-images bucket, inside
  -- <university>/<seller>/, named by the app's random 128-bit hex name.
  -- This rejects external URLs (tracking pixels, unmoderated hosts) and
  -- other students' uploads.
  add constraint listings_cover_is_own_upload
    check (cover_image_url is null or cover_image_url ~
      ('^' || university_id::text || '/' || seller_id || '/[0-9a-f]{32}\.(jpg|png)$')),
  add constraint listings_image_urls_match_cover
    check (cardinality(image_urls) = 0 or image_urls = array[cover_image_url]);
