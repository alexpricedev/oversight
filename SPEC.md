# Oversight: spec

A native macOS app that shows, in one window, what's happening across every
GitHub repo we own: workflows running now, recent deploys, open pull requests
and open issues.

GitHub has no cross-repo view of Actions, so today this means opening each
repo's Actions tab. Oversight puts it on one screen.

## Scope (v1)

**In:**

- Every repo under `alexpricedev`, with more owners (orgs) addable later from
  Settings.
- **Running now:** every workflow run that is queued or in progress, across all
  repos, all workflows.
- **Recent deploys:** the last 5 runs of each repo's deploy workflow.
- **Open pull requests,** with the CI status of each PR's head commit.
- **Open GitHub issues.**
- Clicking anything opens it on github.com.

**Out (not v1):** a menu bar item, notifications, acting on GitHub (re-running
jobs, merging, commenting), Asana, non-GitHub CI.

## Platform and stack

- macOS 15 or later, SwiftUI, a single main window.
- Swift concurrency (`async`/`await`) and `URLSession` for the GitHub REST API.
  No third-party dependencies.
- Tokens in the macOS Keychain (Security framework). Nothing secret in
  `UserDefaults` or on disk.
- Read-only: the app never writes to GitHub.

## Accounts and tokens

GitHub's fine-grained personal access tokens belong to one account (a user or
an org-owned token), so the app holds **one token per account**.

- The account and the repo owner are separate ideas. An account's token reads
  its own repositories and those of every organization the account belongs to;
  the organization never gets a token of its own.
- Settings lists the accounts. "Add owner" asks for the account name and a
  token, checks the token with `GET /user` (and that it can list repos), then
  saves it to the Keychain.
- Settings also lists the organizations found in each account's repo list,
  each with a switch, and accepts an organization added by name. Only
  switched-on organizations are shown and polled, and the set is persisted in
  UserDefaults (`includedOrgs`). `GET /user/orgs` is not used: GitHub returns
  an empty list to fine-grained tokens.
- Required token permissions, all **read-only**: Metadata, Actions, Pull
  requests, Issues. Settings shows this list with a link to GitHub's
  token-creation page.
- The first owner is `alexpricedev`.

## Data and GitHub API

Per account, using that account's token:

| Need | Endpoint |
| --- | --- |
| Repos the token can see | `GET /user/repos?per_page=100&affiliation=owner,organization_member` (paginate); grouped by `owner.login`; archived repos and forks excluded |
| Runs in a repo | `GET /repos/{owner}/{repo}/actions/runs?per_page=20` |
| Deploys in a repo | `GET /repos/{owner}/{repo}/actions/workflows/deploy.yml/runs?per_page=5` (a 404 means the repo has no deploy workflow) |
| Open PRs and issues | `GET /search/issues?q=is:open+is:pr+user:{owner}` and `...is:issue...` (one call each per owner; use `org:` for orgs) |
| Fallback for PRs and issues | `GET /repos/{owner}/{repo}/pulls?state=open` and `GET /repos/{owner}/{repo}/issues?state=open` (issues also lists PRs; drop items with a `pull_request` field). Use these if search doesn't return private repos for a fine-grained token; check this first in milestone 3 |
| CI status of a PR | `GET /repos/{owner}/{repo}/actions/runs?head_sha={sha}` (fine-grained tokens can't read the Checks API) |

**What counts as a deploy:** the workflow at `.github/workflows/deploy.yml`.
That's our convention in every app repo. Each deploy row shows the run's
status and conclusion, the commit message (first line) and short SHA, the
branch or tag (a `v*` tag means a production release), when it started and how
long it took.

## Polling and rate limits

GitHub allows 5,000 requests an hour per token.

- **Conditional requests:** keep each response's `ETag`, and send
  `If-None-Match` next time. A `304 Not Modified` doesn't count against the
  limit, so most polls are free.
- **Active repos poll more often:** a repo with a run in progress polls every
  15 seconds; a repo pushed to in the last 7 days every 60 seconds; others every
  10 minutes. The repo list refreshes every 10 minutes.
- **Search (PRs and issues):** every 60 seconds per owner (the search API allows
  30 requests a minute).
- Read `x-ratelimit-remaining` and `x-ratelimit-reset` on every response. Below
  10% remaining, slow all polling down; show the remaining count in the footer.
- Polling pauses while the window is closed or the Mac is asleep, and refreshes
  immediately on reopen. A Refresh button (⌘R) forces a full refresh.

## The window

One window, four sections, top to bottom. Each row shows the repo name.

1. **Running now:** workflow name, repo, branch, how long it's been running.
   Empty state: "Nothing running".
2. **Recent deploys:** one group per repo with a deploy workflow, newest repo
   activity first, each with its last 5 runs (✅ success, ❌ failure,
   ⏳ in progress, ⚪️ cancelled or skipped).
3. **Pull requests:** title, repo, author, age, CI status of the head commit,
   draft badge.
4. **Issues:** title, repo, labels, age.

Toolbar: an owner filter (all, or one owner), a text filter on repo name, and
Refresh. Footer: last refreshed time and rate-limit remaining per token.

Errors are shown in place, not as alerts: an expired or under-permissioned
token shows a banner on that owner with a link to Settings; a repo whose call
fails shows a small warning icon on its rows.

## Settings

- Owners: add, remove, replace token.
- Organizations: one switch per discovered organization, showing which
  account reads it and how many repositories it has. Off by default.
- Repos to hide: a list of `owner/repo` to leave out (for example archived
  experiments that aren't archived on GitHub).

## Testing

- The GitHub client behind a protocol, with a fake that returns fixture JSON,
  so the view models are tested without network.
- Unit tests for: deploy-row parsing, PR CI-status rollup (any failure =
  failure, any in progress = pending, all success = success), polling intervals
  and the rate-limit backoff, ETag handling (304 keeps the previous data).

## Milestones

1. Settings with one owner and its token in the Keychain; the repo list.
2. Running now and Recent deploys, with polling and ETags.
3. Pull requests (with CI status) and Issues.
4. Multiple owners, the owner filter, hidden repos.

## Open questions

- Should forks we own appear, or only source repos? (Default: source repos
  only.)
- Should the app be signed and notarised for use on more than one Mac, or run
  from Xcode for now? (Default: run from Xcode.)
