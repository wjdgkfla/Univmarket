---
version: 1
slug: "lib-app-dart"
primary_target: "lib/app.dart"
related_targets: ["lib/screens","lib/widgets"]
---

# UnivMarket app shell (all screens)

Scope: every screen in lib/ (Home, Search, Sell/Edit, Saved, Inbox, Chat, Listing detail, Profile, Auth, Recovery, Version gate). Visitor mode: Operate.

Audience/job: GMU/GWU students scanning campus listings between classes, saving, messaging, offering, posting. Constraints: behavior, routes, copy the tests pin, large-text (2x) and 320pt layouts must hold.

Direction: canon, chosen by the owner (Karrot model; Amazon/eBay/Facebook Marketplace craft bar). No concept roll: brief-pinned. Build path: code-led (no image generation available).

## Direction contract

THESIS: The item photo and its price are the interface; the school color is the only brand voice. Refuses the incumbent "Bento" AI look: drifting gradient blobs, coral-to-pink gradient buttons, mesh-gradient category tiles, 20px bordered cards, taglines.

OWN-WORLD: White ground, cool neutral greys (#F2F3F5 fills, #E6E8EB hairlines, #17191C ink). School color (GMU #006633, GWU #033C5A) on primary buttons, active tab, wordmark, "Free" price, own chat bubbles only. SF system type, prices bold with tabular figures. 8pt photo radius, 10pt controls, pill chips. SF Symbols style icons (CupertinoIcons) only. Hairline dividers, no card borders, no shadows except floating controls over photos.

STORY: Open the app and immediately see many real item photos with prices; tap one, the photo grows into the detail page; the seller, pickup spot and one clear Message action are right there.

FIRST VIEWPORT: Pinned white header: school-colored "GMUMarket" wordmark left, profile avatar right; full-width grey search field; horizontal text category chips (black when selected); "Fresh on campus" row with listing count; a two-column photo grid, square photos, bold price, 2-line title, pickup spot. iOS tab bar with translucent material at the bottom.

FORM: Category canon (marketplace photo grid + Karrot rows + sticky action bar), position 1, seed key: none (brief-pinned, no roll). Signature interaction: Hero photo transition grid to detail; sticky bottom action bar on detail.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
