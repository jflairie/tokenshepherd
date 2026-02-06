# TokenShepherd

A floating desktop widget for Mac that provides ambient Claude Code usage awareness and efficiency coaching.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Swift 5.9+

## Building

### Via Xcode

1. Open `TokenShepherd.xcodeproj` in Xcode
2. Select the TokenShepherd scheme
3. Build and run (⌘R)

### Via Command Line

```bash
xcodebuild -project TokenShepherd.xcodeproj -scheme TokenShepherd -configuration Release build
```

The built app will be in `build/Release/TokenShepherd.app`.

## Features

### Floating Widget
- **Compact mode**: Small pill showing usage % and status color
- **Expanded mode**: Click to show details (tokens, time to reset, trends)
- Always-on-top, draggable to any screen position
- Remembers position across launches
- Semi-transparent design

### Metrics Displayed
- Current quota usage (5hr window, 7-day window)
- Tokens used today (input/output breakdown)
- Visual status: green (<70%), yellow (70-89%), red (90%+)
- Time until quota reset
- Estimated cost

## Data Sources

| Source | Location | Purpose |
|--------|----------|---------|
| stats-cache.json | ~/.claude/ | Daily aggregates, cache hit ratio |
| history.jsonl | ~/.claude/ | Per-message tokens, patterns |
| Quota API | api.anthropic.com | Real-time limit status |

## Configuration

The app reads credentials from:
1. Environment variable `ANTHROPIC_API_KEY`
2. macOS Keychain (Claude Code OAuth token)

No manual configuration required if you're already using Claude Code.

## Architecture

```
TokenShepherd/
├── App/
│   ├── TokenShepherdApp.swift      # App entry point
│   └── AppDelegate.swift           # Window management
├── Views/
│   ├── FloatingWidget.swift        # Main widget view
│   ├── CompactView.swift           # Pill/minimal view
│   └── ExpandedView.swift          # Detail view
├── Models/
│   ├── UsageData.swift             # Data models
│   └── QuotaResponse.swift         # API response models
└── Services/
    ├── DataService.swift           # Coordinates data sources
    ├── FileWatcher.swift           # FSEvents wrapper
    ├── QuotaAPI.swift              # Anthropic API client
    └── KeychainService.swift       # Credential access
```

## License

MIT
