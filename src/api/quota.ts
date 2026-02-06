export interface QuotaWindow {
  utilization: number;
  resets_at: string;
}

export interface ExtraUsage {
  is_enabled: boolean;
  monthly_limit: number | null;
  used_credits: number | null;
}

export interface QuotaResponse {
  five_hour: QuotaWindow;
  seven_day: QuotaWindow;
  seven_day_sonnet?: QuotaWindow;
  extra_usage: ExtraUsage;
}

export async function fetchQuota(accessToken: string): Promise<QuotaResponse> {
  const response = await fetch("https://api.anthropic.com/api/oauth/usage", {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "anthropic-beta": "oauth-2025-04-20",
      "User-Agent": "tokenshepherd/0.1.0",
    },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Quota API error (${response.status}): ${text}`);
  }

  return response.json() as Promise<QuotaResponse>;
}
