#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -n "${WHOP_CHECKOUT_URL:-}" ]]; then
  if [[ "$WHOP_CHECKOUT_URL" != https://* && "$WHOP_CHECKOUT_URL" != http://* ]]; then
    echo "WHOP_CHECKOUT_URL must be an absolute http:// or https:// URL." >&2
    exit 1
  fi

  secret_file="$(mktemp)"
  trap 'rm -f "$secret_file"' EXIT
  umask 077
  printf '%s' "$WHOP_CHECKOUT_URL" > "$secret_file"
  wrangler secret put WHOP_CHECKOUT_URL < "$secret_file"
else
  echo "Using the existing WHOP_CHECKOUT_URL secret. Set it interactively first with:"
  echo "  wrangler secret put WHOP_CHECKOUT_URL"
fi

wrangler deploy
