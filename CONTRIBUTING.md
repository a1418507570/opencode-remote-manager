# Contributing

Thanks for your interest in improving OpenCode Remote Manager.

## Development workflow

1. Fork the repository and create a focused branch.
2. Keep changes small and easy to review.
3. Run the local verification steps before opening a pull request.
4. Include enough context in the PR description to explain the why, not just the what.

## Local verification

```bash
swift build
DYLD_FRAMEWORK_PATH="/Library/Developer/CommandLineTools/Library/Developer/Frameworks" \
DYLD_LIBRARY_PATH="/Library/Developer/CommandLineTools/Library/Developer/usr/lib" \
swift test -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
./Scripts/package-release.sh
```

## What to contribute

- bug fixes around tunnel supervision, Desktop integration, and remote bootstrap
- improvements to packaging and onboarding
- additional tests for recovery behavior and compatibility edges
- documentation improvements

## Pull request checklist

- [ ] build passes
- [ ] tests pass
- [ ] docs are updated if behavior changed
- [ ] changes are scoped to one logical concern
