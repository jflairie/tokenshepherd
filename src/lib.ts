#!/usr/bin/env node

/**
 * Shared core library for TokenShepherd
 * Used by both CLI and menu bar app
 */

import {
  getCredentialsFromKeychain,
  triggerTokenRefresh,
  isTokenExpired,
  type ClaudeCredentials,
} from "./api/auth.js";
import { fetchQuota, type QuotaResponse } from "./api/quota.js";

/**
 * Get quota data with automatic token refresh if needed
 */
export async function getQuotaData(): Promise<QuotaResponse> {
  let creds = getCredentialsFromKeychain();

  // Check if credentials exist and are valid
  if (!creds || isTokenExpired(creds.expiresAt)) {
    console.error("Token expired or missing, attempting refresh...");
    await triggerTokenRefresh();
    creds = getCredentialsFromKeychain();
  }

  if (!creds) {
    throw new Error("No credentials available after refresh attempt");
  }

  return fetchQuota(creds.accessToken);
}

// CLI entry point when called directly with --quota flag
const args = process.argv.slice(2);
if (args.includes("--quota")) {
  getQuotaData()
    .then((data) => {
      console.log(JSON.stringify(data));
      process.exit(0);
    })
    .catch((error) => {
      console.error(JSON.stringify({ error: error.message }));
      process.exit(1);
    });
}
