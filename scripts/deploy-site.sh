#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${WHOP_CHECKOUT_URL:-}" ]]; then
  echo "Set WHOP_CHECKOUT_URL to your Whop checkout URL before deploying." >&2
  echo "Example: wrangler secret put WHOP_CHECKOUT_URL" >&2
  exit 1
fi

if [[ "$WHOP_CHECKOUT_URL" != https://* && "$WHOP_CHECKOUT_URL" != http://* ]]; then
  echo "WHOP_CHECKOUT_URL must be an absolute http:// or https:// URL." >&2
  exit 1
fi

echo "$WHOP_CHECKOUT_URL" | wrangler secret put WHOP_CHECKOUT_URL
wrangler deploy
