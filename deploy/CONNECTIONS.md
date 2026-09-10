# Going live with a social platform

Everything that can be built without platform approval **is built**. This is the
list of what is left, and it is deliberately short.

When a platform's credentials appear in the environment, that platform's
"Connect" button stops being simulated and starts a real OAuth round trip. No
code change, no deploy flag. The card in Settings → Social accounts reads the
same `OAuthConfig.configured?` that the flow does, so the two can never
disagree.

---

## Already done (no approval needed)

| Piece | Where |
|---|---|
| Authorization redirect, `state` CSRF, PKCE (S256) | `app/commands/connections/start_authorization.rb` |
| Callback, state verification, code exchange | `app/controllers/connections/callbacks_controller.rb`, `complete_authorization.rb` |
| Token exchange + refresh (generic OAuth 2.0) | `app/integrations/social_provider/token_exchange.rb` |
| HTTP client: timeouts, transient/permanent error mapping | `app/integrations/social_provider/http_client.rb` |
| Base class for real adapters | `app/integrations/social_provider/oauth_adapter.rb` |
| Encrypted token storage | `SocialCredential` (`encrypts :access_token, :refresh_token`) |
| Nightly refresh ahead of expiry | `app/jobs/connections/refresh_expiring_tokens_job.rb`, `config/schedule.yml` |
| Per-provider endpoints and scopes | `app/integrations/social_provider/oauth_config.rb` |

## Left to do, per platform

1. **Register the app** on the platform and complete its review.
2. **Set two environment variables** (below) and restart.
3. **Verify the OAuth entry** against live docs, then set `verified_on:` in
   `oauth_config.rb`.
4. **Write the adapter** — one class, four methods.
5. **Register it**: `REAL_ADAPTERS = { "instagram" => Instagram::Adapter }`.

Step 4 is the only real coding, and it is only the parts that are genuinely
about that platform: `fetch_profile`, `publish`, `fetch_analytics`,
`fetch_conversations`. Everything else is inherited.

---

## The redirect URI

Register this **exactly**, on every platform. It must match byte for byte and
must be a single fixed value — which is why the workspace travels in the
session rather than in the path.

```
https://prachar.dcrayon.com/auth/instagram/callback
https://prachar.dcrayon.com/auth/facebook/callback
https://prachar.dcrayon.com/auth/linkedin/callback
https://prachar.dcrayon.com/auth/youtube/callback
https://prachar.dcrayon.com/auth/tiktok/callback
https://prachar.dcrayon.com/auth/google_business/callback
https://prachar.dcrayon.com/auth/x/callback
```

## Environment variables

One Meta app serves Instagram **and** Facebook. One Google app serves YouTube
**and** Google Business Profile. So seven platforms need five app registrations.

```
META_CLIENT_ID / META_CLIENT_SECRET          → instagram, facebook
GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET      → youtube, google_business
LINKEDIN_CLIENT_ID / LINKEDIN_CLIENT_SECRET  → linkedin
TIKTOK_CLIENT_KEY / TIKTOK_CLIENT_SECRET     → tiktok   (TikTok says "key", not "id")
X_CLIENT_ID / X_CLIENT_SECRET                → x
```

Both halves must be present. A client id with no secret gets a user all the way
to the consent screen and fails on the way back, which is a confusing place to
discover a typo — so a half-configured provider is treated as not configured.

---

## What each platform will ask of you

**Meta (Instagram + Facebook)** — Business verification with company documents,
then App Review with screencasts of each permission in use. The customer's
Instagram must be a Business or Creator account **linked to a Facebook Page**;
a personal account cannot be published to at all, no matter what you approve.
This is the most common "it connected but cannot post" cause.

**Google (YouTube + Business Profile)** — OAuth consent screen verification.
Uploads cost 1600 units against a default 10,000/day quota, so roughly **6
uploads per day** until you request more. Ask for quota early; it takes weeks.

**LinkedIn** — `w_member_social` covers posting as a person. Posting as a
company Page needs the Community Management API, which is a separate,
restricted application.

**TikTok** — Content Posting API requires an audit before direct posting is
allowed. Until it passes, posts can only be sent to a user's drafts.

**X** — Paid. Meaningful write access starts at a paid tier; there is no free
path to publishing.

---

## Before you flip a provider on

- [ ] Re-read that platform's current OAuth docs; fix `oauth_config.rb`
- [ ] Set `verified_on:` so it stops appearing in `OAuthConfig.unverified`
- [ ] Confirm the redirect URI matches on both sides, character for character
- [ ] Connect a real test account and publish one real post
- [ ] Confirm a token refresh works (`RefreshExpiringTokensJob`) before relying
      on the schedule

The scope and endpoint values in `oauth_config.rb` were written from published
documentation and **none have been verified against a live platform**. They are
the most volatile facts in this codebase. A wrong value fails loudly at the
consent screen rather than silently, but it will still waste an afternoon.
