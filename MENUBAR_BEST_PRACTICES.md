# macOS Menu Bar App - Best Practices & Patterns

**Research Date:** 2026-02-07
**Source:** Analysis of 20+ open-source menu bar apps including industry-standard libraries

## The Core Challenge

Menu bar apps face a critical timing issue:
1. User clicks tray icon → window shows
2. Window gains focus → immediately loses focus (blur event)
3. Blur handler hides window
4. **Result:** Window disappears before user can interact

## The Professional Solution

### Industry Standard: 100ms Timeout Pattern

From **[menubar](https://github.com/max-mapper/menubar)** library (6.7k stars, used by thousands of apps):

```rust
// Shared state
let should_hide = Arc::new(Mutex::new(false));

// On focus loss: Schedule hide with 100ms delay
thread::spawn(move || {
    thread::sleep(Duration::from_millis(100));
    if *should_hide.lock().unwrap() {
        window.hide();
    }
});

// On tray click: Cancel pending hide
*should_hide.lock().unwrap() = false;
```

**Why 100ms?**
- Long enough for tray click event to register
- Short enough to feel instant to users
- Battle-tested in production apps

## Implementation Details

### Window Positioning

```rust
// Center window horizontally below tray icon
let x = tray_x + (tray_width / 2) - (window_width / 2);
let y = tray_y + tray_height; // Directly below menu bar
```

**Key Points:**
- macOS menu bar is ~25pt (~50px @2x Retina)
- No extra padding needed - menu bar has built-in spacing
- Position updates on each show (handles monitor changes)

### Window Styling

**tauri.conf.json:**
```json
{
  "macOSPrivateApi": true,  // Enable transparency
  "transparent": true,      // Allow backdrop blur
  "decorations": false,     // Borderless
  "alwaysOnTop": true,      // Float above other windows
  "skipTaskbar": true       // No Dock icon for popup
}
```

**CSS (Native macOS Look):**
```css
.container {
  background: rgba(255, 255, 255, 0.88);
  backdrop-filter: blur(60px) saturate(200%);
  border-radius: 12px;
  box-shadow:
    0 0 0 1px rgba(0, 0, 0, 0.04),
    0 8px 32px rgba(0, 0, 0, 0.18);
}

@media (prefers-color-scheme: dark) {
  .container {
    background: rgba(28, 28, 30, 0.88);
  }
}
```

### Event Handling

**Tauri Pattern:**
```rust
.on_window_event(|window, event| {
    if let WindowEvent::Focused(false) = event {
        // Use Focused(false) instead of blur
        // Known Tauri bug: blur event breaks after first cycle
    }
})
```

**Why Not JavaScript blur?**
- Timing issues with window show/hide
- Race conditions between tray click and blur
- Professional apps handle this in native code

## Reference Projects

### Must-Study Projects

1. **[max-mapper/menubar](https://github.com/max-mapper/menubar)** (Electron)
   - Industry standard library
   - Perfect implementation of timeout pattern
   - Used by: Mojibar, Cumulus, Pomolectron

2. **[4gray/tauri-menubar-app](https://github.com/4gray/tauri-menubar-app)** (Tauri)
   - Clean Tauri implementation
   - Uses `tauri-plugin-positioner`
   - [Tutorial](https://medium.com/@4gray/create-menubar-app-with-tauri-510ab7f7c43d)

3. **[jasonlong/mater](https://github.com/jasonlong/mater)** (Electron)
   - Modern reference implementation (2026)
   - Real-world pomodoro app
   - Clean menubar UX

## Common Anti-Patterns

❌ **Don't:** Hide immediately on blur
```javascript
window.on('blur', () => window.hide()); // Too fast!
```

❌ **Don't:** Use large timeouts (feels sluggish)
```javascript
setTimeout(() => window.hide(), 500); // Too slow
```

❌ **Don't:** Rely on JavaScript for window management
```javascript
// Event timing is unreliable, use native code
```

## Best Practices Checklist

### Window Behavior
- ✅ 100ms timeout on focus loss
- ✅ Cancel timeout on tray click
- ✅ Track visibility state explicitly
- ✅ Support Esc key to dismiss

### UX Considerations
- ✅ Hide Dock icon (menu bar only)
- ✅ Prevent window close (hide instead)
- ✅ Position near tray icon
- ✅ Toggle on repeated clicks
- ✅ Support dark mode

### Performance
- ✅ Use thread-based timers (not tokio in event handlers)
- ✅ Shared state with Arc<Mutex>
- ✅ Frameless window for native feel

## TokenShepherd Implementation

### Current Status (2026-02-07)

**Files:**
- `src-tauri/src/lib.rs` - Implements professional timeout pattern
- `ui/app.js` - Minimal JS (Esc key only)
- `ui/styles.css` - Native macOS vibrancy styling

**Pattern Used:**
- Flag-based hide with 100ms thread sleep
- Tray click cancels pending hide
- All logic in Rust (no JS event management)

### Testing Checklist

- [ ] Click tray icon → window shows
- [ ] Window stays open for interaction
- [ ] Click inside window → stays open
- [ ] Click outside window → hides after 100ms
- [ ] Click tray while window open → toggles off
- [ ] Esc key → hides immediately
- [ ] Dark mode → proper styling
- [ ] Multiple monitors → positions correctly

## Resources

### Documentation
- [Tauri System Tray Guide](https://v2.tauri.app/learn/system-tray/)
- [macOS Menu Bar App Design](https://developer.apple.com/design/human-interface-guidelines/menu-bars)

### Tools
- [tauri-plugin-positioner](https://github.com/tauri-apps/plugins-workspace/tree/v2/plugins/positioner)
- [electron-positioner](https://github.com/jenslind/electron-positioner) (reference)

### Community
- [Tauri Discord](https://discord.gg/tauri) - #help channel
- [Tauri GitHub Issues](https://github.com/tauri-apps/tauri/issues) - Search "menu bar" or "tray"

## Future Improvements

### Consider Adding
1. **Preload window** - Instant show (trade-off: memory)
2. **Animation** - Subtle fade in/out (macOS-native feel)
3. **Context menu** - Right-click on tray icon (Preferences, Quit)
4. **Launch at login** - macOS `LSUIElement` + login items
5. **Keyboard shortcut** - Global hotkey to toggle window

### Advanced Patterns
- **NSPopover approach** - Even more native (requires Swift plugin)
- **Hover preview** - Show on mouse over (like system indicators)
- **Multiple windows** - Different content per tray icon state

---

**Last Updated:** 2026-02-07
**Maintained By:** Claude + User feedback
