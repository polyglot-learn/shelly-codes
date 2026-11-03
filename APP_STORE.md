# App Store submission kit

Everything needed to publish Shelly Codes. Field limits are checked by
`scripts/check_listing.py`, which `make listing` runs.

## Listing

**Name** (30 max)

```
Shelly Codes
```

**Subtitle** (30 max)

```
Learn Python with a turtle
```

**Promotional text** (170 max)

```
Kids write real Python and watch Shelly the turtle draw it! 27 playful puzzles, friendly help with mistakes, and a free-draw studio. No ads, no tracking.
```

**Keywords** (100 max, comma-separated, no spaces after commas)

```
coding,kids,python,programming,learn to code,turtle,STEM,code,school,logic,beginner,drawing
```

**Description** (4000 max)

```
Meet Shelly, a turtle who follows Python code!

Shelly Codes teaches children aged 8 to 12 to program in Python, the real language that grown-up programmers use every day. Kids type code, tap Run, and watch Shelly walk, turn and draw exactly what they wrote.

LEARN BY PLAYING
• 27 short puzzles in 6 chapters, each one a small "aha!"
• Start with forward(100) and left(90), then learn print, variables, for loops, colors, lists, if, while and functions
• Collect stars, unlock new shell colors for Shelly, and celebrate with confetti

REAL PYTHON, KID-SIZED
• Children write real Python 3 code, exactly as they will on a computer later
• Tap-to-insert code pieces help small hands on the iPad
• Shelly's drawings use the same commands as Python's turtle module

MISTAKES ARE PART OF LEARNING
• Instead of scary error codes, Shelly explains what went wrong in plain words: "Add a colon : at the end of this for line."
• The line with the mistake lights up
• Hints are there when you're stuck

FREE DRAW STUDIO
• Make spirals, starry skies, flowers and houses
• Start from an idea or a blank page, and keep your drawings

MADE FOR FAMILIES AND CLASSROOMS
• No ads, no in-app purchases, no accounts
• No tracking and no data collection, ever
• Works completely offline
• Grown-ups area behind a parental gate: unlock all levels for a class, or reset progress

Designed for iPad.
```

**What's New** (version 1.0)

```
Hello from Shelly! Our first version: 27 Python puzzles, Free Draw, and six shells to unlock.
```

## App information

| Field | Value |
|---|---|
| Bundle ID | `org.polyglotlearn.shellycodes` (change in Xcode if you publish under your own) |
| SKU | `shellycodes` |
| Primary category | Education |
| Secondary category | Entertainment (optional) |
| Kids Category | Yes, age band **9–11** |
| Price | Free |
| Devices | iPad only, iPadOS 17 or later |
| Copyright | 2026 thejesh23 |
| Support URL | https://polyglot-learn.github.io/shelly-codes/ |
| Privacy policy URL | https://polyglot-learn.github.io/shelly-codes/privacy |
| Marketing URL | (optional) https://github.com/polyglot-learn/shelly-codes |

## App Privacy ("nutrition label")

Choose **Data Not Collected**. The app has no accounts, analytics, ads, network
access, or third-party code. `ShellyCodes/PrivacyInfo.xcprivacy` declares no
tracking and no collected data.

## Age rating questionnaire

Answer **None / No** to every content question (violence, mature themes, gambling,
contests, user-generated content shared with others, web access, messaging,
advertising). Expected result: the lowest rating (4+). In-app controls: the
Grown-ups area is behind a parental gate.

## Export compliance

The app declares `ITSAppUsesNonExemptEncryption = NO`, so App Store Connect won't ask.

## Notes for App Review

```
Shelly Codes is an educational app that teaches children to program in Python.

• No login is needed.
• The Grown-ups area (top right of the home screen) is behind a parental gate: answer the multiplication question shown.
• To see later levels quickly, open Grown-ups and turn on "Unlock all levels".
• The app runs only code the child types into it, using an interpreter built into the app (written in Swift). No code is downloaded; the app makes no network connections. All levels and content ship inside the app.
• No third-party SDKs, analytics or advertising.
```

## Screenshots

`screenshots/` has seven 2064×2752 PNGs for the 13-inch iPad display, which
App Store Connect scales down for smaller iPads. Regenerate with `make screenshots`.
Suggested order: 2-level, 4-error, 3-success, 5-freedraw, 1-home, 6-gallery, 7-shells.

## Release checklist

1. **Apple Developer Program** membership ($99/year) on the account that will publish.
2. In Xcode, select the ShellyCodes target → Signing & Capabilities → choose your **Team**.
   Change the bundle ID if `org.polyglotlearn.shellycodes` isn't yours.
3. **Host the privacy policy and support page:** on GitHub, Settings → Pages →
   Deploy from branch `main`, folder `/docs`. Check both URLs above load.
4. In **App Store Connect**: My Apps → + → New App → iOS, name "Shelly Codes",
   the bundle ID, SKU `shellycodes`.
5. Fill in the listing, App Privacy, age rating and Kids Category from this file;
   upload the screenshots.
6. `make test` must pass. Then in Xcode: Product → Archive → Distribute App →
   App Store Connect → Upload.
7. Optional: test the build with TestFlight on a real iPad.
8. Select the build on the version page, add the review notes, and **Submit for Review**.

For later versions, bump `MARKETING_VERSION` (e.g. 1.1) and always increase
`CURRENT_PROJECT_VERSION` (the build number) before archiving.
