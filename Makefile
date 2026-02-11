.PHONY: build run clean install uninstall

APP_NAME = TokenShepherd
APP_BUNDLE = macos/.build/$(APP_NAME).app
BINARY = macos/.build/arm64-apple-macosx/debug/$(APP_NAME)
BINARY_RELEASE = macos/.build/arm64-apple-macosx/release/$(APP_NAME)
INSTALL_PATH = /Applications/$(APP_NAME).app
LAUNCHAGENT = com.tokenshepherd.app
LAUNCHAGENT_PLIST = $(HOME)/Library/LaunchAgents/$(LAUNCHAGENT).plist

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
	codesign --force --deep --sign - "$(APP_BUNDLE)"

# Install to /Applications + auto-launch on login
install: dist
	@launchctl unload "$(LAUNCHAGENT_PLIST)" 2>/dev/null || true
	@pkill -f $(APP_NAME) 2>/dev/null || true
	@sleep 1
	@rm -rf "$(INSTALL_PATH)"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_PATH)"
	@mkdir -p "$(HOME)/Library/LaunchAgents"
	@cp macos/Resources/$(LAUNCHAGENT).plist "$(LAUNCHAGENT_PLIST)"
	@launchctl load "$(LAUNCHAGENT_PLIST)"
	@echo "Installed. Starts automatically on login."

# Remove from /Applications + remove auto-launch
uninstall:
	@pkill -f $(APP_NAME) 2>/dev/null || true
	@launchctl unload "$(LAUNCHAGENT_PLIST)" 2>/dev/null || true
	@rm -f "$(LAUNCHAGENT_PLIST)"
	@rm -rf "$(INSTALL_PATH)"
	@echo "Uninstalled."

# Create distributable .app bundle (release build)
dist: release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp "$(BINARY_RELEASE)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp macos/Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	codesign --force --deep --sign - "$(APP_BUNDLE)"
	cd macos/.build && zip -r $(APP_NAME).zip $(APP_NAME).app
	@echo "Built: macos/.build/$(APP_NAME).zip"

# Clean build artifacts
clean:
	cd macos && swift package clean
	rm -rf macos/.build
