# Shelly Codes

An iOS app built with the easy-ios defaults. Follow these conventions rather
than introducing new libraries or patterns.

- **UI:** SwiftUI only. Minimum iOS 17; don't use newer APIs without `if #available`.
- **State:** MV with `@Observable` models. Views read models directly; no view models
  unless a screen has logic worth unit testing on its own.
- **Storage:** SwiftData (`@Model`, `@Query`). Store enums as raw values so `#Predicate` works.
- **Networking:** `URLSession` with async/await. No third-party networking libraries.
- **Concurrency:** Swift 6, app target defaults to `@MainActor` isolation. Mark pure value
  types (structs/enums with logic but no UI) `nonisolated` so `@Model` classes and tests can use them.
- **Dependencies:** Swift Package Manager only, and only when Apple's frameworks can't do it.
- **Tests:** Swift Testing in `ShellyCodesTests` for logic; XCUITest in `ShellyCodesUITests` for one
  happy-path flow per main feature. UI tests launch with `-ui-testing`, which uses an
  in-memory store.
- **Text:** user-facing strings go through String Catalogs (`Localizable.xcstrings`).
- **Icons:** SF Symbols.

Files added to `ShellyCodes/`, `ShellyCodesTests/`, or `ShellyCodesUITests/` are picked up by Xcode
automatically; there's no need to edit the project file.

Run the tests: `make test APP=<path to this folder>` from the easy-ios repo root.
