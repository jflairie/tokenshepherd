import { invoke } from "@tauri-apps/api/core";
async function refreshQuota() {
    try {
        const quota = (await invoke("fetch_quota"));
        updateUI(quota);
    }
    catch (error) {
        console.error("Failed to fetch quota:", error);
        showError(error instanceof Error ? error.message : String(error));
    }
}
function updateUI(quota) {
    // Update 5-hour window
    const fiveHourPct = Math.round(quota.five_hour.utilization * 100);
    updateQuotaDisplay("five-hour", fiveHourPct, quota.five_hour.resets_at);
    // Update 7-day window
    const sevenDayPct = Math.round(quota.seven_day.utilization * 100);
    updateQuotaDisplay("seven-day", sevenDayPct, quota.seven_day.resets_at);
    // Update 7-day sonnet (if available)
    if (quota.seven_day_sonnet) {
        const sonnetPct = Math.round(quota.seven_day_sonnet.utilization * 100);
        updateQuotaDisplay("sonnet", sonnetPct, quota.seven_day_sonnet.resets_at);
        document.getElementById("sonnet-section").style.display = "flex";
    }
    else {
        document.getElementById("sonnet-section").style.display = "none";
    }
    // Update status indicator (use max utilization)
    const maxPct = Math.max(fiveHourPct, sevenDayPct, quota.seven_day_sonnet
        ? Math.round(quota.seven_day_sonnet.utilization * 100)
        : 0);
    updateStatusIndicator(maxPct);
    // Hide error if showing
    document.getElementById("alert").style.display = "none";
}
function updateQuotaDisplay(prefix, percentage, resetsAt) {
    // Update percentage
    document.getElementById(`${prefix}-pct`).textContent = `${percentage}%`;
    // Update progress bar
    const bar = document.getElementById(`${prefix}-bar`);
    bar.style.width = `${percentage}%`;
    bar.className = `progress-fill ${getColorClass(percentage)}`;
    // Update reset time
    document.getElementById(`${prefix}-reset`).textContent =
        formatResetTime(resetsAt);
}
function getColorClass(percentage) {
    if (percentage >= 90)
        return "red";
    if (percentage >= 70)
        return "yellow";
    return "green";
}
function updateStatusIndicator(percentage) {
    const indicator = document.getElementById("status");
    indicator.className = `status-indicator ${getColorClass(percentage)}`;
}
function formatResetTime(isoString) {
    const resetDate = new Date(isoString);
    const now = new Date();
    const diffMs = resetDate.getTime() - now.getTime();
    if (diffMs <= 0) {
        return "Now";
    }
    const hours = Math.floor(diffMs / (1000 * 60 * 60));
    const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
    if (hours < 1) {
        return `Resets in ${minutes}m`;
    }
    return `Resets in ${hours}h ${minutes}m`;
}
function showError(message) {
    const alert = document.getElementById("alert");
    alert.textContent = message;
    alert.style.display = "block";
}
// Event listeners
document.getElementById("refresh").addEventListener("click", refreshQuota);
// Refresh on window show/focus
window.addEventListener("focus", refreshQuota);
// Hide window on ESC key
document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
        // Import getCurrentWindow dynamically to hide the window
        import("@tauri-apps/api/window").then(({ getCurrentWindow }) => {
            getCurrentWindow().hide();
        });
    }
});
// Initial load
refreshQuota();
