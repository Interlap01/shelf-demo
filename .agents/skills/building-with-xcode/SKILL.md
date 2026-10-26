---
name: building-with-xcode
description: Use when building, archiving, or signing iOS/macOS apps with xcodebuild. Covers project discovery, build configurations, code signing, and archive workflows. Triggers on "xcodebuild", "build iOS app", "archive", "code signing", "provisioning profile", "export IPA", "xcode build settings".
---

# Xcode Build

Build, archive, and sign iOS/macOS projects using native Xcode CLI tools.

## When to Use This Skill

Use this skill when:
- Building iOS or macOS apps with Xcode
- Creating archives for distribution
- Configuring code signing and provisioning profiles
- Running tests via xcodebuild
- Investigating build settings and configurations

## Quick Start

### 1. Discover Project Structure
```bash
# List schemes in a workspace
xcodebuild -workspace /path/to/App.xcworkspace -list

# List schemes in a project
xcodebuild -project /path/to/App.xcodeproj -list

# Show build settings
xcodebuild -workspace /path/to/App.xcworkspace -scheme AppScheme -showBuildSettings
```

### 2. Build for Device
```bash
# Build for a connected iOS device
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme AppScheme \
  -destination "platform=iOS,id=DEVICE_UDID" \
  -configuration Debug \
  -derivedDataPath /tmp/build \
  build

# Build for generic iOS device (no specific device required)
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme AppScheme \
  -destination "generic/platform=iOS" \
  -configuration Release \
  build
```

### 3. Build for macOS
```bash
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme MacScheme \
  -destination "platform=macOS" \
  build
```

### 4. Archive and Export
```bash
# Create archive
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme AppScheme \
  -destination "generic/platform=iOS" \
  -archivePath /tmp/App.xcarchive \
  archive

# Export IPA from archive
xcodebuild \
  -exportArchive \
  -archivePath /tmp/App.xcarchive \
  -exportPath /tmp/export \
  -exportOptionsPlist /path/to/ExportOptions.plist
```

### 5. Run Tests
```bash
# Run all tests
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme AppScheme \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  test

# Run specific test class
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme AppScheme \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -only-testing "AppTests/MyTestClass" \
  test
```

## Device Testing

For on-device testing (install, launch, screenshot, tap, swipe), use MobAI's HTTP API at localhost:8686. Do NOT use xcrun simctl or xcrun devicectl. MobAI handles device communication via ADB (Android) and go-ios (iOS).

## Detailed References

For comprehensive command documentation, see:
- **CLI_REFERENCE.md** - Full `xcodebuild` command reference with project discovery, building, archives, testing, and useful flags

## Common Patterns

### Build + Find App
```bash
# 1. Build
xcodebuild -workspace App.xcworkspace -scheme App \
  -destination "generic/platform=iOS" \
  -derivedDataPath /tmp/build build

# 2. Find the built .app
APP=$(find /tmp/build -name "*.app" -type d | head -1)
echo "Built app: $APP"
```

### Log Capture
```bash
# Stream app logs (run in background)
/usr/bin/log stream \
  --predicate 'processImagePath CONTAINS[cd] "AppName"' \
  --style json &
LOG_PID=$!

# ... interact with app ...

# Stop logging
kill $LOG_PID
```

## Session Configuration

Use environment variables for repeated commands:

```bash
export XCODE_WORKSPACE="/path/to/App.xcworkspace"
export XCODE_SCHEME="App"
export APP_BUNDLE_ID="com.your.app"

# Use in commands
xcodebuild -workspace "$XCODE_WORKSPACE" -scheme "$XCODE_SCHEME" ...
```

## Troubleshooting

### Build fails with "no matching destination"
```bash
# Check available destinations
xcodebuild -workspace App.xcworkspace -scheme App -showDestinations
```

### Can't find built .app
```bash
# Check derived data path you specified
ls -la /tmp/build/Build/Products/Debug-iphoneos/

# Or use default derived data
ls ~/Library/Developer/Xcode/DerivedData/
```

### Code signing issues
```bash
# Show signing settings
xcodebuild -workspace App.xcworkspace -scheme App -showBuildSettings | grep -E "CODE_SIGN|PROVISIONING|DEVELOPMENT_TEAM"

# List available signing identities
security find-identity -v -p codesigning

# List provisioning profiles
ls ~/Library/MobileDevice/Provisioning\ Profiles/
```
