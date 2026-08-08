# UnivMarket Local Prototype Design

## Job and audience

This is a high-fidelity local Expo mobile prototype for verified university students who need a trustworthy, fast way to discover, buy, sell, and arrange campus exchanges. It operates in Demo Mode with seeded pilot-campus data, while preserving the architecture of the production mobile app described in `docs/MOBILE_APP_MASTER_PLAN.md`.

## Outcome and proof

A user can explore an active marketplace, search and save listings, open a listing, message a seller, negotiate a cash offer, accept it, and follow the reservation-to-meetup state. They can also create a sell listing and inspect profile reputation. The complete flow must work locally without a Supabase project or credentials.

## Selected direction

- **Mode:** Operate. Fast scanning, clear choices, and native mobile affordances are the visual priority.
- **Visual thesis:** A polished, editorial campus marketplace: photo-led inventory, warm neutral surfaces, assertive type hierarchy, restrained indigo brand accent, and precise status color. Avoid generic gradients, excessive glass, dense nested cards, and school-specific hardcoding.
- **Navigation:** Home, Search, Sell, Saved, and Inbox are primary tabs. Profile opens from the header/avatar.
- **Focal moment:** Listing detail puts imagery, price, condition, seller trust, and Message/Make offer actions in the first interaction zone.

## Architecture and boundaries

- Build with Expo, React Native, TypeScript, and Expo Router.
- Organize code by features: listings, search, favorites, messages, offers, transactions, profile, onboarding.
- Screens access a typed local repository interface rather than raw seeded data. Repository methods mirror future Supabase reads and RPCs, allowing the backend adapter to replace Demo Mode without rewriting feature screens.
- Demo Mode is visible in the app. It is not evidence of production authentication, RLS, Realtime, Storage, or push-notification security.
- This slice implements a cash-offer path and a sell-listing creation flow. Trades, real authentication, and cloud integrations remain part of later master-plan phases.

## States and interactions

- Seed a realistic pilot-campus market with active listings, sellers, favorite state, conversation history, offer history, reputation, and a transaction timeline.
- Support loading, empty-search, empty-saved, optimistic-action, success, and recoverable-error states.
- Cash offer states: pending, countered, accepted, declined, withdrawn. Acceptance moves a listing into reserved state and surfaces a meetup timeline.
- Touch targets, contrast, labels, and text sizes must meet mobile accessibility expectations.

## Verification

- Unit-test repository transitions for favorites, messages, offer chains, and reservation state.
- Add component/screen smoke tests for the primary browsing-to-offer path.
- Run Expo/TypeScript quality checks and inspect the app on a mobile viewport before handoff.

