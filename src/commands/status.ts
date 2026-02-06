import chalk from "chalk";
import {
  getCredentialsFromKeychain,
  isTokenExpired,
  getTokenExpiryInfo,
  triggerTokenRefresh,
} from "../api/auth.js";
import { fetchQuota, QuotaResponse } from "../api/quota.js";
import {
  progressBar,
  formatResetDate,
  formatResetTime,
  statusColor,
  trafficLight,
  box,
} from "../display/terminal.js";

interface StatusOptions {
  raw?: boolean;
  refresh?: boolean;
}

export async function statusCommand(options: StatusOptions): Promise<void> {
  // Get credentials from Keychain
  let credentials = getCredentialsFromKeychain();

  if (!credentials) {
    console.error(chalk.red("Error: Could not find Claude Code credentials."));
    console.error(
      chalk.gray("Make sure you're logged into Claude Code and try again.")
    );
    console.error(chalk.gray('Run "claude" and complete login if needed.'));
    process.exit(1);
  }

  // Check token expiry
  const expiryInfo = getTokenExpiryInfo(credentials.expiresAt);
  if (expiryInfo.expired) {
    console.log(chalk.yellow("Token expired. Attempting refresh..."));

    const refreshed = await triggerTokenRefresh();
    if (refreshed) {
      // Re-read credentials after refresh
      credentials = getCredentialsFromKeychain();
      if (!credentials) {
        console.error(chalk.red("Error: Could not re-read credentials."));
        process.exit(1);
      }
      console.log(chalk.green("Token refreshed successfully.\n"));
    } else {
      console.error(chalk.red("Could not refresh token automatically."));
      console.error(chalk.gray("Please run Claude Code once to refresh:"));
      console.error(chalk.gray('  claude --print "hi"'));
      console.error(chalk.gray("Then run ts status again."));
      process.exit(1);
    }
  }

  try {
    const quota = await fetchQuota(credentials.accessToken);

    if (options.raw) {
      console.log(JSON.stringify(quota, null, 2));
      return;
    }

    printStatus(quota, credentials.subscriptionType, expiryInfo.expiresIn);
  } catch (error) {
    if (error instanceof Error) {
      console.error(chalk.red(`Error: ${error.message}`));

      if (error.message.includes("401")) {
        console.error(chalk.yellow("\nToken invalid. Try refreshing:"));
        console.error(chalk.gray('  claude --print "hi"'));
        console.error(chalk.gray("Then run ts status again."));
      }
    }
    process.exit(1);
  }
}

function printStatus(
  quota: QuotaResponse,
  subscriptionType?: string,
  tokenExpiresIn?: string
): void {
  const fiveHour = quota.five_hour;
  const sevenDay = quota.seven_day;

  const lines: string[] = [];

  // Header with traffic light
  const overallStatus = Math.max(fiveHour.utilization, sevenDay.utilization);
  lines.push(
    `${trafficLight(overallStatus)}  ${chalk.bold("TokenShepherd")}` +
      (subscriptionType ? chalk.gray(` (${subscriptionType})`) : "")
  );
  lines.push("");

  // 5-hour window
  lines.push(chalk.bold("5-Hour Window"));
  lines.push(
    `${progressBar(fiveHour.utilization)}  ${statusColor(fiveHour.utilization)(
      `${fiveHour.utilization.toFixed(0)}%`
    )}`
  );
  lines.push(chalk.gray(`Resets: ${formatResetDate(fiveHour.resets_at)}`));
  lines.push("");

  // 7-day window
  lines.push(chalk.bold("7-Day Window"));
  lines.push(
    `${progressBar(sevenDay.utilization)}  ${statusColor(sevenDay.utilization)(
      `${sevenDay.utilization.toFixed(0)}%`
    )}`
  );
  lines.push(chalk.gray(`Resets: ${formatResetDate(sevenDay.resets_at)}`));

  // Sonnet-specific if present
  if (quota.seven_day_sonnet) {
    lines.push("");
    lines.push(chalk.bold("7-Day Sonnet"));
    lines.push(
      `${progressBar(quota.seven_day_sonnet.utilization)}  ${statusColor(
        quota.seven_day_sonnet.utilization
      )(`${quota.seven_day_sonnet.utilization.toFixed(0)}%`)}`
    );
    lines.push(
      chalk.gray(`Resets: ${formatResetDate(quota.seven_day_sonnet.resets_at)}`)
    );
  }

  // Pace analysis (placeholder for v1.1)
  lines.push("");
  lines.push(chalk.gray("─".repeat(38)));
  lines.push("");

  // Quick status message
  if (overallStatus >= 90) {
    lines.push(chalk.red.bold("⚠ Critical: Approaching quota limit"));
    lines.push(chalk.gray("Consider waiting or using Sonnet"));
  } else if (overallStatus >= 70) {
    lines.push(chalk.yellow("⚡ Moderate usage - pace yourself"));
  } else {
    lines.push(chalk.green("✓ Quota healthy"));
  }

  // Time until reset
  const timeToReset = formatResetTime(fiveHour.resets_at);
  lines.push(chalk.gray(`5hr resets in: ${timeToReset}`));

  console.log("\n" + box(lines) + "\n");
}
