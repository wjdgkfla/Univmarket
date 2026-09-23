# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

Flutter app; iPhone is the primary verified device. Android ships from the same code and design language.

## Users

University students at George Mason (GMU) and George Washington (GWU) buying and selling used goods with other verified students on their own campus: textbooks, electronics, dorm furniture, bikes, bags, clothing. Typical moments: between classes, move-in and move-out weeks, end of semester.

## Product Purpose

A campus-only marketplace. Students list an item with a photo, others browse, save, message, and send cash offers, and they meet at a named campus pickup spot (for example Fenwick Library, Johnson Center, Gelman Library). No payments happen in the app. Success is a listing that finds a buyer on campus quickly and a meetup that actually happens.

## Positioning

Only verified students of the same university can see or contact each other: the market is fixed by the account's email domain (@gmu.edu → GMUMarket, @gwu.edu → GWUMarket). Pickup happens at known campus locations rather than at strangers' addresses.

## Operating Context

- Sign-in with a confirmed university email; no market switcher.
- Tabs: Home, Search, Sell, Saved, Inbox; plus Listing detail, Chat, Profile, Edit, Auth, Password recovery.
- Listing fields: title, price (0 = free), condition (Fair, Good, Like New), category tag, pickup zone, trades accepted, description, one photo, status (available, reserved, sold).
- Chat carries text, system messages, and cash offers that can be accepted (listing becomes reserved) or declined.
- Clearly labeled non-login sample listings seed each campus feed and cannot be contacted.

## Capabilities and Constraints

- Flutter (Dart 3.12), go_router, provider, Supabase backend. Redesign must not change data, routing, or backend behavior; the existing widget/regression test suite must keep passing.
- Large-text and narrow-screen resilience (320×568 at 1.3× text, 390×844 at 2× text) is a tested requirement.
- One photo per listing today.

## Brand Commitments

- Market names are "GMUMarket" and "GWUMarket" ("UnivMarket" before a school is known).
- The school color is the brand of each market: GMU green #006633 with gold #FFCC33; GWU navy #033C5A with buff #AA9868. It is the primary accent for actions, active navigation, and the header.
- Logo: the "Bag U" mark (a shopping bag with a U cut from its body), chosen by the owner on 2026-09-22. App icon is white on ink #17191C; in-app the mark takes the school color. Source of truth: `lib/widgets/brand_mark.dart`; icons regenerate with `flutter test tool/export_icons_test.dart`.
- Reference products named by the owner: Karrot Market (model), with a craft bar of Amazon, eBay, and Facebook Marketplace. The app must not look AI-generated.

## Evidence on Hand

- Six Unsplash sample photos in `assets/images/` (illustrative; see `assets/IMAGE_SOURCES.md`).
- No ratings, reviews, transaction counts, or user totals may be claimed beyond what the backend returns.

## Product Principles

1. The item is the hero: photo and price first, chrome last.
2. Campus trust is the differentiator; show school, verified-student status, and pickup spot wherever a decision is made.
3. Honest labeling: sample, reserved, and sold states are always unmistakable.
4. Familiar marketplace patterns over novelty; a student should know how to use it in seconds.

## Accessibility & Inclusion

Dynamic type up to 2× without overflow; 44pt minimum touch targets; WCAG AA contrast including school colors on white.
