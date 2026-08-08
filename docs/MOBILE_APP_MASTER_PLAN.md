# UnivMarket — Mobile App Master Plan

**Planning date:** August 8, 2026
**Product name:** "UnivMarket" is a **temporary placeholder**, not a final brand decision — used throughout this document for convenience only.
**Relationship to Mason Market:** This is a **separate product** with its **own new Supabase backend/database**. The existing project at `C:\Users\wjdgk\Desktop\mason-market\mason-market` is used strictly as a **reference blueprint** — its proven data model, business logic, and known mistakes inform a fresh design. No code, schema, or backend is shared or reused between the two products.
**Scope:** Mobile app only (iOS + Android) for now. No web app is in scope; the architecture avoids decisions that would be wasted if a web app never happens, while not foreclosing one later.
**Status:** PLANNING ONLY. No code, schema, or configuration was created or modified for either project in this session.

---

# 1. Executive Summary

UnivMarket is a greenfield mobile marketplace app for verified university students to buy, sell, and trade items on campus. It is built independently of Mason Market, with its own Supabase project, but it does not start from a blank slate conceptually: Mason Market is a working, reasonably mature campus marketplace, and auditing it thoroughly surfaced exactly which patterns are worth replicating (atomic offer-acceptance via Postgres RPC, transaction-gated two-way reviews, Wilson-score reputation, cursor pagination, soft-deleted listings) and exactly which mistakes are worth avoiding (a broken counteroffer-acceptance direction, Realtime wired against a deny-all RLS policy set so it silently does nothing, a block-check bypass on a secondary message endpoint, GMU hard-coded into both schema defaults and TypeScript enums, and a second custom auth-session system layered on top of Supabase Auth that added complexity without adding security).

Because this is mobile-only with no existing codebase to interoperate with, the right architecture is leaner than a monorepo: **Expo (React Native + TypeScript) talking directly to a new Supabase project** via properly scoped Row-Level Security policies, Postgres RPCs for atomic multi-table operations, Supabase Realtime for live chat, Supabase Storage for images, and a small number of Edge Functions for the handful of things that need server-side secrets or outbound HTTP (push delivery, scheduled jobs). No separate Next.js/Node backend is needed to start.

Two decisions are made natively from day one, rather than retrofitted: **trading** (item-for-item / item+cash, modeled as generalized offers) and **multi-university support** (universities/campuses/pickup-zones as first-class tables, not hardcoded enums). Since there's no legacy schema to migrate, this costs nothing extra now and avoids repeating Mason Market's biggest structural regret.

The plan still launches at a **single pilot campus first** — multi-university architecture does not mean multi-university launch. Prove liquidity at one school before turning on a second.

---

# 2. Blueprint Source Audit (Mason Market — Read-Only Reference)

This section summarizes what a thorough, read-only audit of Mason Market found. It is retained because it is the single best available input for designing UnivMarket's schema and avoiding known failure modes — **not** because any of this code will be imported or extended.

## 2.1 Stack audited

Next.js 16 (App Router) + React 18 + Tailwind, Supabase Postgres (12 timestamped migrations, CI-replayed), Supabase Auth + a custom HMAC-signed app-session cookie, Supabase Storage, `web-push` for notifications, Jest (12 suites) + Playwright (3 specs, not in CI), GitHub Actions CI (lint/tsc/test/build + migration replay).

## 2.2 What the schema got right (replicate the pattern, not the code)

- **Offers as structured entities with a chain**, not free-text chat: `offer_status` state machine (pending/accepted/declined/withdrawn/superseded), `parent_offer_id`-style counteroffer chaining, expiry.
- **A first-class `transactions` table** created atomically by a locking Postgres RPC (`accept_offer`) that, in one transaction: validates the offer is still pending and the listing still available, accepts it, declines competing pending offers on the same listing, inserts the transaction row, and reserves the listing. This is the correct pattern for "offer acceptance must be atomic" — UnivMarket should do the same from day one.
- **Reviews gated on completed transactions**, two-way (buyer↔seller), unique per `(reviewer, transaction)` — correct trust semantics, worth replicating exactly.
- **Reputation as a transparent Wilson-score-style computation** from completed transactions + review positivity, replacing an earlier price-weighted formula that overweighted expensive items. Adopt directly.
- **Cursor/keyset pagination** `(created_at desc, id desc)` instead of offset pagination — adopt directly.
- **Soft-deleted listings** (`deleted_at`/`deleted_by`/`delete_reason`) instead of hard delete, to preserve transaction/moderation evidence — adopt, and extend the principle to accounts (§10.8-equivalent below).
- **RLS enabled with a deny-all policy set**, all access routed through a privileged server layer — this is a *valid* pattern when a privileged BFF exists, but it is exactly the wrong pattern once a client (mobile) needs Realtime, because Realtime honors RLS and a deny-all policy set means an authenticated client subscription receives nothing. UnivMarket needs **narrow, correct, participant-scoped policies** from the start (§14).

## 2.3 What went wrong (avoid by design, not by patching)

| Mistake found in Mason Market | Root cause | UnivMarket design response |
|---|---|---|
| Buyer cannot accept a seller's counteroffer | `accept_offer` RPC hardcoded "actor must be the listing seller" instead of "actor must be the offer's recipient" | Design the RPC around offer *recipient*, never around a fixed role, from day one |
| Realtime wired in the UI but almost certainly delivers nothing | RLS enabled with zero policies; anon-key client subscription under deny-all RLS receives no rows | Ship participant-scoped SELECT policies alongside the first Realtime feature, with an automated test asserting non-participants get zero rows and participants get their own |
| Block enforced on one message endpoint, bypassable via a second one | Authorization duplicated per-route instead of centralized | Enforce blocking inside the single atomic message-creation RPC, not in route/client code, so there is only one path and it cannot be bypassed by adding a second entry point |
| Suspended users retain functioning sessions on many routes | Suspension checked ad hoc per route instead of centrally | Every RPC/policy checks `account_state = 'active'` at the single choke point (a Postgres function or RLS predicate), not per-feature |
| GMU hardcoded in TypeScript enums (campuses, pickup zones) and in schema defaults/column names (`gmu_email`) | University support was retrofitted after launch | Universities/campuses/pickup-zones are tables from day one (§13); no campus/zone value ever appears in application code |
| A second custom HMAC session-cookie system layered on top of Supabase Auth | Built for a server-rendered web app that needed httpOnly cookies; adds a parallel security surface (session versioning, HMAC secret rotation) | Not needed for a mobile client — use Supabase Auth's native session/JWT + refresh-token model directly (§14) |
| Trades not supported; offers hardcoded to cash only, embedded as columns on `messages` | Offers were designed for the MVP's cash-only scope | Model offers generically (cash / items / items+cash) against a normalized `offers`/`offer_items` schema from day one (§12) — trading is not an add-on |
| No background job infrastructure; matching/expiry logic runs inline on write paths (O(n) scans) | No cron/edge-function investment | Use `pg_cron` + Edge Functions for matching sweeps and expiries from the relevant phase, not inline scans |
| In-memory rate limiting, no structured error monitoring, no analytics | Deferred, documented as known gaps | Plan these in as P0/P1 from day one instead of deferred (§28) |

## 2.4 Feature completeness as a target checklist

Mason Market's live feature set is a credible definition of "what a real campus marketplace needs." The full inventory (offers/counteroffers, wanted listings, saved searches with dedup, price-drop watches, meetup workflow with presence states, favorites, reports, blocking, admin moderation, push notifications) is the functional bar UnivMarket's MVP should reach — see §3 for the phase-by-phase target and §22 for critical E2E scenarios adapted from it.

---

# 3. UnivMarket Feature Target (informed by the blueprint)

Each feature is labeled by how UnivMarket should treat it, not by Mason Market's status:

**ADOPT PATTERN** (build it the same way, new code) · **ADOPT + FIX** (build it the same way, but correct a known defect) · **REDESIGN** (build it differently — usually to support multi-university/trading natively) · **NEW CAPABILITY** (doesn't exist in the blueprint at all) · **DEFER** (real feature, not in MVP) · **OUT OF SCOPE** (not planned).

| Feature | Treatment | Why |
|---|---|---|
| University email verification | REDESIGN | Domain-table-driven (`university_domains`), not hardcoded regex |
| Sell listings | ADOPT PATTERN | Rich model (photos, category, condition, course fields, tags, expiry/refresh) is proven |
| Wanted listings | ADOPT PATTERN | Proven liquidity mechanism |
| Categories/filters | ADOPT PATTERN | Straightforward, works |
| Search (Postgres FTS + trigram) | ADOPT PATTERN, improve weighting from day one | See §19 |
| Cursor pagination | ADOPT PATTERN | Directly correct |
| Favorites, saved searches, price watches | ADOPT PATTERN | Proven, with dedup constraint from day one |
| Cash offers + counteroffers | ADOPT + FIX | Fix recipient-based acceptance from day one |
| **Trades (item-for-item, item+cash)** | **NEW CAPABILITY, built in from day one** | The most requested gap; see §12 |
| Transactions (reserve → meetup → complete) | ADOPT PATTERN | Proven atomic RPC pattern |
| Cancellation / no-show / dispute | NEW CAPABILITY | Blueprint only had status values, not a full workflow |
| Messaging + Realtime | ADOPT + FIX | Real RLS policies from the first version, not retrofitted |
| Meetup scheduling | ADOPT + FIX | Add proposer attribution, curated zones from `pickup_zones` table |
| Reviews / reputation | ADOPT PATTERN | Two-way, transaction-gated, Wilson score — copy exactly |
| Reports / blocking | ADOPT + FIX | Enforce inside the single message RPC, not per-route |
| Admin / moderation | REDESIGN (no web app) | MVP via Supabase Studio + admin RPCs; see §7.4 |
| Push notifications | REDESIGN | Expo push only (no web-push needed); outbox pattern from day one |
| In-app notifications + preferences | NEW CAPABILITY | Preferences table from day one (blueprint only had a localStorage opt-out) |
| Multi-university data model | NEW CAPABILITY, native from day one | The other core gap; see §13 |
| Design tokens (colors/type/spacing) | REDESIGN input, not adopted verbatim | Mason Market's GMU green/gold is a specific school's brand; UnivMarket needs neutral, placeholder branding until final identity is chosen (§21) |
| PWA / offline web | OUT OF SCOPE | No web app |
| Analytics | NEW CAPABILITY | Nothing exists in the blueprint |
| AI features | DEFER | See §24 |
| Payments | OUT OF SCOPE | See §25 |

---

# 4. Lessons-Learned Inventory (from the blueprint audit)

These are not "technical debt in our codebase" — they are defects found in Mason Market that UnivMarket's fresh design must not repeat. Ordered by how load-bearing the lesson is.

| # | Lesson | Design response in UnivMarket |
|---|---|---|
| L1 | Offer-acceptance authorization tied to a fixed role ("seller") instead of "whoever received the offer" broke counteroffers | Acceptance RPC always checks `actor = offer.to_user_id`, regardless of negotiation direction |
| L2 | Realtime subscriptions under deny-all RLS silently deliver nothing — a client-visible feature can be dead with no error | Write the RLS policy test (non-participant denied, participant allowed) **before** shipping any Realtime feature; treat it as a release gate, not an afterthought |
| L3 | Authorization duplicated per API route → one route forgot the block check | Centralize authorization inside Postgres RPCs/policies (the single choke point), not in client or per-endpoint code — mobile-only architecture makes this natural since there's no route layer to duplicate logic across |
| L4 | Suspension enforcement was ad hoc per feature | `account_state` checked in one shared predicate (a Postgres function `is_active_user(uid)`) referenced by every RLS policy and RPC |
| L5 | University identity hardcoded into enums/regex/column names | Universities, domains, campuses, and pickup zones are tables from day one; zero school-specific literals in app code |
| L6 | A second custom session system (HMAC cookie) added surface area for a web-specific need that a mobile client doesn't have | Use Supabase Auth's native session model only |
| L7 | Offers modeled as columns on `messages` blocked trading later and made offer queries awkward | Normalize `offers`/`offer_items` from day one |
| L8 | Inline O(n) matching/expiry scans on write paths | Background jobs (`pg_cron` + Edge Functions) from the relevant phase |
| L9 | In-memory rate limiting, no error monitoring, no analytics — all deferred to "later" | Budget these as P0/P1, not deferred (§28) |
| L10 | No account-deletion story; aggressive `ON DELETE CASCADE` from `users` would destroy counterparty transaction evidence if ever used | Never hard-delete users; anonymize + soft-state (`account_state = 'deleted'`) from the schema's first version |
| L11 | Listing status (available/reserved/sold) editable independently of the transaction that reserved it, creating a contradiction window | Listing status transitions only via transaction RPCs or by the seller **when no active transaction exists** — enforced in one function, not scattered |
| L12 | No web app means no natural home for a moderation dashboard (a gap UnivMarket inherits by being mobile-only, not from the blueprint) | Explicit decision in §7.4: Supabase Studio + admin RPCs for MVP, defer a real UI |

---

# 5. Security Design Baseline (informed by the blueprint's security review)

No secret values appear anywhere in this document.

**Findings from Mason Market worth carrying forward as baseline requirements** (these were correctly implemented there and should be true of UnivMarket too):
- Production email confirmation required before a session is trusted.
- Upload validation: MIME type + magic-byte signature check + size cap + count cap + storage-path restriction — apply identically to UnivMarket's upload path.
- Never commit real secrets; `.env*` (or Expo's `eas.json`/`app.config.ts` secrets) gitignored, only placeholder example files tracked.
- Entity IDs validated before use in any dynamic query construction (filter-injection defense).

**Findings that must NOT be repeated (see §4 L1–L4):** role-fixed authorization, dead Realtime under deny-all RLS, per-route-duplicated authorization, ad hoc suspension checks.

**New baseline requirements specific to a mobile-only, RLS-native architecture:**
- **RLS is the only authorization boundary** (there is no privileged BFF to fall back on) — every table needs an explicit, tested policy; "RLS enabled, no policies" is not an acceptable end state for any table the client ever queries directly.
- **Postgres functions used for privileged operations must be `SECURITY DEFINER` with an explicit role/ownership check inside the function body** — never rely on "only admins call this" as an unenforced convention.
- **Anon key is public by construction** (it ships inside the app binary) — every security guarantee must come from RLS + auth, never from "the key is hard to find."
- **Realtime channels must be scoped** to what a policy already allows; do not create a channel and assume client-side filtering is a security boundary.
- **Rate limiting and abuse protection move to the database/edge layer** (Postgres function-level throttling or Edge Function + Upstash) since there is no proxy layer in front of Supabase to do IP-based limiting the way Mason Market's Next.js proxy did.
- **Privacy/ToS/prohibited-items policy and account deletion (anonymize, don't hard-delete) are P0**, not launch-checklist afterthoughts — required for app-store review regardless of platform choice.

---

# 6. Recommended Mobile Framework

## 6.1 Comparison (re-evaluated for the mobile-only, no-code-reuse scenario)

The original justification for React Native — "reuse the existing web app's TypeScript" — no longer applies, since nothing is being reused. Re-running the comparison honestly for a **greenfield, mobile-only, two-platform build**:

| Criterion | Expo (React Native) | Bare React Native | Flutter | Native Swift + Kotlin |
|---|---|---|---|---|
| iOS + Android from one codebase | Yes | Yes | Yes | No — two codebases |
| Team's existing skillset (TypeScript/React, proven via building Mason Market) | **Direct match** | Direct match | New language (Dart) | New languages/toolchains ×2 |
| Supabase support | First-class (`supabase-js`, official RN patterns, Realtime works) | Same | Official but separately-typed Dart SDK | Community, separately-typed |
| Build/deploy tooling | **EAS Build/Submit/Update** — CI-friendly, no local Xcode/Android Studio required | Manual native project + Fastlane | Standard toolchain | Standard toolchain, most manual |
| OTA JS updates | EAS Update | Community CodePush successors | Shorebird (newer, less mature) | Not applicable |
| Forward compatibility if a web app is ever added | High — same language, and even component logic can migrate via React Native Web if desired | High | None — a web app would be a third rewrite | None |
| Long-term maintainability, solo/small team | **Best fit** | Higher upkeep (native project maintenance) | Second ecosystem to maintain indefinitely | Highest cost, two ecosystems |
| Suitability for this app's UI (lists, forms, chat, camera, maps-lite) | More than sufficient | Same | Same | Overkill |
| Cost | Lowest | Low-mid | Mid (new-language ramp-up) | Highest |

## 6.2 Recommendation

**Expo (React Native) with TypeScript, expo-router, and EAS Build/Submit/Update — unchanged conclusion, different reasoning.**

Even with zero code reuse, the deciding factors are: the team already builds fluently in TypeScript/React (proven by Mason Market); Supabase's official client and Realtime work naturally in React Native; EAS removes the need to run local Xcode/Android Studio toolchains for CI-friendly builds; and if a web app is ever added later (explicitly not planned now), staying in one language keeps that door open without forcing it. Flutter is not disqualified on technical merit — it would be a defensible choice for a team starting fresh in Dart — but it offers no advantage here and costs a second language ecosystem to learn and maintain long-term. Native Swift+Kotlin is not justified by this app's UI complexity (no heavy custom rendering, no platform-specific hardware access beyond camera/push, both well-supported by Expo modules).

---

# 7. Recommended Architecture

## 7.1 Target system — Supabase-native, no custom backend server

```text
                         ┌───────────────────────────────┐
                         │   Supabase (new project)       │
                         │                                 │
                         │  Postgres                       │
                         │   • RLS policies (participant-  │
                         │     scoped, tested)              │
                         │   • RPCs: accept_offer,          │
                         │     accept_trade_offer,           │
                         │     confirm_completion,           │
                         │     cancel_transaction,            │
                         │     create_message, ...            │
                         │                                 │
                         │  Storage (listing/profile images)│
                         │  Realtime (messages, offers,     │
                         │            transactions)          │
                         │  Auth (email/password + OTP,      │
                         │        university-domain hook)    │
                         │  Edge Functions (Deno):            │
                         │   • push delivery (Expo push)      │
                         │   • scheduled matching/expiry       │
                         │     sweeps (invoked by pg_cron)     │
                         │   • auth "before-user-created"      │
                         │     hook (domain → university)      │
                         │  pg_cron (schedules the sweeps)     │
                         └───────────────┬─────────────────┘
                                         │  supabase-js
                                         │  (anon key + user session,
                                         │   RLS enforces everything)
                                         ▼
                              ┌─────────────────────┐
                              │  UnivMarket mobile    │
                              │  (Expo / React Native)│
                              │   iOS + Android        │
                              └─────────────────────┘
```

**Key decisions and why:**

1. **No Next.js/Node backend-for-frontend.** Mason Market needed one because it's server-rendered and had a web-specific session model. UnivMarket has one client (mobile) that can talk to Supabase directly. Adding a BFF now would mean hosting and maintaining a server that does nothing a correctly-designed RLS policy + RPC can't do.
2. **RLS is the authorization layer, not a bypassed formality.** Every table the client touches gets real, tested, participant-scoped policies (fixing L2 from day one). Privileged/atomic operations (accepting an offer, completing a transaction, sending a message) are `SECURITY DEFINER` Postgres functions that re-check authorization internally regardless of what RLS already allows — defense in depth, and the only place complex multi-row atomicity can live.
3. **Auth is Supabase Auth's native session model.** supabase-js in Expo persists sessions via `expo-secure-store`; access/refresh tokens are handled by the SDK. University-domain verification happens via a Supabase Auth **"before user created" hook** (Edge Function) that checks the signup email's domain against `university_domains` and rejects/redirects unrecognized domains — no separate email-regex code path (fixes L5 for auth specifically).
4. **Edge Functions are used narrowly**, only where a secret or outbound HTTP call is unavoidable: sending Expo push notifications (calling Expo's push API), the university-domain auth hook, and scheduled sweep functions invoked by `pg_cron` via `pg_net` (matching, offer/listing expiry, orphaned-upload cleanup). This is a small, auditable surface — not a second application.
5. **No API versioning problem, no route-authorization duplication** — there is exactly one way to read or write any given piece of data (a table with a policy, or an RPC), which structurally prevents the "second endpoint forgot the check" class of bug (fixes L3).

## 7.2 Why not alternatives

- **A custom Node/Express backend:** would duplicate what Postgres RPCs + RLS already do well, and adds a server to host, deploy, and secure for no functional gain with a single mobile client.
- **Firebase instead of Supabase:** the user has already chosen Supabase; it's a mature, Postgres-based choice with better relational modeling for a marketplace's transaction graph than Firestore's document model, and the team already understands Postgres SQL from the blueprint audit.
- **GraphQL layer:** unnecessary indirection for one client; `supabase-js` + generated types from the schema already give type-safe queries.
- **Full custom backend "just in case a web app happens":** premature — if a web app is ever built, it can be a second Supabase-native client (mobile-style) or, if it needs SSR/SEO, a thin Next.js layer added *then*, informed by real usage. Building that now is speculative work against a requirement that doesn't exist (violates "no speculative flexibility").

## 7.3 Client-side structure (single Expo app, no monorepo needed yet)

```text
univmarket-mobile/
  app/                    expo-router screens (file-based routing)
  src/
    lib/
      supabase.ts         client init (anon key, SecureStore persistence)
      types.ts            generated + hand-written domain types (from `supabase gen types`)
      validation.ts       zod schemas for listing/offer/etc. forms
      tokens.ts           design tokens (colors, spacing, type scale)
    features/
      listings/ offers/ messaging/ transactions/ auth/ profile/ ...
    components/           design-system primitives (Button, ListingCard, ...)
  eas.json
  app.config.ts
supabase/
  migrations/             schema, from a clean initial migration
  functions/              Edge Functions (push, auth-hook, sweeps)
  config.toml
  seed.sql
```

A monorepo (`packages/shared`, etc.) is **not** justified yet — there is one client. Revisit only if/when a second client (web) is actually built; at that point extracting `types.ts`/`validation.ts` into a shared package is a small, low-risk refactor, not a foundational decision to make now.

## 7.4 Open decision flagged: admin/moderation without a web app

Mason Market's moderation dashboard is a web-only feature this plan explicitly is not porting (no web app). UnivMarket still needs to suspend abusive users, resolve reports, and review disputes. Recommended approach, staged:

- **MVP (Phase 1–12):** moderation is performed directly via **Supabase Studio** (the built-in table editor/SQL runner) plus a small library of **admin RPCs** (`admin_suspend_user`, `admin_resolve_report`, `admin_hide_listing`) that enforce the audit-logging and validation a raw UPDATE wouldn't. This is honest about being a manual, founder-operated process at pilot-campus scale — appropriate given the current single-operator scale, and avoids building a UI for a workflow that will happen a handful of times a week initially.
- **P2 (post-pilot, if report volume justifies it):** a minimal internal tool — this could be a small mobile-app screen gated by an `admin` role claim (reuses the same Expo app and RLS model) rather than standing up a separate web app just for moderation. Only build a separate web admin panel if in-app admin screens prove awkward at scale.

---

# 8. Pattern Adoption Matrix

Summary view of §3 for quick reference — every listed treatment maps to one of four buckets:

| Bucket | Meaning | Examples |
|---|---|---|
| **Copy the pattern exactly** | Blueprint got this right; replicate the design (new code) | Atomic offer-acceptance RPC shape, transaction-gated two-way reviews, Wilson reputation, cursor pagination, soft-deleted listings, upload validation rules |
| **Copy the pattern, fix the defect** | Right idea, known bug | Offer acceptance (fix recipient logic), meetup workflow (add proposer attribution), blocking (move into the RPC choke point) |
| **Redesign for a requirement the blueprint didn't have** | Multi-university, trading, mobile-only auth | Universities/campuses/zones as tables, offers/offer_items normalized, Supabase-native auth (no HMAC cookie) |
| **New, doesn't exist in the blueprint** | Build from scratch | Cancellation/no-show/dispute workflow, notification preferences, analytics, admin RPCs |

No component of Mason Market is imported, forked, or extended. This matrix exists so implementation sessions know *why* a given schema/RPC looks the way it does without re-deriving the reasoning.

# 9. Repository Structure

**Single-repo, no monorepo, for now** — justified in §7.3. One repository:

```text
univmarket-mobile/     Expo app + Supabase project definitions (schema, functions, seed)
```

**Decision rule for when to introduce a monorepo:** only when a second client is actually being built (e.g., a future web app, or an internal admin web tool if §7.4's in-app admin approach proves insufficient). At that point, extract `src/lib/types.ts` and `src/lib/validation.ts` into a `packages/shared` package — this is a small, mechanical refactor precisely because they're written as plain TypeScript/Zod with no React Native-specific imports today. Do not create the package boundary speculatively.

---

# 10. Database Architecture

Fresh schema, one clean initial migration chain (no legacy files to reconcile with). Presented as design, not executed.

## 10.1 University/campus/identity tables (native from day one)

```sql
create table universities (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,       -- 'gmu', 'gwu'
  name         text not null,
  short_name   text not null,
  active       bool not null default false, -- launch gate
  created_at   timestamptz not null default now()
);

create table university_domains (
  domain        text primary key,           -- 'gmu.edu', 'masonlive.gmu.edu' — one domain maps to one school
  university_id uuid not null references universities(id) on delete cascade
);

create table campuses (
  id            uuid primary key default gen_random_uuid(),
  university_id uuid not null references universities(id) on delete cascade,
  slug          text not null,
  name          text not null,
  latitude      numeric, longitude numeric,
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

create table university_waitlist (   -- unrecognized-domain signup attempts; expansion-demand signal
  id         uuid primary key default gen_random_uuid(),
  email      text not null,
  domain     text not null,
  requested_at timestamptz not null default now()
);
```

## 10.2 Identity / profiles

`auth.users` is Supabase-managed; app-specific profile data lives in a parallel table keyed by the same id.

```sql
create table profiles (
  id                text primary key,        -- = auth.uid()
  university_id     uuid not null references universities(id),
  home_campus_id    uuid references campuses(id),
  display_name      text not null check (length(display_name) <= 100),
  bio               text not null default '',
  profile_image_url text,
  role              text not null default 'student' check (role in ('student','admin')),
  account_state     text not null default 'active' check (account_state in ('active','suspended','banned','deleted')),
  reputation_score  numeric(6,1) not null default 0,
  completed_transaction_count int not null default 0,
  joined_at         timestamptz not null default now(),
  last_active_at    timestamptz not null default now(),
  deleted_at        timestamptz
);

create function is_active_user(uid text) returns bool
  language sql stable security definer as
  $$ select exists (select 1 from profiles where id = uid and account_state = 'active') $$;
```

`is_active_user()` is the single choke point every RLS policy and RPC calls — fixes L4 structurally instead of per-feature.

## 10.3 Listings

```sql
create table listings (
  id                text primary key default gen_random_uuid()::text,
  seller_id         text not null references profiles(id),
  university_id     uuid not null references universities(id),   -- denormalized from seller for query speed
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
  accepts_trades    bool not null default false,               -- NEW vs blueprint: native trade opt-in
  image_urls        text[] not null default '{}',
  cover_image_url   text,
  tags              text[] not null default '{}',
  course_code       text, course_code_normalized text,
  professor_name    text, edition text, bundle_notes text,
  favorite_count    int not null default 0,
  view_count        int not null default 0,
  search_vector     tsvector,                                   -- weighted from day one, see §19
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  expires_at        timestamptz,
  last_refreshed_at timestamptz,
  deleted_at        timestamptz, deleted_by text, delete_reason text
);
-- indexes: (university_id, status, created_at desc, id desc) for scoped cursor pagination,
-- GIN(search_vector), GIN(tags), trigram on course_code_normalized, category/campus/moderation btree
```

## 10.4 Offers and trades (normalized from day one — see §12 for full rationale)

```sql
create table offers (
  id              text primary key default gen_random_uuid()::text,
  listing_id      text not null references listings(id),   -- the listing being pursued
  conversation_id text not null references conversations(id),
  from_user_id    text not null references profiles(id),
  to_user_id      text not null references profiles(id),
  kind            text not null check (kind in ('cash','trade','trade_plus_cash')),
  cash_amount     numeric(10,2) not null default 0 check (cash_amount >= 0),
  status          text not null default 'pending'
                  check (status in ('pending','accepted','declined','withdrawn','superseded','expired')),
  parent_offer_id text references offers(id),
  expires_at      timestamptz,
  created_at      timestamptz not null default now()
);
create table offer_items (
  offer_id           text not null references offers(id) on delete cascade,
  offered_listing_id text not null references listings(id),
  primary key (offer_id, offered_listing_id)
);
-- constraint (enforced in the send_offer RPC, not easily a CHECK): offered_listing_id must be
-- owned by from_user_id and status='available' at time of offer.
```

## 10.5 Messaging

```sql
create table conversations (
  id             text primary key default gen_random_uuid()::text,
  listing_id     text not null references listings(id),
  buyer_id       text not null references profiles(id),
  seller_id      text not null references profiles(id),
  last_message   text not null default '',
  buyer_last_read_at timestamptz, seller_last_read_at timestamptz,
  is_active      bool not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create table messages (
  id              text primary key default gen_random_uuid()::text,
  conversation_id text not null references conversations(id),
  from_user_id    text not null references profiles(id),
  to_user_id      text not null references profiles(id),
  body            text not null check (length(body) between 1 and 2000),
  type            text not null default 'text' check (type in ('text','offer','system')),
  offer_id        text references offers(id),      -- present when type='offer'
  created_at      timestamptz not null default now()
);
```
Note the deliberate simplification vs. the blueprint: **offer/meetup/presence fields no longer live on `messages`** (fixes L7). A message either carries free text, or references an `offer_id` (rendered as a card by reading the offer's current state), or is a `system` message auto-generated by an RPC (e.g., "Meetup confirmed for Thursday 3pm at Fenwick Library") for a readable timeline. Meetup/presence state lives entirely on `transactions` (§11).

## 10.6 Transactions (supports N listings for trades)

```sql
create table transactions (
  id                  text primary key default gen_random_uuid()::text,
  listing_id          text not null references listings(id),  -- primary/target listing (convenience)
  offer_id            text references offers(id),
  buyer_id            text not null references profiles(id),
  seller_id           text not null references profiles(id),
  kind                text not null check (kind in ('sale','trade')),
  agreed_price        numeric(10,2),
  status              text not null default 'reserved'
                      check (status in ('reserved','meetup_scheduled','completed','cancelled','disputed')),
  meetup_zone_id      uuid references pickup_zones(id),
  meetup_time         timestamptz,
  meetup_proposed_by  text references profiles(id),
  buyer_confirmed_at  timestamptz, seller_confirmed_at timestamptz,
  completed_at        timestamptz,
  cancelled_at        timestamptz, cancelled_by text, cancellation_reason text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create table transaction_listings (   -- NEW vs blueprint: supports multi-item trades generically
  transaction_id text not null references transactions(id) on delete cascade,
  listing_id     text not null references listings(id),
  role           text not null check (role in ('target','offered')),
  primary key (transaction_id, listing_id)
);
-- partial unique index: at most one active transaction per listing
create unique index one_active_transaction_per_listing
  on transaction_listings (listing_id)
  where exists (select 1 from transactions t where t.id = transaction_id and t.status in ('reserved','meetup_scheduled'));
```

## 10.7 Trust, safety, engagement (adopted patterns)

```sql
create table ratings (
  id text primary key default gen_random_uuid()::text,
  transaction_id text not null references transactions(id),
  reviewer_id text not null references profiles(id),
  reviewee_id text not null references profiles(id),
  score smallint not null check (score in (1,-1)),
  tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (reviewer_id, transaction_id)
);
create table reports (
  id text primary key default gen_random_uuid()::text,
  reporter_id text not null references profiles(id),
  reported_user_id text not null references profiles(id),
  listing_id text references listings(id),
  transaction_id text references transactions(id),   -- NEW vs blueprint: disputes reference a transaction
  reason text not null, notes text,
  status text not null default 'open' check (status in ('open','reviewed','resolved')),
  created_at timestamptz not null default now()
);
create table blocks (
  blocker_id text not null references profiles(id),
  blocked_id text not null references profiles(id),
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)                    -- fixes a blueprint gap directly
);
create table favorites (user_id text references profiles(id), listing_id text references listings(id),
  created_at timestamptz not null default now(), primary key (user_id, listing_id));
create table saved_searches (id text primary key default gen_random_uuid()::text,
  user_id text not null references profiles(id), label text not null, query text not null default '',
  filters jsonb not null default '{}', normalized_key text not null, last_notified_at timestamptz,
  created_at timestamptz not null default now(), unique (user_id, normalized_key));
create table price_watches (user_id text references profiles(id), listing_id text references listings(id),
  last_seen_price numeric(10,2) not null, created_at timestamptz not null default now(),
  primary key (user_id, listing_id));
```

## 10.8 Notifications, push, background work

```sql
create table notifications (id text primary key default gen_random_uuid()::text,
  user_id text not null references profiles(id), type text not null, title text not null, body text not null,
  link text, meta jsonb, is_read bool not null default false, created_at timestamptz not null default now());
create table notification_preferences (user_id text primary key references profiles(id),
  messages bool not null default true, offers bool not null default true, meetups bool not null default true,
  saved_search_matches bool not null default true, price_drops bool not null default true,
  marketing bool not null default false);
create table device_push_tokens (id text primary key default gen_random_uuid()::text,
  user_id text not null references profiles(id), platform text not null check (platform in ('ios','android')),
  token text not null, created_at timestamptz not null default now(), last_seen_at timestamptz,
  unique (user_id, token));
create table outbox_events (id bigint generated always as identity primary key,
  kind text not null, payload jsonb not null, created_at timestamptz not null default now(),
  processed_at timestamptz, attempts int not null default 0);
create table admin_activity (id text primary key default gen_random_uuid()::text,
  actor_user_id text not null references profiles(id), action text not null,
  target_type text not null, target_id text not null, notes text, created_at timestamptz not null default now());
create table analytics_events (id bigint generated always as identity primary key,
  user_id text, event text not null, properties jsonb not null default '{}',
  created_at timestamptz not null default now());
```

## 10.9 RPCs (all `SECURITY DEFINER`, all re-check authorization internally)

| RPC | Purpose | Key invariant enforced |
|---|---|---|
| `is_active_user(uid)` | Choke-point suspension check | Used by every other RPC and several RLS policies (fixes L4) |
| `create_message(...)` | Atomic message + conversation upsert + notification + outbox, blocking check | Sole write path for messages — no direct INSERT grant on `messages` (fixes L3 structurally) |
| `send_offer(...)` | Create offer (+ offer_items for trades) + system message | Validates offered items are the offerer's own, available listings |
| `accept_offer(offer_id, actor_id)` | Lock offer + every involved listing; accept; decline/supersede competing offers touching any involved listing; create transaction + `transaction_listings`; reserve all involved listings | `actor_id = offer.to_user_id` — **never role-fixed** (fixes L1) |
| `counter_offer(...)` | Lock parent, supersede, insert new offer (roles swapped) | Actor must be `parent.to_user_id` |
| `propose_meetup` / `confirm_meetup` / `cancel_meetup` | Set zone/time/proposer; require confirmer ≠ proposer | Attribution fixes the blueprint's ambiguity |
| `confirm_transaction_completion(id, actor_id)` | Per-party confirm timestamp; both present → `completed` + mark **all** `transaction_listings` `sold` | Atomic across N listings, not just one (blueprint gap) |
| `cancel_transaction(id, actor_id, reason, category)` | Terminal cancel; restore **all** involved listings to `available` | `category` includes `no_show_buyer`/`no_show_seller` for reliability stats |
| `submit_review(...)` | Insert rating, gated on completed transaction + participant + not-already-reviewed; recompute reviewee's Wilson score | Identical semantics to the (correct) blueprint pattern |
| `increment_view_count(listing_id)` | Atomic counter | — |
| `admin_suspend_user` / `admin_resolve_report` / `admin_hide_listing` | Privileged actions, logged to `admin_activity` | Checks `profiles.role = 'admin'` internally, not just RLS |

## 10.10 Row-Level Security (illustrative policy set — real, not deny-all)

```sql
-- profiles: public-safe subset via a view; full row only to owner/admin
create view public_profiles as
  select id, display_name, profile_image_url, reputation_score,
         completed_transaction_count, joined_at, university_id, home_campus_id
  from profiles where account_state != 'deleted';
grant select on public_profiles to authenticated, anon;

create policy profiles_owner_full on profiles for select using (auth.uid()::text = id);
create policy profiles_owner_update on profiles for update using (auth.uid()::text = id);

-- listings: scoped to the viewer's own university by default (multi-university isolation)
create policy listings_select on listings for select using (
  moderation_state = 'visible' and deleted_at is null
  and university_id = (select university_id from profiles where id = auth.uid()::text)
  or seller_id = auth.uid()::text
);
create policy listings_insert on listings for insert with check (
  seller_id = auth.uid()::text and is_active_user(auth.uid()::text)
);
create policy listings_update_owner on listings for update using (
  seller_id = auth.uid()::text
  and not exists (
    select 1 from transaction_listings tl join transactions t on t.id = tl.transaction_id
    where tl.listing_id = listings.id and t.status in ('reserved','meetup_scheduled')
  )
);
-- no delete policy at all: soft-delete only, via the update policy (sets deleted_at)

-- messages/conversations/offers/offer_items/transactions/transaction_listings/ratings:
-- SELECT policies scoped to participants (auth.uid() in from/to, buyer/seller, or via join to transactions);
-- NO insert/update/delete grants to `authenticated` on these tables — all writes go through the
-- SECURITY DEFINER RPCs in §10.9, which is what makes L1/L3/L7's fixes structurally guaranteed
-- rather than convention-dependent.

-- favorites/saved_searches/price_watches/notifications/notification_preferences/device_push_tokens:
-- standard owner-only CRUD (user_id = auth.uid()) — simple enough to allow direct table access safely.

-- universities/campuses/pickup_zones/university_domains: public read where active; no client writes.
-- admin_activity/analytics_events/outbox_events: no client access — service-role/Edge Functions only.
```

**Realtime:** publication includes `messages`, `offers`, `transactions` — safe now because real policies exist (fixes L2). A policy regression test (`anon` sees 0 rows, non-participant sees 0 rows, participant sees exactly their own) is a CI gate before this ships (§22).

## 10.11 Migration hygiene

One clean initial schema migration, timestamped subsequent migrations for every change thereafter — same discipline the blueprint's CI (replay-from-empty) demonstrated works well. Adopt `supabase/config.toml` + CLI from the very first commit (the blueprint never had this — small process improvement, not a defect fix).

---

# 11. Transaction Model

## 11.1 Lifecycle

```text
Listing (available)
   ↓ buyer opens conversation (create_message RPC)
Conversation + messages
   ↓ buyer sends offer — cash / trade / trade+cash (send_offer RPC)
Offer (pending) ── counteroffer chain (counter_offer RPC, parent_offer_id) ── expiry (default 48h)
   ↓ recipient accepts (accept_offer RPC — recipient, never role-fixed)
      • locks offer + every involved listing
      • declines/supersedes competing pending offers on any involved listing
      • creates transaction (kind = sale|trade) + transaction_listings rows
      • reserves every involved listing
   ↓
Meetup: propose_meetup (attributed) → confirm_meetup (must be the other party) → status = meetup_scheduled
   ↓ presence: system messages for "on my way" / "arrived" (client-triggered, no new table needed —
     rendered via a lightweight RPC that posts a system message; no persistent presence state required)
   ↓
Exchange: confirm_transaction_completion — both parties confirm
   → status = completed, completed_at set, ALL transaction_listings' listings → sold
   ↓
Review window: submit_review (two-way, transaction-gated, unique per reviewer+transaction)
   ↓
Reputation recomputed (Wilson score) on profiles.reputation_score + completed_transaction_count
```

## 11.2 Cancellation, no-shows, disputes

- **Cancel** (`cancel_transaction`, either party, while `reserved`/`meetup_scheduled`): terminal state, restores every involved listing to `available`. Declined competing offers are **not** resurrected — instead, prior offerers on that listing get a "this item is available again" notification, which is simpler and re-engages exactly the right audience.
- **No-show:** a `cancellation_reason` category (`no_show_buyer` / `no_show_seller`) chosen by the wronged party once a scheduled meetup time has passed without completion. Feeds a **completion rate** stat on the profile (framed positively — "94% of scheduled meetups completed" — not a public shame counter) rather than a separate punitive score.
- **Dispute:** `reports.transaction_id` lets either party flag a transaction; status → `disputed`; resolved by an admin RPC back to `completed`/`cancelled`. No funds are ever held (no payments in scope), so disputes are reputational/moderation matters only — deliberately lightweight.
- **Auto-expiry (background job, §17/Phase-appropriate):** `pg_cron` sweep nudges reserved transactions inactive 7+ days, auto-cancels (`reason = 'expired'`) at 14 days to free stuck inventory.

## 11.3 Invariants (enforced by RPCs/RLS, not convention)

- At most one active (`reserved`/`meetup_scheduled`) transaction per listing — the partial unique index in §10.6.
- A listing's `status` changes only via a transaction RPC, or by its seller when no active transaction touches it (the RLS update policy's `not exists` clause) — closes the blueprint's contradiction window (L11) at the policy layer, not just in application code.
- Reviews require `transactions.status = 'completed'` — unchanged from the (correct) blueprint pattern.

---

# 12. Trade Model

## 12.1 Recommendation: trades are offers; a trade completes as a transaction — no separate pipeline

Identical reasoning to the original analysis, now simply built in rather than retrofitted: a trade is a negotiation outcome like a cash offer, so it reuses the entire accept/reserve/meetup/complete/review machinery via the `kind` field on `offers` and `transactions`.

```text
Offer = { cash_amount ≥ 0 } + { 0..N of the offerer's own listings }
  cash only        → kind = 'cash'           (today's Mason-Market-equivalent behavior)
  items only       → kind = 'trade'          (Switch ↔ AirPods)
  items + cash     → kind = 'trade_plus_cash' (Switch ↔ AirPods + $50)
```

## 12.2 Design choices

- **Offered items must be existing, active listings owned by the offerer.** This is a deliberate constraint (max 3 items per offer, enforced in `send_offer`): it makes every offered item photographed, described, categorized, and moderatable for free, and it means "I want to trade my headphones I never listed" naturally becomes "quickly list your headphones first" — a liquidity mechanic, not friction.
- **`accept_offer` locks and reserves every listing on both sides of the trade in one transaction** (`transaction_listings` with `role = 'target' | 'offered'`), which is why the blueprint's single-`listing_id`-per-transaction design had to be generalized (§10.6) — trades genuinely need N listings per transaction, not a workaround.
- **Counteroffers can change any dimension** — cash amount, item set, or even flip from trade to trade-plus-cash — via the same `counter_offer` RPC, chained through `parent_offer_id`.
- **Completion marks every involved listing sold; cancellation restores every involved listing to available** — both handled generically over `transaction_listings`, so trade and non-trade transactions share one code path with no special-casing.

## 12.3 Trade UX

- Listing detail: "Make an offer" opens a sheet with Cash / Trade / Both segments; the Trade segment shows the viewer's own active listings as selectable chips (max 3) plus an optional cash delta.
- Sellers set `listings.accepts_trades` at listing-creation time (a simple toggle) to signal openness to trades; it's filterable in search/browse.
- Chat renders a trade card: thumbnails on both sides + cash delta + accept/counter/decline, backed by reading the referenced `offer_id`'s current state (not duplicated onto the message row — see §10.5).

---

# 13. Multi-University Architecture

## 13.1 Native from day one (§10.1) — behavior, not just schema

- **Default marketplace scope is the viewer's own university**, enforced at the RLS layer (§10.10 `listings_select` policy), not merely as a client-side filter — a student physically cannot fetch another school's listings by tampering with the app, because the database itself won't return them.
- **Pilot launch is still single-campus.** Native multi-university schema is a design decision now; turning on a second `universities.active = true` row and seeding its `campuses`/`pickup_zones` is a data operation, not a code change — that's the entire point of building it this way instead of retrofitting later (§4 L5, §26).
- **Unknown-domain signups are captured, not rejected silently:** the Auth "before-user-created" hook checks `university_domains`; unrecognized domains are redirected to a waitlist capture (`university_waitlist`) instead of a bare rejection — this doubles as free expansion-demand data.
- **Cross-university visibility is a deliberately deferred feature**, not an architectural gap: when wanted, it's a new `listings.visibility` enum (`university` default / `nearby` / `network`) plus a small policy extension — the current design doesn't block it, it just doesn't build it before there's a second live university to make it meaningful.
- **Reputation is global** (attaches to `profiles.id`, not scoped by university) since it should follow a person across schools if they transfer, consistent with the identity-lifecycle rules in §14.2.

## 13.2 What NOT to build

No per-university database/tenant isolation, no per-school admin hierarchy, no per-school app builds. One app, one database, a `university_id` column, and four small config tables handle the foreseeable number of campuses.

---

# 14. Authentication / Verification Architecture

## 14.1 Mechanism

- **Identity:** Supabase Auth only (email/password + OTP email confirmation). No parallel session system (fixes L6) — `supabase-js` in Expo persists sessions via `expo-secure-store`; refresh is automatic.
- **Authorization:** every table read/write goes through RLS + the RPCs in §10.9/§10.10 — `auth.uid()` is the only identity primitive the database trusts.
- **University verification:** a Supabase Auth **"before user created" hook** (Edge Function) checks the signup email's domain against `university_domains`; recognized → proceed and stamp `university_id` via a trigger that creates the matching `profiles` row; unrecognized → reject signup, capture to `university_waitlist` instead.
- **Password reset:** Supabase Auth's native flow; **use Supabase's own session-revocation** (`supabase.auth.signOut({ scope: 'others' })` / admin API) instead of reinventing the blueprint's `session_version` counter — one less custom mechanism to secure and test.

## 14.2 Verification lifecycle policy (deliberately simple at MVP)

| Concern | MVP design | Later |
|---|---|---|
| Student proof | Verified email on an allow-listed university domain | SheerID/enrollment API only if fraud data demands it |
| Unknown `.edu` domains | Waitlist capture, not silent rejection (§13.1) | Auto-provision universities from waitlist volume |
| Graduation / alumni | No action at MVP — most university email persists post-graduation | Optional annual re-verification ping; lapsed accounts get an "alumni" badge with reduced new-listing visibility, not removal |
| Changing universities | New verified email updates `profiles.university_id`; reputation follows the person | — |
| Duplicate accounts | Unique auth email (Supabase default) | Device-fingerprint heuristics only if abuse is observed |
| Suspended | `account_state = 'suspended'` checked by `is_active_user()` inside every RPC and relevant RLS policy — no per-feature ad hoc checks (fixes L4) | — |
| Banned | Distinct `account_state = 'banned'`; a Postgres Auth hook can additionally block re-authentication entirely | — |
| Deleted | Anonymize (`display_name`, `bio`, `profile_image_url` cleared; `account_state = 'deleted'`; `deleted_at` set) — **never hard-delete**, to preserve counterparty transaction/review evidence (fixes L10) | Data-export-on-request if usage/legal need arises |

---

# 15. Messaging / Realtime Architecture

## 15.1 Delivery matrix

```text
Event (message / offer / counteroffer / trade / meetup / transaction update)
   │  written via a SECURITY DEFINER RPC (§10.9), which also writes an outbox_events row
   ▼
 app foregrounded on the relevant screen ──→ Supabase Realtime (participant-scoped RLS, §10.10)
 app foregrounded elsewhere ────────────────→ Realtime on a per-user channel (badge updates)
 app backgrounded/closed ───────────────────→ Expo push, delivered by an Edge Function draining
                                               outbox_events, respecting notification_preferences
```

## 15.2 Why this is safe from day one (unlike the blueprint)

Realtime is only turned on for `messages`, `offers`, and `transactions` **once their RLS policies exist and are tested** (the CI gate described in §10.10/§22) — there is no window where a Realtime feature ships against a deny-all or missing policy set, which is exactly the failure mode found in Mason Market (L2). The client authenticates its Realtime channel with the same Supabase session used for everything else — no separate real-time auth mechanism to build or secure.

## 15.3 Scope discipline

Build: live thread updates, live offer/transaction card updates, per-user notification badge. **Do not build:** typing indicators, delivery/read receipts beyond the existing `*_last_read_at` timestamps, message reactions — all post-launch polish at best, and none affect whether a transaction completes safely.

---

# 16. Notifications Architecture

## 16.1 Single channel: Expo push (no web-push needed — mobile-only)

- `device_push_tokens` stores Expo push tokens per device; registered on app launch/login via `expo-notifications`.
- An Edge Function (invoked on a short `pg_cron` interval, or immediately best-effort with the outbox table as the retry backstop) drains `outbox_events`, calls the Expo Push API, and prunes dead tokens (Expo returns delivery-receipt errors for unregistered devices).
- **Preferences are server-side from day one** (`notification_preferences`) — the blueprint's localStorage-only opt-out (lost on reinstall, no per-category control) is explicitly not repeated.
- **Categories:** transactional (messages/offers/meetups/transaction updates — default on), matching (saved-search/wanted/price-drop — default on), marketing (default **off**).
- **Deep linking:** every push payload carries a route (`/messages/[conversationId]`, `/transactions/[id]`) handled by `expo-linking`.
- **Suppression:** no push for a conversation the user is actively viewing (client reports current screen); collapse multiple messages from the same conversation into one notification.

---

# 17. Marketplace Liquidity Strategy

Unchanged in substance from first-principles marketplace strategy — this is a product problem, not a backend-coupling problem, so it carries over regardless of the architecture pivot.

## 17.1 Product features

| Feature | Priority | Note |
|---|---|---|
| Wanted listings | P0 | Give it real visual prominence in the mobile IA, not a buried tab |
| Saved searches + match notifications | P0 | Matching runs as a batched background sweep (§4 L8), not inline on write |
| New-listing → wanted/saved-search matching | P1 | Title-similarity matching, not just category+budget |
| Price-drop alerts | P0 | — |
| "Students are looking for..." demand strip | P1 | Surfaces wanted-listing counts by category to induce supply |
| Free-items shelf | P1 | `price = 0` filter, given a home-screen shelf |
| Listing refresh / easy repost | P1 | One-tap renew push before expiry |
| Native share sheet + public deep-link landing | P1 | Even mobile-only, a shared listing link needs *some* landing surface for non-users — a minimal, unauthenticated single-listing web page (static, no app) is the smallest thing that could work; evaluate once share volume is measurable, don't build speculatively |
| Trade offers generate inventory | P1 | Because offered items must be listings (§12), every trade proposal creates supply |
| Move-in/move-out seasonal shelf | P2 | Timed to the academic calendar |

## 17.2 Growth/marketing playbook (operations, not engineering)

Campus ambassadors seeding initial supply, launch timing aligned to move-in/move-out weeks, referral mechanics deferred until organic loops are measurable. Identical reasoning to the original analysis: features that create/match **demand signals** are product work; creating **initial supply** is an operations problem, and the biggest lever (launch timing) costs zero engineering.

---

# 18. Trust / Safety Strategy

- **Verification:** university-domain gate (§14), the table-stakes baseline.
- **Blocking:** enforced **inside** `create_message`/`send_offer` (the only write paths — §10.10), not per-route, so there is structurally no second endpoint to forget the check on (fixes L3 for safety specifically). Self-block prevented by a CHECK constraint (fixes a blueprint gap directly). Blocked users' listings mutually hidden.
- **Reporting:** listing, profile, and conversation report entry points; `reports.transaction_id` for disputes (new capability vs. blueprint).
- **Moderation:** Supabase Studio + admin RPCs for MVP (§7.4); every admin action logged to `admin_activity`.
- **Suspension/ban:** `is_active_user()` choke point (§10.2) means suspension is real everywhere immediately, not route-by-route.
- **Meetup safety:** curated `pickup_zones` with safety notes per campus (§10.1), preferring public/camera-covered spots.
- **Evidence retention:** soft-deleted listings, anonymized-not-deleted accounts (§14.2), messages retained per a written retention policy (a launch requirement, not engineering).
- **Deterministic risk rules before ML (P2):** account age × posting volume, duplicate images across listings (perceptual hashing), repeated external links in messages, price outliers, repeat-report thresholds → flag to the admin queue. No ML scam model until there's labeled moderation data to train on.

# 19. Search Strategy

## 19.1 MVP — built weighted from day one (cheap improvement over the blueprint's unweighted version)

Postgres `tsvector` + GIN, `setweight('A', title) || setweight('B', tags || course_code) || setweight('C', description)`, `websearch` query parsing, university-scoped (§10.10), cursor pagination, trigram index on `course_code_normalized` for typo-tolerant course lookups. Doing the weighting now costs nothing extra since the schema is new anyway — no reason to ship the blueprint's unweighted version and fix it later.

## 19.2 Improved (P1–P2)

1. Title trigram fallback when weighted FTS returns few results (typo tolerance beyond course codes).
2. A small curated synonym map (fridge/mini-fridge/refrigerator; calculator/TI-84; couch/sofa) applied at query time in the app layer — promote to a table only if it grows large.
3. Campus-aware ranking (boost, don't filter) once a second campus/university exists.
4. **Zero-result logging from day one** (`analytics_events`) — the input that will actually tell you whether search needs more investment.

## 19.3 Later (evidence-gated)

Semantic/embedding search only if zero-result analytics show synonyms/weighting genuinely aren't enough at real inventory volume. No pgvector, no external search service, until that evidence exists.

# 20. Analytics Strategy

## 20.1 Tool

**PostHog** (mobile + server SDKs, generous free tier, funnels/retention built in) for behavioral events, plus the `analytics_events` Postgres table (§10.8) for server-authoritative funnel events emitted directly from RPCs — money-shaped metrics (transactions, offers, listings) are computed from the actual tables, not from an analytics SDK, so they're never at risk of client-side event loss.

## 20.2 Events

```text
signup_started · signup_completed · student_verified
search_performed {query, filters, result_count} · zero_result_search
listing_viewed · listing_saved · listing_created {kind} · wanted_created · listing_shared
message_started · offer_sent {kind} · counteroffer_sent · offer_accepted · offer_declined
trade_proposed · trade_accepted
listing_reserved · meetup_proposed · meetup_confirmed · transaction_completed {kind, agreed_price}
transaction_cancelled {reason} · review_submitted · report_submitted · user_blocked
push_opened {category} · notification_pref_changed
```

## 20.3 KPIs

Activity (DAU/WAU/MAU, verified), supply (active sell/wanted listings, new/week), demand (searches/user, zero-result rate), funnel (view→message, message→offer, offer acceptance rate, accepted→completed rate, median time-to-sale), trust (review rate on completions, no-show/dispute rate), retention (W1/W4, repeat buyer/seller rate). The composite **liquidity score** (sell-through rate + zero-result rate + time-to-first-reply) is what actually gates university #2 (§26).

# 21. Design System (mobile, placeholder branding)

**Branding is explicitly undecided** — "UnivMarket" is a temporary name, so no final color/logo identity should be treated as locked in. Recommended approach: build the design system around **neutral, swappable tokens** rather than committing to Mason Market's specific GMU green/gold (which is one school's brand, not a generic campus-marketplace identity):

- A small token set (primary/accent/ink/muted/surface/line colors, a type scale, radii) defined in one `tokens.ts` file, referenced everywhere — changing the final brand later is a one-file edit, not a redesign.
- Reuse **concepts**, not colors, from Mason Market's proven UX: price-first listing cards with a status pill, a trust/reputation badge on seller cards, a bottom tab bar as primary navigation, bottom-sheet filters instead of full-screen filter pages — these are validated interaction patterns independent of any color palette.
- No dark mode at MVP (matches the blueprint's own scope decision — not a regression, a deliberate cut).
- Typography: any clean system/variable font (e.g., Inter or the system font) rather than importing Mason Market's specific Geist/Outfit pairing, since that pairing isn't tied to any special requirement.

# 22. Testing Strategy

| Layer | Tooling | Scope |
|---|---|---|
| Unit | Jest + RNTL | validation schemas, offer/trade state helpers, formatting |
| **RLS policy suite** | pgTAP or Jest against a local Supabase instance | **Release gate**, not optional: for every sensitive table, assert anon gets 0 rows, non-participant gets 0 rows, participant gets exactly their own rows. This directly operationalizes the L2 lesson. |
| RPC/integration | Jest against local Supabase (CLI) | `accept_offer` (both counteroffer directions, competing-offer decline/supersede, multi-listing trade locking), `confirm_transaction_completion` (marks all listings sold), `cancel_transaction` (restores all listings), `submit_review` (gating), blocking enforcement inside `create_message` |
| Mobile UI | React Native Testing Library | screen logic with a mocked Supabase client |
| Mobile E2E | Maestro | auth → browse → sell → message → offer → trade → transaction → review; safety flow (report → block → suspend → locked out) |
| Security | dedicated suite | auth-hook domain validation, suspended/banned rejection at the RPC layer, upload validation (MIME + magic bytes, ported rule-for-rule from the blueprint) |
| Load | k6, pre-launch only | browse/search/message at 10× expected pilot-campus concurrency |

**Critical E2E scenarios** (adapted from the blueprint's own critical flows, §2.4):
1. **Sell flow:** signup → domain-verify → create listing → second user searches (university-scoped) → messages → offer → recipient accepts (test both cash and counteroffer-then-accept directions) → reserved → meetup proposed/confirmed → both confirm completion → listing sold → both review → reputation updates.
2. **Trade flow:** A proposes Switch↔AirPods+$50 (attaching an existing listing as the offered item) → B counters (drops the cash) → A accepts → both listings reserved atomically → meetup → dual confirm → both listings sold → reviews.
3. **Safety flow:** report from conversation → block (verify via RLS/RPC test that blocked messaging is rejected, not just hidden client-side) → admin suspends (via admin RPC) → suspended user's write RPCs are rejected → evidence retained (soft-deleted, not gone).
4. **Auth flow:** unrecognized domain → waitlist capture, not account creation; unverified email → rejected; banned account → cannot authenticate at all.

# 23. CI/CD Strategy

```text
PR pipeline:
  lint → tsc --noEmit → jest (unit + RPC/integration against Supabase CLI local stack) →
  RLS policy suite (release gate) → expo-doctor → migration replay on a clean local Postgres →
  gitleaks secret scan → npm audit --audit-level=high

main:
  all of the above → EAS Update (OTA JS update to existing installs)

release tags:
  EAS Build (iOS + Android) → EAS Submit → TestFlight / Play internal track → staged rollout

environments:
  local:   Supabase CLI (config.toml from commit 1 — no retrofit needed, unlike the blueprint)
  staging: separate Supabase project + Expo internal distribution build
  production: production Supabase project + store releases
```

No Vercel/Next.js deploy target exists in this architecture — one less moving part than the blueprint's pipeline.

# 24. AI Roadmap (unchanged reasoning, still evidence-gated)

| Feature | Classification | Rationale |
|---|---|---|
| Photo → title/category/description | Useful later (P2) | Real sell-flow conversion win once the flow itself is measured; not a moat |
| Price suggestions from own completed-transaction data | Useful later (P2, data-gated) | Never from a general LLM guess — only from real `transactions.agreed_price` history once volume exists |
| Semantic search | Not worth building yet | §19.3 — gate on zero-result evidence |
| Duplicate/perceptual-hash listing detection | Useful later (P2) | Cheap, deterministic, catches spam/reposts |
| Scam-risk assistance | Not worth building yet | Deterministic rules first (§18); ML needs labeled data that doesn't exist |
| Personalized recommendations | Not worth building yet | Meaningless below single-campus inventory/user thresholds |

# 25. Monetization Roadmap (post-liquidity, unchanged reasoning)

Free through the pilot campus and likely campus #2 — charging listing fees during the liquidity-proving phase directly undermines the thing being proven. Later, in rough order of fit: promoted listings (self-serve, needs real browse volume) → sponsored local-business placements in seasonal shelves → moving/storage partnerships around move-out season → university sustainability-office partnerships → optional seller upgrades (bump/renew, extra photos). No transaction fees or payment processing planned (no payments in scope at all — see §3 OUT OF SCOPE).

# 26. Expansion Roadmap

```text
Stage 0  Single pilot campus launch (schema already multi-university-capable — §13)
Stage 1  Prove liquidity at the pilot campus            ── gate: metrics below
Stage 2  University #2 — flip universities.active=true, seed campuses/pickup_zones,
         run the same launch-timing playbook. This is now a DATA + OPS operation, not
         a schema migration, precisely because §10.1/§13 were built natively.
Stage 3  Regional cluster, one launch per semester max
Stage 4  Repeatable, documented campus-launch playbook
Stage 5  Broader expansion only with capital/team to run parallel launches
```

**Gate criteria before any second university** (measured over a full semester at the pilot campus): >500 concurrent active listings, >100 completed transactions/month trending up, >35% sell-through within 30 days, <25% and declining zero-result search rate, >20% listing→conversation conversion, 30–60% offer acceptance rate, >30% of transactors doing a second transaction in-semester, >25% W4 retention. Identical bar to the original analysis — expansion readiness is a product-metrics question, not an architecture question, and the architecture is already ready.

---

# 27. Prioritized Backlog

**P0 — required for a real pilot-campus launch**

| Item | User impact | Tech impact | Difficulty | Depends on | Risk | Why P0 |
|---|---|---|---|---|---|---|
| Universities/campuses/pickup_zones schema + auth-domain hook | Correct verification from day one | New tables + Edge Function | M | — | Low | Cheapest possible time to build this is now |
| Core schema: profiles/listings/offers/offer_items/messages/conversations/transactions/transaction_listings + RLS + RPCs | The whole product | Large, one-time schema build | L | universities | Med — mitigated by the RLS test suite as a gate | Foundation |
| RLS policy test suite | Trust that Realtime/direct-client access is safe | New test category | M | schema | Low | Structurally prevents repeating L2 |
| Mobile shell + auth (Expo, expo-router, Supabase client) | App exists | New Expo project | M | schema | Low | — |
| Browsing/search/listing detail | Core value | consumes RLS-protected tables directly | M | auth | Low | — |
| Sell + wanted listing creation | Supply side | upload + validation | M | browsing | Low | — |
| Messaging + Realtime | Core interaction | `create_message` RPC + tested policies | M | schema | Med | — |
| Cash offers + counteroffers (both directions) | Negotiation works | `send_offer`/`accept_offer`/`counter_offer` RPCs | M | messaging | Low | Direct fix of L1, tested |
| Transactions: reserve → meetup → complete | Trust | RPCs in §10.9 | M | offers | Low | — |
| Reviews / reputation | Trust | `submit_review` RPC | S | transactions | Low | — |
| Blocking / reporting | Safety | enforced in RPCs | S | messaging | Low | — |
| Expo push + notification preferences | Retention | device tokens + outbox + Edge Function | M | transactions | Low | — |
| Privacy/ToS/prohibited-items policy + account deletion (anonymize) | Store approval | policy content + `account_state='deleted'` path | M | — | Low | **App Store/Play requirement** |
| Sentry + basic rate/abuse protection at the Edge Function layer | Operate safely | SDK wiring | S | — | Low | Can't operate blind |

**P1 — strong marketplace**

Trades (offer_items/trade UX/`accept_offer` multi-listing path — largely built with P0's schema, UI is the remaining work) · cancellation/no-show/dispute workflow + auto-expiry cron · background matching sweep (replaces none — there's no legacy inline scan to replace, just build it right) · search weighting refinement + synonyms + zero-result logging · meetup proposer attribution + curated zones (already native, this is the UI) · "students are looking for" demand strip · native share sheet + minimal public listing landing page · analytics events + PostHog + KPI queries.

**P2 — after initial usage**

Move-in/move-out seasonal shelves · AI photo-to-listing · price suggestions from own transaction data · perceptual-hash duplicate detection · deterministic risk rules → admin queue · in-app admin screens (if Supabase-Studio-based moderation proves insufficient) · Maestro E2E expansion · load testing · alumni re-verification flow.

**P3 — expansion era**

University #2 launch tooling/dashboards · cross-university visibility (`listings.visibility`) · promoted listings + sponsored placements · partnerships · campus ambassador tooling · referral mechanics.

**NOT NOW (explicit):** housing, jobs, services marketplace, social feed/followers, dating, events, integrated payments, auctions, AI campus assistant, semantic/vector search, per-school app builds, QR-code exchange confirmation, public listing Q&A/comments, GPS campus detection, dark mode, a standalone web app or admin panel (§7.4 covers the interim approach).

# 28. Dependency-Aware Implementation Roadmap

```text
Universities/campuses/pickup_zones + auth domain hook
        ↓
Core schema (profiles, listings, offers, messages, transactions) + RLS + RPCs
        ↓
RLS policy test suite (gate) ──────────────► Realtime enabled safely
        ↓                                           │
Mobile shell + auth ──► Browsing/search ──► Listing creation
        ↓                                           │
Messaging (create_message RPC) ────────────────────┤
        ↓                                           ▼
Offers/counteroffers (accept_offer, both directions fixed) ──► Trades (offer_items, multi-listing accept)
        ↓
Transactions (reserve→meetup→complete) ──► Cancellation/no-show/dispute
        ↓
Reviews/reputation ──► Reliability stats (completion rate)
        ↓
Push notifications (outbox + Edge Function)
        ↓
Analytics events ──► KPI dashboards ──► Expansion gate (§26)
        ↓
Completed transactions accumulate ──► Historical pricing ──► Price suggestions (AI, P2)
Moderation decisions accumulate ────► Labeled data ────────► Risk model (AI, later)
```

Ordering rules encoded above: (1) schema + RLS before any client screen touches a table; (2) the RLS test suite is a gate before Realtime, not a follow-up; (3) messaging before offers before transactions before reviews, since each depends on the previous being correct; (4) analytics before any expansion decision; (5) AI features gated on accumulated first-party data, never built speculatively.

# 29. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Empty-marketplace death loop** at launch | High | Fatal | Seasonal launch timing, seeding ops, wanted-listing prominence (§17) — unchanged from any marketplace's biggest risk |
| RLS policy mistakes at launch (no BFF safety net this time) | Medium | High | Policy test suite is a **required CI gate**, not a nice-to-have — this is the single biggest architectural risk of going BFF-less, and the mitigation is proportionate |
| Multi-item trade locking bugs (deadlocks, partial reservation) | Medium | Medium | Constrain v1 (max 3 offered items, single RPC owns all locking in a fixed order to avoid deadlock) |
| Greenfield build = no head start on implementation, only on design | High | Medium | This plan's phases are ordered so the product is shippable at multiple cut points; the blueprint audit removes design risk even though it doesn't remove build time |
| No web app = no natural admin surface | Medium | Medium | §7.4's staged approach (Studio+RPCs → in-app admin screens) is explicit, not left as a gap |
| App Store/Play rejection (UGC policy) | Medium | Medium | Report/block/moderation exist from P0; policy pages are P0; provide reviewer test credentials |
| Supabase Edge Function cold starts / cron reliability for push delivery | Low | Medium | Outbox table is a durable retry backstop regardless of delivery-attempt timing |
| Team bandwidth for a genuinely from-scratch build (schema + RLS + RPCs + mobile UI, nothing inherited) | High | High | Phases are cut-line-friendly (§30); trades and cancellation/dispute are explicitly P1, not required for a shippable MVP |
| Branding/name changes later | Low | Low | Token-based design system (§21) makes this a data change, not a redesign |

# 30. Definition of MVP (pilot-campus mobile launch)

A verified student at the pilot campus can, entirely on the mobile app:

1. Sign up with their university email, get auto-verified via the domain hook, set up a profile.
2. Browse/search/filter listings scoped to their own university; save favorites and searches.
3. Create a sell listing (camera-first, <60s) and a wanted listing.
4. Message a seller in real time; receive push when the app is backgrounded.
5. Send/receive cash offers and counteroffers **in both directions** correctly; accept atomically → reserved with buyer identity on the transaction.
6. Propose/confirm a campus meetup with clear proposer/confirmer roles; dual-confirm completion → listing sold automatically.
7. Leave a two-way verified review; see reputation on profiles.
8. Block and report users; suspended/banned users are actually locked out at the database layer.

**Trades are P1, not in the MVP cut** — the schema supports them from day one (§10.4/§10.6), but the UI and multi-listing accept-path testing are the first post-MVP addition, so the MVP ships against a smaller, faster-to-validate surface. **Cut lines if time-constrained:** ship without price watches UI (schema/RPC still trivial to add), without seasonal shelves, without notification-preferences UI (sensible defaults on). Do not cut: offers, transactions, meetups, reviews, block/report, push, the RLS test suite.

# 31. Definition of Launch-Ready (public pilot-campus push)

MVP plus: trades live · cancellation/no-show/dispute workflow + auto-expiry cron · background matching sweep · search weighting refined + synonyms + zero-result logging · analytics events + KPI dashboard live · load test passed at 10× expected pilot concurrency · store listings polished with reviewer test account · moderation runbook written (even if it's "Supabase Studio + these RPCs") · privacy/ToS/prohibited-items published · Sentry alerting configured · seeding-ops plan staffed for launch week.

---

# 32. EXECUTION HANDOFF

Thirteen phases, strictly ordered per §28. Every phase ends with green CI and a deployable app/backend. There is no "existing files to inspect" for the new codebase (it doesn't exist yet) — where a phase should consult the blueprint audit for a design pattern, that's called out explicitly.

## Phase 1 — Backend foundation: schema + RLS + RPCs

- **Goal:** the complete database — all tables in §10, every RLS policy, every RPC — exists in a fresh Supabase project, with the policy test suite green.
- **Blueprint reference:** §10.9's RPC table cites which blueprint pattern each RPC replicates and which lesson (§4) it fixes — read those rows before writing each function.
- **New files:** `supabase/config.toml`, `supabase/migrations/00000000000000_initial_schema.sql` (or split logically), `supabase/seed.sql` (dev seed: 1 university, 2 campuses, a few zones, test users), `supabase/functions/auth-hook-domain-check/`.
- **DB changes:** everything in §10.
- **Tests:** the RLS policy suite (anon/non-participant/participant matrix) for every sensitive table; RPC tests for `accept_offer` (both counteroffer directions), `confirm_transaction_completion` (multi-listing), `cancel_transaction` (restores all), `submit_review` (gating), `create_message` (blocking enforcement).
- **Dependencies:** none. **Completion:** `supabase db reset` replays cleanly; policy suite green; RPC suite green.

## Phase 2 — Mobile shell + auth

- **Goal:** Expo app with tab navigation, Supabase client wired, full auth lifecycle (sign-up with domain verification, sign-in, OTP, password reset) against Phase 1's backend.
- **New files:** `app/(auth)/...`, `app/(tabs)/...`, `src/lib/supabase.ts`, `src/lib/tokens.ts`, onboarding screens (welcome, select-university, verify, profile-setup).
- **Tests:** RNTL smoke; auth E2E (unrecognized domain → waitlist, unverified → rejected, banned → rejected).
- **Dependencies:** Phase 1. **Completion:** a real device can sign up, verify, and land on an empty tab shell.

## Phase 3 — Browsing, search, listing detail

- **Goal:** home feed, search + filters, listing detail, favorites, saved searches, price watches.
- **New files:** feature screens under `src/features/listings/`.
- **Tests:** cursor-pagination integration test; university-scoping regression test (a user genuinely cannot fetch another university's listings); Maestro smoke.
- **Dependencies:** Phase 2. **Completion:** browsing feels fast and is provably university-scoped at the DB layer, not just the UI.

## Phase 4 — Listing creation

- **Goal:** camera-first sell flow (<60s) + wanted flow + my-listings management (edit/renew/soft-delete).
- **Tests:** upload validation (MIME/magic-byte/size, ported rule-for-rule from the blueprint); Maestro create-listing flow.
- **Dependencies:** Phase 3. **Completion:** a listing created on-device is immediately visible to a second university-matched account.

## Phase 5 — Messaging + Realtime

- **Goal:** real-time chat via `create_message` and the Phase 1 policies.
- **Tests:** two-account Maestro chat test proving live delivery without polling; blocking-enforcement regression (attempt to message a blocker, expect rejection from the RPC, not just a hidden UI button).
- **Dependencies:** Phase 4. **Completion:** message sent on one device appears on a second device without refresh.

## Phase 6 — Cash offers + counteroffers

- **Goal:** offer/counter/accept/decline/withdraw UI on the Phase 1 `offers`/`send_offer`/`accept_offer`/`counter_offer` RPCs.
- **Tests:** **explicitly test both counteroffer directions** (buyer-initiated accepted by seller, and seller-counters accepted by buyer) — this is the direct regression test for L1.
- **Dependencies:** Phase 5. **Completion:** a full cash negotiation completes in either direction.

## Phase 7 — Transactions: reserve → meetup → complete

- **Goal:** transaction status screen, meetup propose/confirm with correct proposer/confirmer roles, dual-confirmation completion.
- **Tests:** proposer cannot self-confirm; completion marks all `transaction_listings` sold.
- **Dependencies:** Phase 6. **Completion:** §22's sell-flow E2E scenario passes end-to-end.

## Phase 8 — Reviews & reputation

- **Goal:** post-completion review prompt, profile reputation display (Wilson score, completed count).
- **Dependencies:** Phase 7. **Completion:** a completed transaction → review → visible reputation change.

## Phase 9 — Safety: blocking, reporting, account states

- **Goal:** block/report UI from listing/profile/thread; account deletion (anonymize) flow; policy pages (privacy/ToS/prohibited items) in-app.
- **Tests:** §22's safety E2E (report → block → admin suspend via RPC → suspended user's writes rejected).
- **Dependencies:** Phase 5+. **Completion:** safety E2E green; policies published in-app.

## Phase 10 — Trades

- **Goal:** `offer_items`, "accepts trades" toggle, Cash/Trade/Both offer sheet, trade cards, multi-listing `accept_offer` path fully exercised by real UI.
- **Tests:** §22's trade E2E (multi-item propose → counter → accept → both sides reserved → meetup → dual complete → both sold → reviews).
- **Dependencies:** Phases 6–7 (offer/transaction machinery proven with the simpler cash case first). **Completion:** the trade E2E scenario passes.

## Phase 11 — Cancellation, no-show, dispute + background jobs

- **Goal:** `cancel_transaction` UI with reason categories; admin dispute resolution via RPC; `pg_cron`-driven matching sweep (saved-search/wanted/price-drop) and stale-reservation auto-expiry; orphaned-upload cleanup.
- **Dependencies:** Phase 10. **Completion:** every transaction reaches a terminal state through the UI; matching runs as a background sweep, not inline.

## Phase 12 — Notifications

- **Goal:** Expo push registration, outbox-draining Edge Function, in-app Notifications screen + preferences UI.
- **Tests:** preference suppression, dead-token pruning, deep links open the correct screen.
- **Dependencies:** Phase 5 (outbox exists from `create_message`). **Completion:** a backgrounded device receives a correctly deep-linked push for messages/offers/meetups.

## Phase 13 — Analytics + launch hardening

- **Goal:** §20's events wired (PostHog + `analytics_events`), zero-result logging, search weighting/synonym refinement, k6 load test, store submission assets, Sentry alert rules, moderation runbook, seeding-ops checklist.
- **Dependencies:** all prior phases (instruments them). **Completion:** §31's launch-ready definition is fully satisfied.

---

# 33. Execution Prompts (one per phase)

**Common preamble — prepend to every phase prompt:**

> You are implementing one phase of the UnivMarket mobile app. The authoritative spec is `docs/MOBILE_APP_MASTER_PLAN.md` in this repository — read your phase's entry in §32 plus every section it references (especially §10 for schema/RLS/RPCs, §4 for the lessons each fix addresses) before writing code. This is a **greenfield build with a new Supabase project**; do not look for or attempt to reuse code from any other project. Rules: (1) match the schema/RLS/RPC design in §10 unless you find a concrete reason to deviate — if you do deviate, state why in your report; (2) modify only what your phase scopes; (3) never edit an already-shipped migration — add new timestamped migrations only; (4) every RLS-protected table needs a passing policy test before it's considered done; (5) never commit secrets; (6) when finished, report: files changed, migrations added, RPCs added/changed, test results, and any deviations from the plan with reasons — then STOP for review before the next phase. Definition of done = your phase's "Completion" criteria in §32.

**Phase 1 prompt:** Implement §32 Phase 1. Create a new Supabase project's initial schema exactly per §10 (universities/campuses/pickup_zones/university_domains/university_waitlist, profiles, listings, offers/offer_items, conversations/messages, transactions/transaction_listings, ratings/reports/blocks/favorites/saved_searches/price_watches, notifications/notification_preferences/device_push_tokens/outbox_events/admin_activity/analytics_events), the `is_active_user` function, and every RPC in §10.9 (`create_message`, `send_offer`, `accept_offer`, `counter_offer`, `propose_meetup`/`confirm_meetup`/`cancel_meetup`, `confirm_transaction_completion`, `cancel_transaction`, `submit_review`, `increment_view_count`, admin RPCs), plus the full RLS policy set per §10.10. Write the RLS policy test suite FIRST (anon/non-participant/participant matrix for every sensitive table) so it drives the policy implementation. Write RPC tests specifically covering: `accept_offer` accepted by the actual offer recipient in both negotiation directions (this is the L1 regression test — do not skip it), `confirm_transaction_completion` marking every row in `transaction_listings` sold, `cancel_transaction` restoring every involved listing, blocking enforcement living inside `create_message` (attempt a message between blocked users and expect rejection from the function, not from client code). Adopt the Supabase CLI (`config.toml`) from this commit. Seed one university (placeholder name, mark `active=true`), two campuses, a few pickup zones, and enough test users to exercise the RPC tests.

**Phase 2 prompt:** Implement §32 Phase 2. Scaffold an Expo + TypeScript + expo-router app: tab navigation, `supabase-js` client with `expo-secure-store` session persistence, design tokens per §21 (neutral, swappable — do not hardcode any specific university's brand colors), and the full auth lifecycle screens (welcome, select-university with waitlist capture for unrecognized domains, sign-up, OTP verification, sign-in, forgot/reset password with deep-link handling, profile setup) against the Phase 1 backend's auth hook. Write auth E2E tests for: unrecognized domain → waitlist row created, not an account; unverified email → session rejected; banned account → cannot authenticate.

**Phase 3 prompt:** Implement §32 Phase 3. Build Home (cursor-paginated listing grid, category chips), Search (filter bottom sheet, zero-result CTA), Listing detail (gallery, seller trust card using `public_profiles`, save/share — offer/trade buttons stubbed for Phase 6/10), and Saved (favorites/saved searches/price watches) screens, reading exclusively from the RLS-protected tables via the Supabase client — no bypass layer. Write a regression test proving a user cannot retrieve another university's listings regardless of client-side query construction (query the table directly, not just through your screen code, and confirm RLS blocks it).

**Phase 4 prompt:** Implement §32 Phase 4. Build the camera-first sell flow (photos → title → category → condition → price → campus/zone picker from Phase-1-seeded data → "open to trades" toggle → submit) targeting under 60 seconds end-to-end, the wanted-listing variant (budget instead of photos-required), and My Listings management (status, renew, edit, soft-delete via the update policy). Port the upload validation rules (MIME allowlist, magic-byte signature check, size cap, count cap) rule-for-rule as a design reference from the blueprint audit in §5 — implement fresh code, do not import anything.

**Phase 5 prompt:** Implement §32 Phase 5. Build Inbox and Thread screens using `create_message` for every send, with a live Supabase Realtime subscription per conversation (policies already exist from Phase 1 — verify they work, don't add new ones without reason). Write a two-device test proving live delivery, and a blocking-enforcement test proving a blocked user's message attempt is rejected by the RPC.

**Phase 6 prompt:** Implement §32 Phase 6. Build offer/counteroffer/accept/decline/withdraw UI on the Phase 1 `offers` table and RPCs. Write and pass a test for the full counteroffer chain in **both directions** — a buyer-sent offer accepted by the seller, and a seller-sent counteroffer accepted by the buyer — since this exact asymmetry was the most severe defect found in the blueprint audit (§4 L1) and must be proven fixed, not assumed fixed.

**Phase 7 prompt:** Implement §32 Phase 7. Build the transaction status screen (reserved → meetup_scheduled → completed timeline), meetup propose/confirm sheet using `pickup_zones` with correct proposer/confirmer role separation (the proposer cannot also confirm), and the dual-confirmation completion flow. Run the full §22 sell-flow E2E scenario end-to-end and report the result.

**Phase 8 prompt:** Implement §32 Phase 8. Build the post-completion review prompt and profile reputation display (score, completed-transaction count, review list) against the existing `submit_review` RPC and Wilson-score computation — no changes to the gating logic, it's already correct in the Phase 1 schema.

**Phase 9 prompt:** Implement §32 Phase 9. Build report/block entry points from listing, profile, and thread; the account-deletion (anonymize) flow; and in-app policy pages (privacy, ToS, prohibited items — draft placeholder content clearly marked as needing legal review). Run the full §22 safety E2E scenario (report → block → admin suspend via the admin RPC → suspended user's write attempts rejected → evidence still present, not deleted) and report the result.

**Phase 10 prompt:** Implement §32 Phase 10. Build the trade UI: `offer_items` selection (max 3 of the user's own active, available listings), the Cash/Trade/Both offer sheet, trade cards in the thread, and the "accepts trades" listing toggle + search filter. This exercises `accept_offer`'s multi-listing locking path for the first time with real UI — run the full §22 trade E2E scenario (multi-item propose → counter → accept → both sides reserved → meetup → dual complete → both sold → reviews) and report the result, including any deadlock or partial-reservation issues found.

**Phase 11 prompt:** Implement §32 Phase 11. Build the `cancel_transaction` UI with reason categories (including `no_show_buyer`/`no_show_seller`) and admin dispute resolution via RPC. Set up `pg_cron` jobs: a matching sweep for saved-search/wanted/price-drop notifications (batched and indexed — do not reintroduce an inline per-write scan), a stale-reservation nudge/auto-cancel job (7-day nudge, 14-day auto-cancel per §11.2), and orphaned-upload cleanup.

**Phase 12 prompt:** Implement §32 Phase 12. Wire `expo-notifications` registration to `device_push_tokens`, build an Edge Function that drains `outbox_events` and delivers via the Expo Push API respecting `notification_preferences` (with per-conversation collapse and dead-token pruning), and build the in-app Notifications screen + preferences UI. Verify deep links from a push notification open the correct conversation/transaction screen.

**Phase 13 prompt:** Implement §32 Phase 13. Wire PostHog (mobile + server) and server-side `analytics_events` emission for every event in §20.2, with zero-result search logging feeding a documented search-improvement backlog. Refine search weighting/synonyms per §19.2. Write and run a k6 load test against browse/search/message at 10× expected pilot-campus concurrency. Prepare store submission assets (screenshots, reviewer test account, review notes referencing the safety features already built), configure Sentry alert rules, and write the moderation runbook (documenting the Supabase Studio + admin-RPC workflow from §7.4) and the launch-week seeding-ops checklist per §17.2. Exit only when §31 (launch-ready) is fully satisfied.

---

*End of master plan. "UnivMarket" remains a placeholder name pending a final branding decision — no engineering artifact in this plan depends on the name. This document is the single authoritative planning artifact for a from-scratch product with its own Supabase backend; Mason Market is referenced throughout as a design blueprint only and is never a build dependency.*





