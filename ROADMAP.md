# Roadmap

The next features for statuskeel, 32 hours of work in total, in the order they are planned.

## 1. Webhook and Slack alerts, 4 hours

- What: a `Notifier` model with a URL and a kind (generic JSON webhook or Slack incoming webhook). Each new incident update sends 1 signed POST from a Solid Queue job with retries. Admin screens to add, test, remove notifiers.
- Why: teams watch chat more than e-mail, and other tools can react to the JSON payload.

## 2. TLS certificate expiry checks, 3 hours

- What: for https monitors, record the certificate's expiry date on each check and open a minor incident 14 days before it expires (the number of days is a setting).
- Why: an expired certificate takes a site down as surely as a crash, and it is easy to see coming.

## 3. Response-time charts, 3 hours

- What: an inline SVG chart of response times for the last 24 hours and 7 days on the admin monitor page, drawn from the checks table on the server with no JavaScript library.
- Why: slow responses often come before an outage. The data is already stored with every check.

## 4. Maintenance windows, 3 hours

- What: a maintenance window has a start, an end, a list of monitors. Checks still run during it, but no automatic incident opens.
- Why: planned work should not page subscribers or count as an outage.

## 5. Scheduled maintenance notices, 2 hours

- What: show upcoming maintenance windows on the public page and in `/status.json`, and e-mail subscribers when a window is scheduled and when it starts.
- Why: users plan around downtime they know about.

## 6. Component groups, 3 hours

- What: group monitors (for example "API" with several endpoints) with 1 combined state and collapsible rows on the public page.
- Why: a page with many monitors stays readable, and visitors see the parts of the service they use.

## 7. Multi-region checks with a small agent, 5 hours

- What: a small Ruby agent that runs the same HTTP check from another region and posts results to an authenticated endpoint. A monitor counts as down only when most regions agree.
- Why: 1 vantage point cannot tell a real outage from a network problem near the checker.

## 8. API tokens, 3 hours

- What: hashed API tokens per admin and a JSON API to open, update, resolve incidents. Tests cover the tokens and the rate limits.
- Why: deploy scripts and incident tools can post updates without a browser.

## 9. Private status pages, 2 hours

- What: a setting that puts the whole public side (page, `/status.json`, badges) behind sign-in or a shared access token.
- Why: internal services need a status page that is not public.

## 10. Translations (i18n), 2 hours

- What: move every string to `config/locales`, add French, pick the language from the `Accept-Language` header.
- Why: a status page speaks to all users of a service, and Canada alone needs English and French.

## 11. Release v0.1.0, 2 hours

- What: a CHANGELOG plus a `v0.1.0` tag. A GitHub Actions job builds the Docker image on each tag and pushes it to the GitHub Container Registry.
- Why: people can run a tagged image instead of building from source.
