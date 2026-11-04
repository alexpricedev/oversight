# Oversight

macOS SwiftUI app; see `README.md` for the full picture.

- **Project file:** `Oversight.xcodeproj` is generated from `project.yml`. Never edit
  the `.pbxproj`; run `xcodegen generate` after adding, removing or renaming a file.
- **Build and test:** the `xcodebuild … build` / `… test` commands in `README.md`.
  There is no CI, so run the tests locally before merging a PR.
- **Install / release:** when asked to install, release, or "update the app",
  run `Scripts/install.sh` from an up-to-date `main` checkout. It builds Release,
  quits the running app, replaces `/Applications/Oversight.app` and relaunches it.
  Details in the README's "Install into /Applications" section.
