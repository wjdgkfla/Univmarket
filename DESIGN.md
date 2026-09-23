---
name: UnivMarket
description: Campus-only student marketplace; the item photo and its price are the interface, the school color is the only brand voice.
colors:
  paper: "#FFFFFF"
  fill-grey: "#F2F3F5"
  hairline: "#E6E8EB"
  ink: "#17191C"
  ink-deep: "#0B0C0E"
  ink-soft: "#5B616B"
  ink-faint: "#6E747E"
  letterbox-grey: "#E9EBEE"
  gmu-green: "#006633"
  gmu-green-deep: "#004D26"
  gmu-green-wash: "#E6F2EA"
  gwu-navy: "#033C5A"
  gwu-navy-deep: "#022B41"
  gwu-navy-wash: "#E4ECF1"
  good: "#15803D"
  good-wash: "#E3F4E8"
  warn: "#B45309"
  warn-wash: "#FDF0DF"
  bad: "#CC2A22"
  bad-wash: "#FCE8E7"
typography:
  large-title:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.4px"
  wordmark:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "24px"
    fontWeight: 800
    letterSpacing: "-0.7px"
  headline:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "-0.3px"
  section-title:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "20px"
    fontWeight: 700
    letterSpacing: "-0.3px"
  nav-title:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "17px"
    fontWeight: 600
  price:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "17px"
    fontWeight: 700
    letterSpacing: "-0.2px"
    fontFeature: "tnum"
  body:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.55
  body-small:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.3
  caption:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "12.5px"
    fontWeight: 400
  button:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "16px"
    fontWeight: 600
  status-label:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "11px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0.3px"
  tab-label:
    fontFamily: "SF Pro (iOS system), Roboto (Android system)"
    fontSize: "10.5px"
    fontWeight: 500
rounded:
  status: "4px"
  photo: "8px"
  control: "10px"
  sheet: "16px"
  bubble: "18px"
  composer: "22px"
  pill: "999px"
spacing:
  hairline: "0.5px"
  xs: "4px"
  sm: "8px"
  grid-gap: "12px"
  gutter: "16px"
  grid-row: "22px"
components:
  button-primary:
    backgroundColor: "{colors.gmu-green}"
    textColor: "{colors.paper}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "0 18px"
    height: "50px"
  button-primary-disabled:
    backgroundColor: "{colors.fill-grey}"
    textColor: "{colors.ink-faint}"
  button-outlined:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "0 18px"
    height: "50px"
  chip-category:
    backgroundColor: "{colors.fill-grey}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "7px 14px"
    height: "36px"
  chip-category-selected:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
  input-field:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "14px"
  search-field:
    backgroundColor: "{colors.fill-grey}"
    textColor: "{colors.ink-soft}"
    rounded: "{rounded.control}"
  status-pill:
    backgroundColor: "{colors.fill-grey}"
    textColor: "{colors.ink-soft}"
    typography: "{typography.status-label}"
    rounded: "{rounded.status}"
    padding: "3px 6px"
  chat-bubble-mine:
    backgroundColor: "{colors.gmu-green}"
    textColor: "{colors.paper}"
    rounded: "{rounded.bubble}"
    padding: "9px 14px"
  chat-bubble-theirs:
    backgroundColor: "{colors.fill-grey}"
    textColor: "{colors.ink}"
    rounded: "{rounded.bubble}"
    padding: "9px 14px"
  avatar:
    backgroundColor: "{colors.gmu-green-wash}"
    textColor: "{colors.gmu-green-deep}"
    rounded: "{rounded.pill}"
    size: "40px"
  tab-bar:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink-soft}"
    typography: "{typography.tab-label}"
    height: "52px"
---

# Design System: UnivMarket

## Overview

**Creative North Star: "The Campus Bulletin, Photo First"**

UnivMarket is a native iOS-first marketplace built on the Karrot model with the craft bar of Amazon, eBay and Facebook Marketplace. The item photo and its price are the interface; every other element is quiet chrome that gets out of their way. The ground is plain white, the neutrals are cool greys, and the only brand voice is the school color of the market the student belongs to (GMU green or GWU navy), applied to a short, fixed list of places.

The density is a real marketplace's: a two-column grid of square photos with bold prices, list rows with 96pt thumbnails, pinned headers and a translucent iOS tab bar. Type is the platform's own system face, tightened for SF, with prices set bold in tabular figures. Depth comes from hairlines and grey fills, not from cards or shadows; shadows exist only on the small white controls that float over photos.

The system explicitly replaces the earlier "Bento" look: drifting gradient blobs, coral-to-pink gradient buttons, mesh-gradient category tiles, 20px bordered cards and taglines are rejected. It must not look AI-generated.

**Key Characteristics:**
- White ground, cool grey fills, hairline dividers, no card borders.
- School color as the single accent, on a fixed short list of surfaces.
- Photos at 8pt radius, controls at 10pt, sheets at 16pt, chips as full pills.
- Platform system type; prices bold with tabular figures.
- SF Symbols-style line icons (CupertinoIcons) only.
- Light mode only.

## Colors

A near-monochrome white and cool-grey system with one school color per market and three muted semantic hues for status.

### Primary
- **GMU Green** (gmu-green): the brand of GMUMarket. Primary filled buttons, the active tab, the wordmark and Bag U mark in the header, the verified-school seal, "Free" prices, your own chat bubbles, the send button, the saved heart, progress indicators. Deep and Wash variants (gmu-green-deep, gmu-green-wash) serve avatar initials, the accent status pill and your own offer card.
- **GWU Navy** (gwu-navy): the brand of GWUMarket, filling exactly the same roles with its own deep and wash steps. One market is live per account; the two never appear together except on the sign-in school list.
- **Neutral brand (pre-school):** before the school is known (sign-in, loading, update required, errors), the accent is Ink (ink) and its deep step is Ink Deep (ink-deep); the wash is Fill Grey.

The school secondary colors (GMU gold #FFCC33, GWU buff #AA9868) are declared in `schoolColors` but used by no surface today; they are brand references, not UI tokens.

### Neutral
- **Paper** (paper): page, scaffold, app bar, sheets, dialogs, input fill and tab bar (at 92% opacity under a 20pt blur).
- **Fill Grey** (fill-grey): search field, unselected chips, other people's chat bubbles, notices, photo placeholders, disabled buttons.
- **Hairline** (hairline): every divider, app-bar bottom edge, tab-bar top edge, input and outlined-button strokes.
- **Ink** (ink): primary text, icons, selected chip fill, snackbar background, focused input stroke.
- **Ink Soft** (ink-soft): secondary text (pickup spot, meta lines, labels), inactive tab icons and labels.
- **Ink Faint** (ink-faint): placeholders, hints, empty-state icons, disabled text. Kept at AA contrast on white.
- **Letterbox Grey** (letterbox-grey): only the area outside the 520pt content column on wide screens.

### Semantic
- **Good / Good Wash** (good, good-wash): reserved status, accepted offers.
- **Warn / Warn Wash** (warn, warn-wash): pending offers, banners.
- **Bad / Bad Wash** (bad, bad-wash): errors, declined offers, unread-message dot, sign-out.

### Named Rules
**The One Voice Rule.** The school color appears only on primary actions, the active tab, the wordmark and mark, the verified seal, "Free" prices, your own chat bubbles and send button, and the saved heart. Everything else is ink and grey.

**The Snap Rule.** Palettes change only at sign-in, so theme colors snap instead of tweening.

## Typography

**Display Font:** the platform system face (SF Pro on iOS, Roboto on Android); no bundled fonts.
**Body Font:** same.

**Character:** Native and unornamented. Weight and tight tracking create the hierarchy, not typeface contrast. Material's Roboto-tuned tracking is overridden for SF: 0 at 20pt and up, -0.4 at 17 to 19pt, -0.2 at 15 to 16pt, -0.1 below.

### Hierarchy
- **Large Title** (700, 34pt, 1.15): top-level tab titles (Search, Saved, Inbox), iOS large-title scale.
- **Wordmark** (800, 24pt, -0.7): "GMUMarket" / "GWUMarket" beside the Bag U mark, in the school color.
- **Headline** (700, 22pt, 1.25): listing title on detail, profile name.
- **Section Title** (700, 20pt): in-feed section heads such as "Fresh on campus", paired with an Ink Soft count on the right.
- **Nav Title** (600, 17pt): centered app-bar titles.
- **Price** (700, 16 to 17pt, tabular figures, -0.2): every price; 26pt/800 inside offer cards. "Free" replaces $0 and takes the school color.
- **Body** (400, 16pt, 1.55): listing descriptions; 15pt/1.4 to 1.45 in dialogs, empty states and notices.
- **Body Small** (400, 14pt, 1.3): two-line titles in grid tiles; 15.5pt in list rows.
- **Caption** (400 to 500, 12.5 to 13pt, Ink Soft): pickup spot, meta lines, helper text.
- **Status Label** (700, 11pt, +0.3, uppercase): only inside status pills.
- **Tab Label** (500, 600 when selected, 10.5pt): tab bar, text scaling clamped at 1.2x.

### Named Rules
**The Tabular Price Rule.** Prices are always bold with tabular figures, set through `priceText`, so columns of prices align and "Free" is never styled by hand.

**The Uppercase-Is-Status Rule.** Uppercase text exists only inside status pills (Sample, Reserved, Sold, offer states). It is never a heading, kicker or section label.

## Layout

Single-column phone layout with a 16pt horizontal gutter on every screen. On wider displays the app is centered in a 520pt maximum column over Letterbox Grey, so it always reads as a phone.

Home stacks a pinned white header (wordmark and school line left, avatar right, full-width search field), a horizontal row of category chips, a section title with count, and a two-column grid of listing tiles (12pt column gap, 22pt row gap; three columns only above 650pt, which the 520pt column does not reach). Search, Saved and profile lists use rows: 96pt square photo, 14pt gap, text column, 12pt vertical padding, hairline dividers inset to the text column.

Listing detail opens with a full-bleed photo that grows from the grid tile through a shared Hero transition, then title, price, seller, pickup spot and description, with a sticky bottom action bar (two equal buttons, 10pt apart, stacking vertically when large text needs it). Tab screens sit above a 52pt translucent tab bar.

Large text to 2x and 320pt-wide screens are tested requirements: text wraps rather than truncating where it carries a decision, and paired actions stack.

## Elevation & Depth

The system is flat. Separation comes from Paper against Fill Grey and from 0.5pt hairlines; app bars have zero elevation and no scroll tint. The tab bar is the one material layer: Paper at 92% opacity under a 20pt backdrop blur with a hairline top edge. Listing photos carry a 0.5pt black-at-6% inner hairline so white product shots do not bleed into the page.

### Shadow Vocabulary
- **Floating photo control** (`0 1px 6px rgba(0,0,0,0.12)`, on white at 94% opacity): the circular save heart on grid tiles and the round back/save buttons over the detail photo (Material elevation 1, shadow black at 20%).

### Named Rules
**The Only-Over-Photos Rule.** A shadow is allowed only on a control floating over a photo, where it must stay legible against any image. Cards, sheets, buttons and rows are shadowless.

## Shapes

One radius scale, each step tied to a kind of object: status pills 4pt, photos 8pt, controls (buttons, inputs, search field, notices, snackbars) 10pt, sheets and dialogs 16pt (sheets rounded on top only, with a Hairline drag handle), chat bubbles 18pt with a 6pt tail corner on the sender's side, the chat composer 22pt, chips and avatars full pill or circle. There are no bordered cards; grouping is done with Fill Grey panels or hairlines.

### Logo: the Bag U mark
A shopping bag (rounded body, 10-unit corner radius; round-capped arched handle) with a U cut from its body. It is drawn once by `BrandMarkPainter` in `lib/widgets/brand_mark.dart` on a 120-unit grid (mark bounds x 28 to 92, y 23 to 96), and that same painter renders both the in-app mark and every exported app icon (`flutter test tool/export_icons_test.dart`), so they cannot drift.
- **App icon / AppIconTile:** white mark on an Ink tile with the U knocked out to Ink; the in-app tile uses a 22.5% corner radius and appears on sign-in and other pre-school screens.
- **In-app BrandMark:** the mark in the school color with the U knocked out to Paper, 22pt high beside the wordmark in the Home header.

## Components

### Buttons
Plain, full-height, platform-native.
- **Shape:** gently rounded (10pt), 50pt minimum height, 18pt horizontal padding, 16pt/600 labels.
- **Primary (filled):** school color with white label; disabled is Fill Grey with Ink Faint text. One primary per decision (e.g. Message on detail).
- **Outlined:** Paper with a 1pt Hairline stroke and Ink label, the secondary action beside a primary.
- **Text:** school-colored 15pt/600, 44pt minimum target.
- **Press:** no ink splash on iOS.

### Chips
- **Style:** full pill, 36pt minimum height, 7 by 14pt padding, 14pt label; no border, no checkmark.
- **State:** Fill Grey with Ink text at rest; Ink fill with white 600 text when selected, 160ms ease-out color change. Selection is ink, never the school color.

### Cards / Containers
- **Listing tile (signature):** borderless. Square photo (8pt) with a floating save heart top-right, then Price (17pt), two-line title, and a location glyph with the pickup spot in Caption. Pressing scales the tile to 0.97 over 120ms ease-out; the photo is the Hero into detail. Sample listings carry an overlay "Sample" pill top-left; reserved shows a pill bottom-left; sold dims the photo with a 45% ink scrim and a white "Sold".
- **Listing row:** 96pt photo, title, "zone · condition · Trades ok" meta line, status pill and price.
- **Notices:** Fill Grey panels at 10pt with an info glyph and 13.5pt Ink Soft text.

### Inputs / Fields
- **Style:** Paper fill, 1pt Hairline stroke, 10pt radius, 14pt padding, 15pt Ink Soft labels and Ink Faint hints.
- **Focus:** stroke becomes Ink at 1.5pt.
- **Error:** Bad stroke (1.5pt when focused).
- **Search field:** Fill Grey, borderless, 10pt, search glyph in Ink Soft.
- **Chat composer:** Fill Grey, borderless 22pt capsule; Hairline stroke on focus; circular 34pt school-colored send button with an up arrow.

### Navigation
- **Tab bar:** five items (Home, Search, Sell, Saved, Inbox), outline icons that switch to filled when active, 24pt icons over 10.5pt labels. Active is school color, inactive Ink Soft. Unread messages show a 9pt Bad dot ringed in Paper on Inbox.
- **App bar:** Paper, flat, centered 17pt/600 title, Hairline bottom edge, chevron back glyph.

### Status Pill
Small 4pt tag, 3 by 6pt padding, uppercase Status Label. Tones pair a wash with its hue: good, warn, bad, neutral (Fill Grey/Ink Soft), accent (wash/deep), and overlay (ink at 70% with white text) for use on photos.

### Chat
Your bubbles are solid school color with white text; theirs are Fill Grey with Ink text; both 18pt with a 6pt tail corner, 78% max width. Offer cards are larger bubbles (your own on the school wash, theirs on Fill Grey) with a tag glyph, the offer state pill, a 26pt/800 price and Accept/Decline for received pending offers.

### Avatar
Circle in the school wash with bold initials in the school deep color, 38% of the diameter, not scaled with text size.

### Empty State
Centered in a 320pt column: 44pt Ink Faint line icon, 18pt/700 title, 15pt Ink Soft message, optional primary button.

### Dialogs and sheets
Dialogs are adaptive (`AlertDialog.adaptive` + `dialogAction` in `listing_detail_screen.dart`): native CupertinoAlertDialog on iOS (Mark as sold is a destructive action; the cash offer uses a CupertinoTextField), Material on Android (16pt radius, FilledButton primary). Tab screens (Search, Saved, Sell, Inbox) use the large-title pattern in `ScreenScaffold(title:)`: a 34pt title that scrolls under a blurred 44pt bar, with a 17pt inline title fading in once it has scrolled off. The Sell form keeps Material DropdownButtonFormField fields (10pt, chevron-down glyph) for the same reason. Bottom sheets are Paper with 16pt top corners and a Hairline drag handle.

## Do's and Don'ts

### Do:
- **Do** let the photo and price lead every listing surface; chrome stays ink, grey and hairline.
- **Do** confine the school color to the One Voice list: primary buttons, active tab, wordmark and mark, verified seal, "Free", own bubbles and send, saved heart.
- **Do** render every price through `priceText` (bold, tabular figures, "Free" in school color).
- **Do** use the radius scale by object type: 4 status, 8 photo, 10 control, 16 sheet, pill for chips.
- **Do** separate with 0.5pt Hairline dividers and Fill Grey panels.
- **Do** use CupertinoIcons line glyphs, filled only for an active or toggled state.
- **Do** keep sample, reserved and sold states unmistakable with status pills and the sold scrim.
- **Do** keep 44pt touch targets and hold layouts at 2x text and 320pt width.
- **Do** draw the logo only through `BrandMarkPainter` / `BrandMark` / `AppIconTile`.

### Don't:
- **Don't** use gradients, gradient buttons, blobs or mesh-gradient tiles.
- **Don't** put borders or shadows on cards; shadows belong only to controls floating over photos.
- **Don't** use the school color for selected chips, secondary text or decoration.
- **Don't** use uppercase or letter-spaced labels outside status pills; no kickers or taglines.
- **Don't** bundle or substitute a display font; the system face is the type.
- **Don't** redraw or export the logo from anything other than `BrandMarkPainter`.
- **Don't** wire the dark palette or add a dark-mode surface; the system is light only.
