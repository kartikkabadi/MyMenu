export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/buy") {
      const configuredCheckoutURL = String(env.WHOP_CHECKOUT_URL || "").trim();
      if (!configuredCheckoutURL) {
        return new Response(
          "Whop checkout is not configured yet. Set the WHOP_CHECKOUT_URL secret before deploying.",
          { status: 503, headers: { "content-type": "text/plain; charset=utf-8" } },
        );
      }

      let checkoutURL;
      try {
        checkoutURL = new URL(configuredCheckoutURL);
      } catch {
        return new Response(
          "Whop checkout is configured, but it is not a valid absolute URL. Update WHOP_CHECKOUT_URL and redeploy.",
          { status: 502, headers: { "content-type": "text/plain; charset=utf-8" } },
        );
      }

      if (!['https:', 'http:'].includes(checkoutURL.protocol)) {
        return new Response(
          "Whop checkout must use an http:// or https:// URL. Update WHOP_CHECKOUT_URL and redeploy.",
          { status: 502, headers: { "content-type": "text/plain; charset=utf-8" } },
        );
      }

      return Response.redirect(checkoutURL.toString(), 302);
    }

    return env.ASSETS.fetch(request);
  },
};
