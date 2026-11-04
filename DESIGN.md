---
name: E-Voting Ketua Angkatan Teknik Elektro
description: Trustworthy kiosk voting for a supervised campus election.
colors:
  primary: "#0d5c49"
  primary-strong: "#084334"
  primary-soft: "#dcefe6"
  accent: "#f0b429"
  accent-soft: "#fdf1cf"
  danger: "#b33a2f"
  danger-soft: "#fbe7e4"
  paper: "#eef1ec"
  surface: "#ffffff"
  surface-soft: "#f6f8f4"
  ink: "#12211d"
  ink-soft: "#46564f"
  muted: "#64736c"
  line: "#d8ded6"
  line-strong: "#b9c4ba"
typography:
  display:
    fontFamily: "Bricolage Grotesque, Segoe UI, sans-serif"
    fontSize: "clamp(2.8rem, 6.2vw, 5.2rem)"
    fontWeight: 700
    lineHeight: 0.98
    letterSpacing: "-0.055em"
  headline:
    fontFamily: "Bricolage Grotesque, Segoe UI, sans-serif"
    fontSize: "clamp(1.8rem, 4vw, 2.8rem)"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.045em"
  title:
    fontFamily: "Bricolage Grotesque, Segoe UI, sans-serif"
    fontSize: "1.22rem"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.025em"
  body:
    fontFamily: "Plus Jakarta Sans, Segoe UI, sans-serif"
    fontSize: "0.9rem"
    fontWeight: 400
    lineHeight: 1.6
    letterSpacing: "0em"
  label:
    fontFamily: "Plus Jakarta Sans, Segoe UI, sans-serif"
    fontSize: "0.82rem"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "0.02em"
  mono:
    fontFamily: "IBM Plex Mono, ui-monospace, monospace"
    fontSize: "0.74rem"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "0.08em"
rounded:
  xs: "6px"
  sm: "9px"
  md: "10px"
  lg: "12px"
  xl: "16px"
  2xl: "20px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  2xl: "28px"
  3xl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface}"
    rounded: "{rounded.md}"
    padding: "11px 20px"
    height: "44px"
  button-primary-hover:
    backgroundColor: "{colors.primary-strong}"
    textColor: "{colors.surface}"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "11px 20px"
    height: "44px"
  button-secondary-hover:
    backgroundColor: "{colors.surface-soft}"
    textColor: "{colors.primary}"
  button-danger:
    backgroundColor: "{colors.danger-soft}"
    textColor: "{colors.danger}"
    rounded: "{rounded.md}"
    padding: "11px 20px"
    height: "44px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.ink-soft}"
    rounded: "{rounded.md}"
    padding: "11px 20px"
    height: "44px"
  button-sm:
    rounded: "{rounded.sm}"
    padding: "7px 12px"
    height: "34px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    padding: "11px 13px"
  panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xl}"
    padding: "clamp(20px, 3vw, 28px)"
  badge-open:
    backgroundColor: "{colors.primary-soft}"
    textColor: "{colors.primary}"
    rounded: "{rounded.pill}"
    padding: "7px 13px"
  badge-paused:
    backgroundColor: "{colors.accent-soft}"
    textColor: "#6e4a00"
    rounded: "{rounded.pill}"
    padding: "7px 13px"
  badge-closed:
    backgroundColor: "#eef0ed"
    textColor: "#55635c"
    rounded: "{rounded.pill}"
    padding: "7px 13px"
---

# Design System: E-Voting Ketua Angkatan Teknik Elektro

## Overview

**Creative North Star: "The Trusted Ballot Desk"**

This is a civic instrument, not a campaign poster. The interface borrows the calm of an official polling desk: soft paper-green ground, white forms, a dense evergreen used for authority, and a single amber mark that reads like a stamp or a highlighter. Every surface is quiet enough that the voter's next action is unmistakable, and official enough that the result feels legitimate.

The world is deliberately flat and border-led. Thin lines, generous white space, and a restrained green palette carry structure; depth appears only where a physical artifact is implied, most clearly the dark ballot card with its torn stub and hard offset shadow. Typography does the persuasion: Bricolage Grotesque gives headlines a slightly condensed, notice-board confidence, while Plus Jakarta Sans keeps instructions plain and Indonesian copy readable at kiosk distance.

This is an Operate-first system. It serves two scenes: a queue of students at a shared device who need to finish in seconds, and an organizer under pressure who needs status and recovery paths to be obvious. Brand expression lives in precise details, not decoration.

**Key Characteristics:**
- Paper-green ground with white forms and evergreen authority.
- Amber used sparingly as a stamp, marker, or live-status signal.
- Flat, border-defined surfaces; a single hard offset shadow for the ballot artifact.
- Display type with tight, negative tracking; body type plain and legible.
- Rounded but restrained geometry: 9–20px radii, pill-shaped status only.

## Colors

A low-chroma institutional green palette warmed by paper and one amber accent.

### Primary
- **Evergreen Authority** (#0d5c49): Primary actions, links, active status, focus rings, and display accents. It signals official action and verified state.
- **Deep Evergreen** (#084334): Hover and pressed state for primary actions only. Never a background for large sections.
- **Ballot Green Wash** (#dcefe6): Selected/open status, primary stat card, ghost-button hover, and the verifying halo around the success mark.

### Secondary
- **Stamp Amber** (#f0b429): The single expressive accent. Used for live-status dots, ballot-stub labels, selection highlight, section markers, and the paused/warning badge.
- **Amber Paper** (#fdf1cf): Warning notices, paused badges, lock icons, and other cautionary-but-not-destructive states.

### Neutral
- **Paper Green** (#eef1ec): Page ground, including its two very soft radial tints (amber at top-right, evergreen at left).
- **Clean White** (#ffffff): Panels, cards, inputs, and the main content surface.
- **Soft Field** (#f6f8f4): Secondary surfaces, table headers, disabled inputs, nesting inside panels.
- **Ink** (#12211d): Primary text and the dark ballot card ground.
- **Soft Ink** (#46564f): Secondary labels, descriptive paragraphs, and navigation links.
- **Muted Slate** (#64736c): Hints, metadata, timestamps, and supporting copy.
- **Hairline** (#d8ded6): Default dividers, card borders, and table rules.
- **Strong Hairline** (#b9c4ba): Input borders and controls that must read as interactive.

### Named Rules
**The One Stamp Rule.** Amber is a mark, not a theme. Keep it under roughly 10% of any screen; it should feel like a stamp on paper, never a second brand color.

**The Green Means Action Rule.** Evergreen is reserved for things the voter or admin should act on, trust, or read as live. Do not use it for decorative fills or inactive states.

## Typography

**Display Font:** Bricolage Grotesque (with Segoe UI, sans-serif)
**Body Font:** Plus Jakarta Sans (with Segoe UI, sans-serif)
**Label/Mono Font:** IBM Plex Mono (ui-monospace, monospace)

**Character:** Bricolage gives headings the compact confidence of a printed notice; Plus Jakarta Sans keeps Indonesian instructions neutral and easy to scan. IBM Plex Mono appears only where a token, code, or stub label needs to read as a machine artifact.

### Hierarchy
- **Display** (700, clamp(2.8rem, 6.2vw, 5.2rem), 0.98): Hero and device-stage headlines only. Tracking tightens to -0.055em; this is the loudest the system gets.
- **Headline** (700, clamp(1.8rem, 4vw, 2.8rem), 1.1): Page titles, results title, dashboard heading. Tracking -0.045em.
- **Title** (700, 1.22rem, 1.1): Panel titles and candidate names. Tracking -0.025em.
- **Body** (400, 0.9rem, 1.6): Instructions, descriptions, and candidate copy. Keep measure near 62ch in panels, 65–75ch in prose.
- **Label** (600, 0.82rem): Field labels, nav, badges, metadata. Uppercase is not used; Indonesian copy stays sentence case.
- **Mono** (500, 0.74rem, 0.08em): Device tokens, ballot stub labels, and code-like strings.

### Named Rules
**The Two-Voice Rule.** Only Bricolage may carry negative tracking and large scale. Body and label text stay in Plus Jakarta Sans with normal tracking so the two voices never compete.

**The Kiosk Distance Rule.** Voter-facing headlines must remain legible at arm's length on a shared monitor; never reduce the display step on the device flow to fit more copy.

## Layout

The page uses a centered fixed-measure container: `min(1180px, calc(100% - 48px))` for public and admin surfaces, widening to `min(1200px, calc(100% - 48px))` on device screens. Gutters tighten to 32px below 640px. Vertical rhythm is built from 12–28px gaps inside panels and 18px between panels.

The landing hero is a two-column editorial split (1.15fr copy / 0.85fr ballot artifact) with a 36–96px clamp gap; it collapses to one column at 900px. The device flow mirrors that split (1fr stage / 0.8fr action card) and also collapses at 900px. Admin uses a four-column stat strip (collapsing to 2 at 900px, 1 at 420px) above a two-column panel grid that becomes one column at 900px.

Density is comfortable, not airy: 44px minimum control height, 11–13px input padding, 16px list-row padding, and 11px table cell padding. Long rosters scroll inside a bounded table (max-height 540px) with a sticky header rather than stretching the page.

## Elevation & Depth

Flat by default. Structure is carried by hairline borders and white-over-paper contrast, not by shadows. Two shadows exist, each tied to a specific physical metaphor: the dark ballot card uses a hard offset (`6px 6px 0 rgba(18, 33, 29, 0.12)`) so it reads as a printed slip lying on the desk, and the device action panel uses a soft ambient lift (`0 18px 45px rgba(18, 33, 29, 0.08)`) so the active task floats above the stage. The modal is the only genuinely elevated layer (`0 30px 80px rgba(0, 0, 0, 0.28)`) over a blurred ink backdrop.

### Shadow Vocabulary
- **Ballot offset** (`box-shadow: 6px 6px 0 rgba(18, 33, 29, 0.12)`): The dark hero/ballot card only. It is a printed-paper device, never a generic card shadow.
- **Task lift** (`box-shadow: 0 18px 45px rgba(18, 33, 29, 0.08)`): The device action panel and other single-purpose task surfaces.
- **Modal depth** (`box-shadow: 0 30px 80px rgba(0, 0, 0, 0.28)`): Dialogs above the blurred backdrop.

### Named Rules
**The Paper-Not-Plastic Rule.** No drop shadows on ordinary panels, cards, tables, or buttons. If a surface needs separation, use a hairline border or a tonal step, not a shadow.

## Shapes

Rounded but institutional. Panels use 16px, task cards 20px, dialogs 18px, inputs 9px, buttons 10px, and small controls 6–8px. Pills (999px) are reserved for status badges and tiny labels; they never become buttons.

The signature silhouette is the ballot card: a dark rounded rectangle with two circular notches cut into its left and right edges and a dashed tear line under a mono stub label. That receipt-like geometry is the only place the system allows playful physical detail.

Circular medallions (40–60px) carry candidate avatars, success marks, empty icons, and lock icons. They are always centered, never inline with body text.

## Components

### Buttons
- **Shape:** 10px radius, 44px minimum height, 11px × 20px padding (`btn-sm` drops to 8px radius, 34px height).
- **Primary:** Evergreen ground, white label, 0.9rem/700. Used once per view for the single most important action.
- **Hover / Focus:** Primary deepens to #084334 and lifts 1px; all buttons return to 0 on active. Focus is a 2px evergreen outline with 2px offset.
- **Secondary:** White ground with a strong hairline; hover shifts to soft field with an evergreen border and label.
- **Danger:** Soft red ground (#fbe7e4) with a red border and deep red label; never a solid red fill.
- **Ghost:** Transparent with soft-ink label; hover gains a ballot-green wash.

### Chips
- **Style:** Status badges use pill geometry, 7px × 13px padding, 0.78rem/700, and a hairline. Open = green wash/evergreen; paused = amber paper/amber-brown; closed = neutral grey.
- **State:** Badges describe election state only. Small `pill` labels (0.7rem) mark active/inactive candidates and are never interactive.

### Cards / Containers
- **Corner Style:** Panels 16px; nested cards 12–14px; dialogs 18px; ballot artifact 18px.
- **Background:** White on paper for panels; soft field for nested or preview content; ink for the ballot artifact.
- **Shadow Strategy:** See Elevation. Panels are flat with a hairline border.
- **Border:** 1px `#d8ded6` by default; strong hairline only on interactive controls.
- **Internal Padding:** `clamp(20px, 3vw, 28px)` for panels, 18px for candidate cards, 26px for dialogs.

### Inputs / Fields
- **Style:** White ground, 1px strong hairline, 9px radius, 11px × 13px padding, 0.9rem body type.
- **Focus:** Evergreen border plus a 3px translucent green ring (`0 0 0 3px rgba(13, 92, 73, 0.14)`); no browser default outline.
- **Error / Disabled:** Error copy is 0.76rem danger red below the field; disabled fields use soft field ground and muted text with a not-allowed cursor. Labels are 0.82rem/600 soft ink, placed above the control.

### Navigation
- **Style:** A single 84px hairline-bottom header (72px on mobile) with the display-face wordmark left and text links right. Links are 0.88rem/600 soft ink; hover becomes evergreen with no underline.
- **Active / Mobile:** At 640px the admin link hides; at 420px the first nav link hides and the wordmark shrinks to 1.15rem. No hamburger menu exists.

### Signature Component: Ballot Card
The dark ink card with the amber mono stub label (“KERTAS SUARA” style), dashed tear line, two circular notches, and hard offset shadow. It appears in the landing hero to make the abstract election feel physical. Body copy inside is white at 72% opacity; links are amber. This is the only element allowed both the offset shadow and the notch geometry.

## Do's and Don'ts

### Do:
- **Do** use evergreen for the single primary action per view and let everything else recede.
- **Do** use a 1px hairline or a soft-field step to separate surfaces instead of a shadow.
- **Do** keep amber to stamps, live-status dots, stub labels, and the paused badge.
- **Do** keep controls at 44px minimum height with clear 2px evergreen focus outlines.
- **Do** use Bricolage only for display, headline, and title roles, with negative tracking.
- **Do** preserve the ballot card's notches, dashed tear line, and offset shadow together; they are one artifact.

### Don't:
- **Don't** introduce a second accent hue or a gradient as brand expression; the only gradient is the results progress bar.
- **Don't** put shadows on ordinary panels, cards, tables, or buttons.
- **Don't** use solid red fills for destructive actions; use the soft danger ground.
- **Don't** make pill shapes into buttons or navigation controls.
- **Don't** set Indonesian copy in uppercase or all-caps tracking; sentence case is the voice.
- **Don't** reduce the device-flow display type below its clamp minimum to fit more content.
