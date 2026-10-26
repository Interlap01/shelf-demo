# Xcode CLI Reference

Complete command reference for `xcodebuild` and related tools.

## xcodebuild Commands

### Project Discovery

```bash
# List all schemes in workspace
xcodebuild -workspace /path/to/App.xcworkspace -list

# List all schemes in project
xcodebuild -project /path/to/App.xcodeproj -list

# Show available SDKs
xcodebuild -showsdks

# Show available destinations for a scheme
xcodebuild -workspace /path/to/App.xcworkspace -scheme SchemeName -showDestinations

# Show all build settings
xcodebuild -workspace /path/to/App.xcworkspace -scheme SchemeName -showBuildSettings

# Get specific build setting
xcodebuild -workspace /path/to/App.xcworkspace -scheme SchemeName \
  -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER
```

### Building for iOS Device

```bash
# Build for generic iOS device (no signing)
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "generic/platform=iOS" \
  -configuration Release \
  build

# Build for connected device
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS,id=DEVICE_UDID" \
  build

# Build with custom derived data path (recommended)
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS,id=DEVICE_UDID" \
  -derivedDataPath /tmp/build \
  build

# Clean build
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "generic/platform=iOS" \
  clean build
```

### Building for iOS Simulator

```bash
# Build targeting a simulator by name
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  build

# Build with specific iOS version
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0" \
  build

# Build with custom derived data path
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -derivedDataPath /tmp/build \
  -configuration Debug \
  build
```

### Building for macOS

```bash
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme MacScheme \
  -destination "platform=macOS" \
  build
```

### Archives and Distribution

```bash
# Create archive
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
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

### Testing

```bash
# Run all tests
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  test

# Run specific test class
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -only-testing "AppTests/UserServiceTests" \
  test

# Run specific test method
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -only-testing "AppTests/UserServiceTests/testLoginSuccess" \
  test

# Skip specific tests
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -skip-testing "AppTests/SlowTests" \
  test

# Test with code coverage
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -enableCodeCoverage YES \
  test

# Save test results
xcodebuild \
  -workspace /path/to/App.xcworkspace \
  -scheme SchemeName \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -resultBundlePath /tmp/TestResults.xcresult \
  test
```

### Useful Flags

| Flag | Description |
|------|-------------|
| `-workspace <path>` | Path to .xcworkspace |
| `-project <path>` | Path to .xcodeproj |
| `-scheme <name>` | Build scheme |
| `-destination <spec>` | Target device/simulator |
| `-configuration <name>` | Debug or Release |
| `-derivedDataPath <path>` | Where to put build products |
| `-quiet` | Suppress xcodebuild output |
| `-parallelizeTargets` | Build targets in parallel |
| `-jobs <n>` | Number of concurrent build jobs |

---

## Logging with /usr/bin/log

```bash
# Stream logs for specific app
/usr/bin/log stream \
  --predicate 'processImagePath CONTAINS[cd] "AppName"' \
  --level debug

# Stream with JSON output
/usr/bin/log stream \
  --predicate 'processImagePath CONTAINS[cd] "AppName"' \
  --style json

# Stream with timeout
/usr/bin/log stream \
  --predicate 'processImagePath CONTAINS[cd] "AppName"' \
  --timeout 60s

# Filter by message content
/usr/bin/log stream \
  --predicate 'eventMessage CONTAINS[cd] "error"' \
  --level debug

# Save to file (background)
/usr/bin/log stream \
  --predicate 'processImagePath CONTAINS[cd] "AppName"' \
  --style json > /tmp/logs.json &
LOG_PID=$!

# Stop logging
kill $LOG_PID
```

### Common Predicates

| Predicate | Description |
|-----------|-------------|
| `processImagePath CONTAINS[cd] "App"` | Filter by app name |
| `eventMessage CONTAINS[cd] "error"` | Filter by message |
| `category == "network"` | Filter by category |
| `subsystem == "com.apple.xxx"` | Filter by subsystem |
| `messageType == error` | Only errors |

---

## Finding Built App Path

```bash
# If using -derivedDataPath
find /tmp/build -name "*.app" -type d | head -1

# Default derived data location
find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*Debug-iphoneos*" | head -1

# Get from build settings
xcodebuild -workspace App.xcworkspace -scheme App -showBuildSettings | grep "BUILT_PRODUCTS_DIR"
```

---

## Complete Build Workflow

```bash
#!/bin/bash
set -e

# Configuration
WORKSPACE="/path/to/App.xcworkspace"
SCHEME="App"
DERIVED_DATA="/tmp/build"

# 1. Build for device
echo "Building..."
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  -configuration Debug \
  build

# 2. Find the built app
APP_PATH=$(find "$DERIVED_DATA" -name "*.app" -type d | head -1)
echo "Found app: $APP_PATH"

# 3. Use MobAI HTTP API to install and test on device
# See MobAI docs for localhost:8686 API reference
```
