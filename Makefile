.PHONY: build run run-app clean cli

APP_NAME = TokenShepherd
APP_BUNDLE = macos/.build/$(APP_NAME).app
BINARY = macos/.build/arm64-apple-macosx/debug/$(APP_NAME)
BINARY_RELEASE = macos/.build/arm64-apple-macosx/release/$(APP_NAME)
ENTITLEMENTS = macos/Resources/TokenShepherd.entitlements

# Build the Swift menu bar app
build:
	cd macos && swift build

# Build in release mode
release:
	cd macos && swift build -c release

# Run the menu bar app as .app bundle (notifications enabled)
run: build bundle
	open -W "$(APP_BUNDLE)"

# Create .app bundle from built binary
bundle:
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp "$(BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp macos/Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	codesign --force --deep --sign - --entitlements "$(ENTITLEMENTS)" --options runtime "$(APP_BUNDLE)"

# Create distributable .app bundle (release build)
dist: release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp "$(BINARY_RELEASE)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp macos/Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	codesign --force --deep --sign - --entitlements "$(ENTITLEMENTS)" --options runtime "$(APP_BUNDLE)"
	cd macos/.build && zip -r $(APP_NAME).zip $(APP_NAME).app
	@echo "Built: macos/.build/$(APP_NAME).zip"

# Build CLI (TypeScript)
cli:
	npm run build

# Build everything
all: cli build

# Clean Swift build artifacts
clean:
	cd macos && swift package clean
	rm -rf macos/.build
