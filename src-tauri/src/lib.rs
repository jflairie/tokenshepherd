use std::process::Command;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use serde_json::Value;
use tauri::{Manager, menu::{Menu, MenuItem}, tray::{TrayIconBuilder, TrayIconEvent}};
use tauri::image::Image;

#[tauri::command]
async fn fetch_quota(app: tauri::AppHandle) -> Result<Value, String> {
    // Get the app's resource directory (where dist/ is bundled)
    let resource_dir = app.path().resource_dir()
        .map_err(|e| format!("Failed to get resource dir: {}", e))?;

    let lib_path = resource_dir.join("dist").join("lib.js");

    // In development, use the project directory
    let lib_path_str = if cfg!(debug_assertions) {
        // In dev mode, use relative path from project root
        "dist/lib.js".to_string()
    } else {
        lib_path.to_string_lossy().to_string()
    };

    let output = Command::new("node")
        .arg(&lib_path_str)
        .arg("--quota")
        .output()
        .map_err(|e| format!("Failed to execute node: {}", e))?;

    if !output.status.success() {
        let error = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Node process failed: {}", error));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    serde_json::from_str(&stdout)
        .map_err(|e| format!("Failed to parse JSON: {}", e))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Shared state for 100ms timeout pattern
    let should_hide = Arc::new(Mutex::new(false));
    let should_hide_for_window = should_hide.clone();
    let should_hide_for_tray = should_hide.clone();

    tauri::Builder::default()
        .setup(move |app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }

            let window = app.get_webview_window("main").unwrap();

            // 100ms timeout pattern on focus loss
            let should_hide_clone = should_hide_for_window.clone();
            let window_for_timeout = window.clone();
            window.on_window_event(move |_window, event| {
                match event {
                    tauri::WindowEvent::Focused(false) => {
                        // Lost focus - start 100ms timer
                        *should_hide_clone.lock().unwrap() = true;

                        let should_hide = should_hide_clone.clone();
                        let window_clone = window_for_timeout.clone();

                        thread::spawn(move || {
                            thread::sleep(Duration::from_millis(100));
                            if *should_hide.lock().unwrap() {
                                let _ = window_clone.hide();
                            }
                        });
                    }
                    tauri::WindowEvent::Focused(true) => {
                        // Gained focus - cancel hide
                        *should_hide_clone.lock().unwrap() = false;
                    }
                    _ => {}
                }
            });

            // Create tray icon
            let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&quit])?;

            let _tray = TrayIconBuilder::new()
                .tooltip("TokenShepherd")
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .on_menu_event(|app, event| {
                    if event.id() == "quit" {
                        app.exit(0);
                    }
                })
                .on_tray_icon_event(move |tray, event| {
                    if let TrayIconEvent::Click { .. } = event {
                        // Cancel any pending hide
                        *should_hide_for_tray.lock().unwrap() = false;

                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![fetch_quota])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
