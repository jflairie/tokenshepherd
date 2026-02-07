# TokenShepherd Menu Bar - Testing Guide

## Quick Start

### 1. Run the Menu Bar App

```bash
# Make sure Rust is in PATH
source "$HOME/.cargo/env"

# Run in development mode
npm run dev:menubar
```

The app will:
- Compile TypeScript (CLI + UI)
- Compile Rust backend
- Launch the app
- Show a tray icon in your menu bar

### 2. What to Look For

**Tray Icon:**
- Look for a TokenShepherd icon in your Mac menu bar (top-right area)
- Should appear after ~30-60 seconds on first run (Rust compilation)
- Subsequent runs are faster (~5 seconds)

### 3. Test Scenarios

#### Test 1: Basic Window Show/Hide
1. **Click the tray icon** → Window should appear
2. **Click inside the window** → Window stays open
3. **Click outside the window** → Window hides after ~100ms
4. **Click tray again** → Window shows again

**Expected:** Window feels instant, no sluggish delay

#### Test 2: ESC Key
1. Click tray icon to show window
2. **Press ESC key** → Window hides immediately

**Expected:** Instant hide, no delay

#### Test 3: Quota Display
1. Click tray icon
2. Look at the window content

**Expected:**
- See "TokenShepherd" header with status dot
- See "5-Hour Window" with percentage and progress bar
- See "7-Day Window" with percentage and progress bar
- See "7-Day Sonnet" if you have Sonnet quota
- See "Resets in Xh Ym" below each window
- See "Refresh" button at bottom

#### Test 4: Data Accuracy
1. In terminal, run: `node dist/index.js status`
2. Compare output with menu bar window

**Expected:** Numbers should match

#### Test 5: Refresh Button
1. Click "Refresh" button in window
2. Window should stay open
3. Data should update (check reset times)

**Expected:** No errors, smooth update

#### Test 6: Dark Mode
1. Go to System Preferences → General → Appearance
2. Switch between Light and Dark mode
3. Check menu bar window styling

**Expected:** Window background and text colors adapt automatically

#### Test 7: Right-Click Menu
1. Right-click (or Control+click) the tray icon
2. Should see a menu with "Quit" option
3. Click "Quit" → App should close

**Expected:** Clean exit

---

## Common Issues & Solutions

### Issue: "cargo not found"
```bash
# Install Rust if not installed
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Then source cargo
source "$HOME/.cargo/env"

# Try again
npm run dev:menubar
```

### Issue: "No credentials available"
**Cause:** Claude Code not logged in

**Solution:**
```bash
# Run Claude Code to trigger login
claude --version

# If not logged in, follow auth prompts
# Then try menu bar app again
```

### Issue: Window shows but is blank
**Possible causes:**
1. UI TypeScript not compiled
2. Path issue with dist/lib.js

**Solution:**
```bash
# Rebuild everything
npm run build:cli
npm run build:ui

# Try again
npm run dev:menubar
```

### Issue: App crashes on startup
**Check logs:**
```bash
# Look for error messages in terminal output
# Common issues:
# - Node not in PATH
# - dist/lib.js doesn't exist
# - Tauri config error
```

---

## Debug Mode

The app logs to console in development mode:

```bash
# Run and watch logs
npm run dev:menubar 2>&1 | grep -E '(Error|Failed|TRAY)'
```

Look for:
- `[TRAY]` messages (if you added debug logs)
- `Error` or `Failed` messages
- Rust compilation errors

---

## Performance Check

### Memory Usage
```bash
# While app is running
ps aux | grep TokenShepherd

# Should see ~20-30MB memory usage when idle
```

### CPU Usage
```bash
# Check Activity Monitor
# TokenShepherd should be 0-1% CPU when idle
# Brief spike when refreshing data is normal
```

---

## What's Working vs. To-Do

### ✅ Working (Should work now)
- Tray icon appears
- Click tray → window shows
- Window management (100ms timeout)
- ESC key hide
- IPC communication (fetch_quota)
- Real quota data display
- Dark mode styling

### ⏳ To-Do (Phase 3)
- Real-time countdown updates (static for now)
- Window positioning near tray icon (center screen currently)
- Loading spinner during fetch
- Error state UI (errors show in console only)
- Detailed alert messages

---

## Expected First Run

```
1. npm run dev:menubar
2. See: "> tokenshepherd@0.1.0 build:cli"
3. See: "> tokenshepherd@0.1.0 build:ui"
4. See: "Compiling app v0.1.0" (Rust compilation - SLOW first time)
5. See: Progress bars for Rust deps (30-60 seconds)
6. See: "Finished `dev` profile"
7. See: "Running `target/debug/app`"
8. App launches, tray icon appears
```

**If you see this, it's working!**

Subsequent runs skip Rust compilation if code unchanged (~5 second startup).

---

## Stop the App

### From Terminal:
- Press `Ctrl+C` in the terminal where it's running

### From Menu Bar:
- Right-click tray icon → "Quit"

---

## Next Steps After Testing

If basic functionality works:
1. Report any bugs/issues you find
2. Proceed to Phase 3 (UI polish)
3. Test on real usage (multiple tray clicks, extended session)

If something doesn't work:
1. Check console output for errors
2. Verify CLI still works: `node dist/index.js status`
3. Try rebuilding: `npm run build:cli && npm run build:ui`
4. Check this guide's "Common Issues" section
