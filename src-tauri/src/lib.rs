use std::process::Command;
use serde_json::Value;
use tauri::{
    Manager, WindowEvent,
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
};
use tauri_plugin_positioner::{Position, WindowExt};

#[tauri::command]
async fn fetch_quota(app: tauri::AppHandle) -> Result<Value, String> {
    let lib_path_str = if cfg!(debug_assertions) {
        "dist/lib.js".to_string()
    } else {
        let resource_dir = app.path().resource_dir()
            .map_err(|e| format!("Failed to get resource dir: {}", e))?;
        resource_dir.join("dist").join("lib.js").to_string_lossy().to_string()
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
    tauri::Builder::default()
        .plugin(tauri_plugin_positioner::init())
        .setup(|app| {
            // Menu bar app: no dock icon
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }

            TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .icon_as_template(true)
                .on_tray_icon_event(|tray, event| {
                    // Forward tray events to positioner so it knows icon location
                    tauri_plugin_positioner::on_tray_event(tray.app_handle(), &event);

                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            if window.is_visible().unwrap_or(false) {
                                let _ = window.hide();
                            } else {
                                let _ = window.as_ref().window().move_window(Position::TrayBottomCenter);
                                let _ = window.show();
                                let _ = window.set_focus();
                            }
                        }
                    }
                })
                .build(app)?;

            Ok(())
        })
        // Hide window when it loses focus (click outside)
        .on_window_event(|window, event| {
            if let WindowEvent::Focused(false) = event {
                let _ = window.hide();
            }
        })
        .invoke_handler(tauri::generate_handler![fetch_quota])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
