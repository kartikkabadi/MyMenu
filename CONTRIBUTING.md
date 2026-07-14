# Contributing to MyMonitor

Thanks for helping improve MyMonitor. Small, focused pull requests are easiest to review.

## Before you start

1. Search existing issues and pull requests.
2. For a bug, include the macOS version, Mac architecture, display connection, display mode, MyMonitor tier, and the exact reproduction steps. Do not include screenshots or logs containing private window titles unless you have redacted them.
3. For a feature, explain the user problem and the smallest useful behavior.

## Local workflow

```bash
./scripts/generate_xcodeproj.sh
xcodebuild -project MyMonitor.xcodeproj \
  -scheme MyMonitor \
  -configuration Debug \
  -sdk macosx \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

Run the manual matrix in [docs/DESK_TEST_RESULTS.md](docs/DESK_TEST_RESULTS.md) when a change touches display, window, permission, or hot-key behavior.

## Pull requests

- Keep changes scoped and explain behavior changes in the PR description.
- Do not commit `build/`, `dist/`, `.DS_Store`, user-specific paths, private logs, credentials, or generated runtime data.
- Do not add telemetry, network calls, or third-party dependencies without discussing the privacy and maintenance impact.
- Update the README or docs when user-facing behavior, permissions, shortcuts, or requirements change.

## Code style

Prefer clear Swift with small ownership boundaries. Keep display APIs and Accessibility/Carbon quirks at their edges, avoid force casts for values received from the OS, and make teardown paths explicit.
