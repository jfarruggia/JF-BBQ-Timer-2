# Spec: "Get a Probe" link

Status: **approved by Jim** (2026-09-26)

## Goal

Give users an easy way to buy a Combustion probe from inside the app.

## Key decision: link to Jim's website, not a store

The app opens **one fixed URL on Jim's own domain**. That page redirects
(forwards) to wherever the probe is sold today.

- Today: redirect to the Combustion Inc. store.
- Later: when the probe is back on Amazon, change the redirect to the Amazon
  affiliate link. **No app update needed.**
- Combustion has not answered Jim about an affiliate program. If they ever do,
  swap the redirect the same way.

URL: `https://farruggiacreations.com/probe` (approved)

**The redirect must be live before this build ships.** Otherwise the button
opens a dead page.

## Where it shows

### 1. Connect Probe screen (`ProbePickerView.swift`)

A new section at the **bottom** of the list. Shown only when no probe is
connected (hide it in `.connected` and `.reconnecting`).

- Footer-style text: "Don't have a probe?"
- Row: **"Get a Combustion Probe"** with an `arrow.up.right` icon, accent color.
- Tap opens the URL in Safari (SwiftUI `Link`, not an in-app web view).

### 2. Paywall (`CustomPaywallView.swift`)

Free users tap the "Probe" chip and see the paywall, **not** the Connect Probe
screen. So the link must be here too. Directly under the probe `FeatureRow`
("Connect your Combustion probe …"), add a small line:
**"Don't have a probe? Get one →"** — caption size, accent color, opens the URL
in Safari. It must not look like or compete with the purchase button.

### 3. Settings ▸ Temperature Probe section (`SettingsViews.swift`)

Last row of the existing "Temperature Probe" section: **"Get a Combustion
Probe"** with an `arrow.up.right` icon, opens the URL in Safari. That section
only shows for premium users today — keep it that way (free users get the
paywall link instead).

## Rules

- URL lives in **one constant** (e.g. `ProbeStoreLink.url`), not typed twice.
- No new dependencies. No `project.pbxproj` edits.
- iPhone only. Nothing on the watch.
- Apple allows links to buy physical goods outside the app (no IAP needed).

## Decisions (2026-09-26)

1. URL `https://farruggiacreations.com/probe` — approved.
2. Link on the paywall — yes.
3. Link in Settings ▸ Temperature Probe — yes (Jim added).
