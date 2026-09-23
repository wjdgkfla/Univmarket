# Listing photo storage release gate

The app now uploads JPEG/PNG files up to 1,500,000 bytes to a **private** `listing-images` bucket using paths `<university-id>/<authenticated-user-id>/<random-128-bit-name>.<extension>`. Uploads do not overwrite objects. The listings `cover_image_url` and `image_urls` fields store object paths for new uploads, not expiring URLs. Existing HTTPS photo URLs remain readable for compatibility.

The bucket and its policies are provisioned by `supabase/migrations/20260923063332_listing_image_storage.sql` (applied to the hosted project on 2026-09-23) and tested in `supabase/tests/audit_hardening.sql`: uploads only into `<your university>/<your user id>/`, reads only for your own uploads or photos on listings you can see, no client updates or deletes. `listings.cover_image_url` must be the seller's own path in that folder (`20260923063328_harden_listing_fields.sql`).

Required provisioning and verification:

- Create the private bucket with the same file size limit and MIME allowlist `image/jpeg`, `image/png`.
- Insert policy must independently validate a confirmed, active, nonanonymous account, server-owned university membership, and both path prefixes. Client-side path checks are not authorization.
- Read/sign policy must permit the owner and authorized students viewing a visible, nondeleted listing in their university. Do not grant public reads or rely solely on a guessed object path.
- Preserve existing objects while deploying policies. Test owner, another user at the same university, another university, anonymous, suspended and unconfirmed accounts.
- Orphan cleanup runs nightly at 08:17 UTC: pg_cron calls the `cleanup-listing-photos` Edge Function, which deletes (through the Storage API) photos no live listing uses once they are 24 hours old: deleted listings and accounts, replaced photos, and uploads whose listing write failed. The grace period covers an ambiguous network failure where the write may have committed. See `20260923072453_listing_photo_cleanup.sql` and `supabase/operations/configure_photo_cleanup.sql`.
- Signed viewing URLs last one hour. Add refresh/expiry handling for long-lived app sessions, and test refresh after background/resume. A signing failure currently shows the normal missing-photo fallback without reporting a successful listing write as failed.
- Validate actual image decoding and review metadata stripping before launch. Current format checks identify JPEG/PNG signatures and size; they do not guarantee image integrity.

Mocked SDK tests verify upload-before-write, randomized scoped paths, stored paths, signed URL mapping, and stopping writes on upload denial. Actual hosted storage policy tests and physical-device photo picking remain required.

Catalog refresh is now implemented on foreground resume and every 45 active minutes. Lifecycle and SDK tests verify refresh and re-signing, but real-device background/resume and hosted photo permissions still require verification.
