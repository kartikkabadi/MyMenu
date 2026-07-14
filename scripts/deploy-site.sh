#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${WHOP_CHECKOUT_URL:-}" ]]; then
  echo "Set WHOP_CHECKOUT_URL to your Whop checkout URL before deploying." >&2
  echo "Example: wrangler secret put WHOP_CHECKOUT_URL" >&2
  exit 1
fi

echo "$WHOP_CHECKOUT_URL" | wrangler secret put WHOP_CHECKOUT_URL
wrangler deploy
