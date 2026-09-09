# Native app implementation status

The existing Flutter project at the repository root is now runnable as an explicitly labeled persistent local marketplace demo. This replaces the older Expo prototype assumption; no framework migration was needed.

Implemented: three separate university sample feeds, search/filter/sort, saved listings, photo listing creation, editing/cancel, sold status, local conversations, outgoing cash offers, received-offer acceptance/reservation, local persistence with storage-failure rollback, phone layout, and a local preview launcher.

Read VERIFICATION.md for the checks performed and DEPLOYMENT_PLAN.md for the path to a real multi-user native release. The retained live adapter is unfinished, opt-in, and not production-ready. The public Mason Market backend was not modified.
