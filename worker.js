export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/buy") {
      if (!env.WHOP_CHECKOUT_URL) {
        return new Response(
          "Whop checkout is not configured yet. Set the WHOP_CHECKOUT_URL secret before deploying.",
          { status: 503, headers: { "content-type": "text/plain; charset=utf-8" } },
        );
      }
      return Response.redirect(env.WHOP_CHECKOUT_URL, 302);
    }

    return env.ASSETS.fetch(request);
  },
};
