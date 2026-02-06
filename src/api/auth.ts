import { execSync } from "child_process";

interface OAuthCredentials {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  subscriptionType?: string;
  rateLimitTier?: string;
}

interface KeychainCredentials {
  claudeAiOauth?: OAuthCredentials;
  // Legacy format (direct at root)
  accessToken?: string;
  refreshToken?: string;
  expiresAt?: string;
  subscriptionType?: string;
  rateLimitTier?: string;
}

export interface ClaudeCredentials {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  subscriptionType?: string;
  rateLimitTier?: string;
}

export function getCredentialsFromKeychain(): ClaudeCredentials | null {
  try {
    const result = execSync(
      'security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null',
      { encoding: "utf-8" }
    );

    const keychain = JSON.parse(result.trim()) as KeychainCredentials;

    // Check for nested structure first (newer format)
    if (keychain.claudeAiOauth) {
      return keychain.claudeAiOauth;
    }

    // Fallback to root-level (legacy format)
    if (keychain.accessToken) {
      return {
        accessToken: keychain.accessToken,
        refreshToken: keychain.refreshToken || "",
        expiresAt: keychain.expiresAt || "",
        subscriptionType: keychain.subscriptionType,
        rateLimitTier: keychain.rateLimitTier,
      };
    }

    return null;
  } catch (error) {
    return null;
  }
}

export function isTokenExpired(expiresAt: string): boolean {
  const expiry = new Date(expiresAt);
  const now = new Date();
  // Add 5 minute buffer
  return now.getTime() > expiry.getTime() - 5 * 60 * 1000;
}

export function getTokenExpiryInfo(expiresAt: string): {
  expired: boolean;
  expiresIn: string;
} {
  const expiry = new Date(expiresAt);
  const now = new Date();
  const diffMs = expiry.getTime() - now.getTime();

  if (diffMs <= 0) {
    return { expired: true, expiresIn: "expired" };
  }

  const hours = Math.floor(diffMs / (1000 * 60 * 60));
  const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

  if (hours < 1) {
    return { expired: false, expiresIn: `${minutes}m` };
  }

  return { expired: false, expiresIn: `${hours}h ${minutes}m` };
}

/**
 * Attempt to refresh token by running Claude Code briefly.
 * This is a workaround since there's no public refresh endpoint.
 */
export async function triggerTokenRefresh(): Promise<boolean> {
  try {
    // Run claude with a simple command that triggers auth refresh
    execSync('echo "" | claude --print "hi" 2>/dev/null', {
      encoding: "utf-8",
      timeout: 10000,
    });
    return true;
  } catch {
    return false;
  }
}
