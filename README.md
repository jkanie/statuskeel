# statuskeel

statuskeel is an open-source status page with uptime checks, built on Ruby on Rails 8.1. It checks your URLs on a schedule and opens an incident when a check fails a set number of times in a row. The public page shows the result and updates live in the browser with no page reload.

It is for small teams and open-source projects that want a self-hosted status page on 1 server with no services beyond SQLite.

## Features

- Public status page at `/` with an overall state banner. Each monitor shows its state with 90 daily uptime bars and its uptime percentage.
- Live updates through Turbo Streams over Action Cable. The page has no JavaScript framework.
- Monitors with a URL (http or https), check interval, timeout, expected HTTP status range (default 200 to 399), optional body keyword, failure threshold (default 2), active flag.
- Checks run as Solid Queue jobs. Each check honours the timeout and follows at most 3 redirects. A check stores its result (up or down), HTTP status, response time, error text.
- Incidents open on their own when a monitor reaches its failure threshold and resolve on their own when it recovers, each time with an automatic update.
- Incidents by hand: statuses investigating, identified, monitoring, resolved. Impact none, minor, major, critical. Updates have rich text bodies (Action Text).
- E-mail subscribers with double opt-in. Every e-mail has an unsubscribe link and supports RFC 8058 one-click unsubscribe.
- Incidents by e-mail (Action Mailbox): an admin's e-mail to `incidents@` opens an incident, a reply to `incident+<id>@` adds an update. Mail from other senders is bounced.
- `/status.json` for scripts and an SVG badge per monitor at `/badge/<id>.svg` for READMEs.
- Server-side request forgery guard: addresses in private, loopback, link-local, reserved ranges are refused at save time and again at check time (also after DNS changes and redirects), unless `ALLOW_PRIVATE_TARGETS` is on.
- Admin sign-in with the Rails 8 authentication generator. There is no public sign-up.
- Deploys to 1 server with Kamal 2. Secrets come from the environment, never from the repo.

## Rails parts in use

| Part | Where | What it does here |
| --- | --- | --- |
| Authentication generator | `app/controllers/concerns/authentication.rb`, `app/models/session.rb` | Admin sign-in with password reset by e-mail. The admin screens need a session. |
| `rate_limit` | `SessionsController`, `SubscribersController` | Limits sign-in attempts to 10 in 3 minutes and subscriptions to 5 in 10 minutes per IP address. |
| `params.expect` | Admin controllers | Strong parameters in the Rails 8 form. |
| Solid Queue | `app/jobs`, `config/recurring.yml` | Runs the checks and the subscriber e-mails. 2 recurring tasks enqueue due checks every minute and prune old data every day. |
| `limits_concurrency` | `CheckMonitorJob` | At most 1 check per monitor runs at a time. A 2nd one is discarded. |
| `ActiveJob.perform_all_later`, `ActionMailer.deliver_all_later` | `EnqueueDueChecksJob`, `NotifySubscribersJob` | Enqueue many jobs with 1 insert. |
| Solid Cable | `config/cable.yml` | Carries Turbo Stream broadcasts from job processes to browsers, in development too. |
| Solid Cache | `config/environments/production.rb` | The production cache, which also holds the rate limit counters. |
| Turbo Streams | `app/models/status_page.rb`, `app/views/status` | After each change, every open page gets new HTML for the parts that changed (banner, monitor row, incident lists). |
| Action Text | `IncidentUpdate#body` | Rich text incident updates in the admin screens, rendered on the page and in e-mails. |
| Action Mailbox | `app/mailboxes` | Opens and updates incidents from e-mail through the relay ingress. |
| Action Mailer | `app/mailers` | Confirmation e-mails, incident e-mails with `List-Unsubscribe` headers, bounce replies. Previews live in `test/mailers/previews`. |
| `generates_token_for` | `Subscriber` | Signed confirmation tokens that expire after 3 days and stop working once used, plus unsubscribe tokens. |
| `normalizes`, `enum` with `validate: true` | Models | Clean e-mail addresses and URLs, readable string enums that fail validation instead of raising. |
| `upsert` with `on_duplicate` | `DailyUptime.record!` | Adds each check to the per-day counts in 1 statement. |
| Jbuilder | `app/views/status/show.json.jbuilder` | The `/status.json` summary. |
| Propshaft, import maps | `app/assets`, `config/importmap.rb` | CSS and JavaScript without Node or a build step. |
| Kamal 2, Thruster | `config/deploy.yml`, `.kamal/secrets`, `Dockerfile` | Container deploy to 1 server with automatic TLS. |
| Minitest, Capybara | `test/` | Tests for models, jobs, mailers, the mailbox, the cable connection, controllers, integration flows, the browser (system tests). |

The monitor model is called `UptimeMonitor` because Ruby already defines a `Monitor` class.

## Built with

| Part | Version |
| --- | --- |
| Ruby | 4.0.9 |
| Rails | 8.1.4.1 |
| Bundler | 4.0.20 |
| sqlite3 gem | 2.10.2 |
| Solid Queue | 1.7.2 |
| Solid Cache | 1.0.10 |
| Solid Cable | 4.1.0 |
| turbo-rails | 2.0.23 |
| stimulus-rails | 1.3.4 |
| importmap-rails | 2.2.3 |
| Propshaft | 1.3.2 |
| Puma | 8.0.2 |
| Kamal | 2.12.0 |
| Thruster | 0.1.27 |
| Capybara | 3.40.0 |
| Cuprite (Ferrum) | 0.20.1 |
| WebMock | 3.34.0 |
| Minitest | 6.1.0 |
| Brakeman | 8.1.0 |
| RuboCop Rails Omakase | 1.1.0 |
| bundler-audit | 0.9.3 |

## Set-up

You need Ruby 4.0.9 (see `.ruby-version`). The sqlite3 gem brings its own SQLite library. The system tests also need Chrome or Chromium.

```sh
git clone https://github.com/jkanie/statuskeel.git
cd statuskeel
bin/setup --skip-server
```

`bin/setup` installs the gems and creates the development databases. Creating them also loads `db/seeds.rb`, which adds 3 sample monitors (example.com, example.org, example.net) and 1 resolved incident.

Create the admin. There is no sign-up page, so this is the only way in. The password needs at least 12 characters. Run the same command again to reset the password.

```sh
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='at least 12 characters' bin/rails admin:create
```

Start the app:

```sh
bin/dev
```

Open http://localhost:3000 for the status page and http://localhost:3000/session/new to sign in.

### Background jobs

`bin/dev` sets `SOLID_QUEUE_IN_PUMA=1`, so Puma starts the Solid Queue supervisor next to the web server. Its scheduler runs `EnqueueDueChecksJob` every minute and `PruneChecksJob` every day at 3:15 (`config/recurring.yml`). The first checks run within a minute of the start.

To run the jobs in their own process instead, start `bin/rails server` in 1 terminal and `bin/jobs` in another.

## Settings

Every setting is an environment variable. Production reads secrets only from the environment: the repo has no `config/master.key` and no `config/credentials.yml.enc`.

| Variable | Default | Used for |
| --- | --- | --- |
| `SECRET_KEY_BASE` | none, required in production | Signs cookies and the subscriber tokens. Create 1 with `bin/rails secret`. Development and tests use `tmp/local_secret.txt`. |
| `APP_HOST` | `status.example.com` | Production host name for links in e-mails and for the host check. |
| `STATUS_PAGE_TITLE` | `Statuskeel` | Title of the public page and of the e-mails. |
| `MAIL_FROM` | `Statuskeel <status@example.com>` | Sender of every e-mail. |
| `SMTP_ADDRESS` | not set | SMTP server for production e-mail. Without it, production sends through SMTP on localhost port 25 (the Rails default). |
| `SMTP_PORT` | `587` | SMTP port. |
| `SMTP_USERNAME` | not set | SMTP user name. |
| `SMTP_PASSWORD` | not set | SMTP password. |
| `RAILS_INBOUND_EMAIL_PASSWORD` | not set | Password of the Action Mailbox relay ingress. Requests to the ingress fail while it is not set. |
| `ALLOW_PRIVATE_TARGETS` | `false` | Any of `true`, `1`, `yes`, `on` lets monitors point at addresses in private, loopback, link-local, reserved ranges. Leave it off on a public server. |
| `CHECK_RETENTION_DAYS` | `90` | Days of checks and daily counts to keep. |
| `SOLID_QUEUE_IN_PUMA` | set by `bin/dev` and `config/deploy.yml` | Runs the Solid Queue supervisor inside Puma. |
| `JOB_CONCURRENCY` | `1` | Solid Queue worker processes (`config/queue.yml`). |
| `RAILS_MAX_THREADS` | `3` for Puma, `5` for the database pool | Puma threads and database connections. |
| `PORT` | `3000` | Puma port. |
| `RAILS_LOG_LEVEL` | `info` | Production log level. |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | not set | Read only by `bin/rails admin:create`. |
| `BROWSER_PATH` | Chrome on the `PATH` | Chrome or Chromium binary for the system tests. |

## Deploy with Kamal

`config/deploy.yml` deploys to 1 server. The 4 SQLite databases and the Active Storage files live in the `statuskeel_storage` volume, so back up that volume.

1. Replace every value marked `CHANGE ME` in `config/deploy.yml`: `image`, the server address under `servers`, `proxy.host`, the `registry` server and user name, `APP_HOST`, `STATUS_PAGE_TITLE`, `MAIL_FROM`, `SMTP_ADDRESS`.
2. Point the DNS record of `proxy.host` at the server. Kamal Proxy gets a Let's Encrypt certificate for it.
3. Export the secrets that `.kamal/secrets` reads, on the machine you deploy from:

   ```sh
   export KAMAL_REGISTRY_PASSWORD=...          # registry access token
   export SECRET_KEY_BASE=$(bin/rails secret)
   export RAILS_INBOUND_EMAIL_PASSWORD=...     # shared with your mail server
   export SMTP_USERNAME=... SMTP_PASSWORD=...
   ```

4. Set up the server and deploy: `bin/kamal setup` the 1st time, `bin/kamal deploy` after that.
5. Create the admin in the running container:

   ```sh
   bin/kamal app exec --reuse -e ADMIN_EMAIL:you@example.com -e ADMIN_PASSWORD:'at least 12 characters' "bin/rails admin:create"
   ```

`bin/kamal config` parses this file with the placeholders in place. A deploy to a real server has not been run for this release.

The container starts with `bin/rails db:prepare`. It skips the sample data in production.

## Inbound e-mail

Action Mailbox uses the relay ingress in production (`config.action_mailbox.ingress = :relay`). Your mail server posts each raw message to `https://<APP_HOST>/rails/action_mailbox/relay/inbound_emails` with HTTP basic authentication: user name `actionmailbox`, password `RAILS_INBOUND_EMAIL_PASSWORD`.

From a host with the app checked out, Rails has a task per mail server:

```sh
bin/rails action_mailbox:ingress:postfix URL=https://status.example.com/rails/action_mailbox/relay/inbound_emails INGRESS_PASSWORD=...
```

The same request with curl, for a mail server that cannot run Ruby:

```sh
curl --fail -u "actionmailbox:$RAILS_INBOUND_EMAIL_PASSWORD" -H "Content-Type: message/rfc822" \
  --data-binary @message.eml https://status.example.com/rails/action_mailbox/relay/inbound_emails
```

Both forms were run against the app in production mode. An e-mail to `incidents@` opened an incident. A reply to `incident+<id>@` added an update without the quoted text.

| Address | Result |
| --- | --- |
| `incidents@<your domain>` | Opens an incident. The subject is the title, the body is the 1st update. |
| `incident+<id>@<your domain>` | Adds an update to incident `<id>`. The status stays as it is: change it on the admin screen. |

Only mail whose `From` address belongs to an admin is accepted. Everything else is bounced with a short reply. The check trusts the `From` header, so let your mail server check SPF, DKIM, DMARC before it relays a message.

In development, the Action Mailbox conductor at http://localhost:3000/rails/conductor/action_mailbox/inbound_emails lets you send a test e-mail through the same mailbox.

## Tests

```sh
bin/rails test           # 120 runs, 497 assertions, 0 failures
bin/rails test:system    # 2 runs, 11 assertions, 0 failures
bin/rubocop              # 103 files inspected, no offenses detected
bin/brakeman --no-pager  # 0 security warnings
bin/importmap audit      # No vulnerable packages found
bin/bundler-audit        # No vulnerabilities found
bin/ci                   # runs all of the above plus the seeds
```

The counts are from a run on Linux with Ruby 4.0.9. Outbound HTTP is stubbed with WebMock and DNS answers are made up in `test/test_helper.rb`, so the tests do not reach the network.

The system tests drive headless Chrome with Cuprite over the DevTools protocol, so no chromedriver is needed. They use the Chrome on the `PATH`, or the binary in `BROWSER_PATH`. 1 of them opens the public page and fails a monitor twice, then lets the monitor recover. After each step it checks the banner, the monitor row, the incident lists. At the end it checks that the page did not reload.

GitHub Actions (`.github/workflows/ci.yml`) runs the same checks in 5 jobs: `scan_ruby`, `scan_js`, `lint`, `test`, `system-test`.

## Licence

MIT. See [LICENSE](LICENSE).
