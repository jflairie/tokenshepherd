.PHONY: build run clean cli

# Build the Swift menu bar app
build:
	cd macos && swift build

# Build in release mode
release:
	cd macos && swift build -c release

# Run the menu bar app
run: build
	cd macos && swift run

# Build CLI (TypeScript)
cli:
	npm run build

# Build everything
all: cli build

# Clean Swift build artifacts
clean:
	cd macos && swift package clean
	rm -rf macos/.build
