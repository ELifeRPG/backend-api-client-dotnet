# The `eliferpg-core` dispatch trigger

`.github/workflows/release.yml` in this repo is triggered by a `repository_dispatch` event sent from
`eliferpg-core` whenever its OpenAPI spec changes on `main`. The sending workflow is
[`.github/workflows/dispatch-client-generation.yml`](https://github.com/ELifeRPG/backend/blob/main/.github/workflows/dispatch-client-generation.yml)
over there, merged as [ELifeRPG/backend#139](https://github.com/ELifeRPG/backend/pull/139), and it
has been live since 2026-08-25.

It authenticates as a GitHub App, which had to be registered and installed by hand — GitHub does not
expose App registration through `gh` or the API without an interactive browser step. That setup is
done; what follows is the reasoning, and the steps as a reference for rotating the key or recreating
the App.

`release.yml` can also be run manually via `workflow_dispatch` (see `README.md`), pointing
`core_ref` at any `eliferpg-core` ref. That is for on-demand regeneration, not a fallback — the
automatic path needs no help. A manual run against a ref whose spec already matches the committed
submodule pin does nothing and releases nothing, by design.

## Why a GitHub App instead of a personal access token

The cross-repo `repository_dispatch` call needs a token with permission to hit
`ELifeRPG/backend-api-client-dotnet`'s `dispatches` endpoint — the default `GITHUB_TOKEN` in
`eliferpg-core`'s Actions runs can't dispatch events to a different repo. A personal PAT would
work but ties this piece of CI automation to one person's GitHub account (shows up as them in
audit logs, breaks if they leave/rotate credentials). A GitHub App is an org-owned identity
instead: installed only on the one target repo, scoped to the one permission the endpoint actually
needs (`Contents: write`), and exchanged for a short-lived installation token at workflow-run time
via [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token) rather
than a long-lived stored credential.

## Steps, as applied

1. Create a GitHub App owned by the `ELifeRPG` org: org **Settings** → **Developer settings** →
   **GitHub Apps** → **New GitHub App**.
   - No webhook needed (leave "Active" unchecked under Webhook).
   - Repository permissions → **Contents: Read and write** (the only permission the `dispatches`
     endpoint requires — nothing else).
   - "Where can this GitHub App be installed?" → **Only on this account**.
2. On the App's settings page, **Generate a private key** (downloads a `.pem` file — keep it, it's
   shown only once).
3. **Install App** → select the `ELifeRPG` org → "Only select repositories" →
   `backend-api-client-dotnet` → Install.
4. In `eliferpg-core`'s repo settings (**Settings** → **Secrets and variables** → **Actions**):
   - Add a repo **variable** named `DISPATCH_APP_ID` with the App's ID (shown on its settings
     page).
   - Add a repo **secret** named `DISPATCH_APP_PRIVATE_KEY` with the full contents of the
     downloaded `.pem` file.
5. Merge the dispatch workflow in `eliferpg-core` (done in
   [#139](https://github.com/ELifeRPG/backend/pull/139)). Every push to `main` that changes
   `openapi/eliferpg-api-v1.json` then triggers this repo's release workflow with the exact commit
   SHA the spec came from.
