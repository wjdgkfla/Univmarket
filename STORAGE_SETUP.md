# Listing photo storage release gate

The app now uploads JPEG/PNG files up to 1,500,000 bytes to a **private** `listing-images` bucket using paths `<university-id>/<authenticated-user-id>/<random-128-bit-name>.<extension>`. Uploads do not overwrite objects. The listings `cover_image_url` and `image_urls` fields store object paths for new uploads, not expiring URLs. Existing HTTPS photo URLs remain readable for compatibility.

The hosted project was inspected: no buckets or storage object policies were returned. This document does not create them. Live photo posting cannot succeed until provisioning is completed.

Required provisioning and verification:

- Create the private bucket with the same file size limit and MIME allowlist `image/jpeg`, `image/png`.
- Insert policy must independently validate a confirmed, active, nonanonymous account, server-owned university membership, and both path prefixes. Client-side path checks are not authorization.
- Read/sign policy must permit the owner and authorized students viewing a visible, nondeleted listing in their university. Do not grant public reads or rely solely on a guessed object path.
- Preserve existing objects while deploying policies. Test owner, another user at the same university, another university, anonymous, suspended and unconfirmed accounts.
- Implement orphan-object cleanup for uploads whose listing write fails or whose photo is replaced. Do not delete immediately after an ambiguous network failure: the listing write may have committed.
- Signed viewing URLs last one hour. Add refresh/expiry handling for long-lived app sessions, and test refresh after background/resume. A signing failure currently shows the normal missing-photo fallback without reporting a successful listing write as failed.
- Validate actual image decoding and review metadata stripping before launch. Current format checks identify JPEG/PNG signatures and size; they do not guarantee image integrity.

Mocked SDK tests verify upload-before-write, randomized scoped paths, stored paths, signed URL mapping, and stopping writes on upload denial. Actual hosted storage policy tests and physical-device photo picking remain required.
