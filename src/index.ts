#!/usr/bin/env node

import { Command } from "commander";
import { statusCommand } from "./commands/status.js";

const program = new Command();

program
  .name("ts")
  .description("TokenShepherd - Real-time Claude Code quota monitoring")
  .version("0.1.0");

program
  .command("status")
  .description("Show current quota status and pace prediction")
  .option("-r, --raw", "Output raw JSON")
  .action(statusCommand);

// Default command (no subcommand = status)
program.action(() => {
  statusCommand({});
});

program.parse();
