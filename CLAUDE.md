# Shelly Codes

An iPad-only app (kids 8–12) that teaches Python with a turtle. Built with the
easy-ios defaults; follow these conventions rather than introducing new libraries
or patterns.

- **UI:** SwiftUI only. Minimum iOS 17; don't use newer APIs without `if #available`.
  Large, rounded type; every control a child uses is at least 50pt tall.
- **State:** MV with `@Observable` models. Views read models directly.
- **Storage:** SwiftData (`LevelProgress`, `Creation`). Settings in `@AppStorage`.
- **No networking, no third-party code, no analytics, no external links.** It's a Kids
  Category app; anything that leaves the app needs a parental gate and an
  APP_STORE.md privacy update first.
- **Concurrency:** Swift 6, app target defaults to `@MainActor`. Pure logic types
  (`ShellyCodes/Python`, `ShellyCodes/Game`) are `nonisolated`.
- **Tests:** Swift Testing in `ShellyCodesTests`, XCUITest in `ShellyCodesUITests`.
  UI tests launch with `-ui-testing` (in-memory store, fresh settings, instant
  replays). XCUITest can't see focus in the code editor: tap it, wait, then use
  `app.typeText`.

## The interpreter (`ShellyCodes/Python`)

- Error messages are the product. Every `PyError` must say what to do, in words an
  8-year-old understands, on the right line. Add a case to `FriendlyErrorTests` for
  any new message.
- Behave like real Python 3 for everything supported. If something can't be
  supported, fail with a clear message rather than doing something different.
- Keep the limits (`Interpreter.maxSteps`, `maxEvents`, `maxDepth`, `maxOutput`,
  `Parser.maxDepth`). Runs happen on a 32 MB-stack thread; don't call the parser or
  interpreter internals any other way.

## Levels (`ShellyCodes/Game/Curriculum.swift`)

- Level ids are saved with progress: add levels, never renumber shipped ones.
- A level's goal comes from running its `solution`. `LevelTests` checks that every
  solution solves its level, every starter doesn't (except 1.1), and everything fits
  on the canvas (±200).

## Commands

`make test`, `make unit`, `make format`, `make lint`, `make screenshots`, `make icon`,
`make listing`. Debug builds support `-ui-testing -screenshot <home|level|success|error|freedraw|gallery|shells>`.

Files added to `ShellyCodes/`, `ShellyCodesTests/` or `ShellyCodesUITests/` are picked
up by Xcode automatically.
