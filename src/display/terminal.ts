import chalk from "chalk";

export function progressBar(percent: number, width: number = 20): string {
  const filled = Math.round((percent / 100) * width);
  const empty = width - filled;

  let color = chalk.green;
  if (percent >= 70) color = chalk.yellow;
  if (percent >= 90) color = chalk.red;

  return color("█".repeat(filled)) + chalk.gray("░".repeat(empty));
}

export function formatResetTime(resetAt: string): string {
  const reset = new Date(resetAt);
  const now = new Date();
  const diffMs = reset.getTime() - now.getTime();

  if (diffMs < 0) return "now";

  const hours = Math.floor(diffMs / (1000 * 60 * 60));
  const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

  if (hours < 1) return `${minutes}m`;
  if (hours < 24) return `${hours}h ${minutes}m`;

  const days = Math.floor(hours / 24);
  const remainingHours = hours % 24;
  return `${days}d ${remainingHours}h`;
}

export function formatResetDate(resetAt: string): string {
  const reset = new Date(resetAt);
  const now = new Date();

  const isToday = reset.toDateString() === now.toDateString();

  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const isTomorrow = reset.toDateString() === tomorrow.toDateString();

  const timeStr = reset.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });

  if (isToday) return `today at ${timeStr}`;
  if (isTomorrow) return `tomorrow at ${timeStr}`;

  const dayStr = reset.toLocaleDateString("en-US", { weekday: "long" });
  return `${dayStr} at ${timeStr}`;
}

export function statusColor(percent: number): typeof chalk {
  if (percent >= 90) return chalk.red;
  if (percent >= 70) return chalk.yellow;
  return chalk.green;
}

export function trafficLight(percent: number): string {
  if (percent >= 90) return chalk.red("●");
  if (percent >= 70) return chalk.yellow("●");
  return chalk.green("●");
}

export function box(lines: string[], title?: string): string {
  const width = Math.max(...lines.map((l) => stripAnsi(l).length), 40);
  const top = "╭" + "─".repeat(width + 2) + "╮";
  const bottom = "╰" + "─".repeat(width + 2) + "╯";

  let header = "";
  if (title) {
    header = "│ " + chalk.bold(title.padEnd(width)) + " │\n";
    header += "├" + "─".repeat(width + 2) + "┤\n";
  }

  const content = lines
    .map((line) => {
      const padding = width - stripAnsi(line).length;
      return "│ " + line + " ".repeat(padding) + " │";
    })
    .join("\n");

  return top + "\n" + header + content + "\n" + bottom;
}

function stripAnsi(str: string): string {
  return str.replace(/\x1b\[[0-9;]*m/g, "");
}
