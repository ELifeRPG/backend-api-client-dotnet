# Pending: `eliferpg-core` dispatch workflow

`.github/workflows/release.yml` in this repo is triggered by a `repository_dispatch` event sent
from `eliferpg-core` whenever its OpenAPI spec changes on `main`. The workflow that sends it is
open as [ELifeRPG/backend#139](https://github.com/ELifeRPG/backend/pull/139), but it can't be
merged as functional until a GitHub App is created and installed by hand (see below) — GitHub
doesn't expose App registration via `gh`/API without an interactive browser step, so this is a
manual follow-up, not something that can be automated here.

In the meantime, `release.yml` can still be run manually via `workflow_dispatch` (see
`README.md`), or the `core_ref` input can be pointed at any `eliferpg-core` ref on demand.

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

## Steps to apply

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
5. Merge [#139](https://github.com/ELifeRPG/backend/pull/139). From then on, every push to `main`
   that changes `openapi/eliferpg-api-v1.json` will trigger `backend-api-client-dotnet`'s release
   workflow automatically with the exact commit SHA the spec came from.

For reference, the workflow being merged (`eliferpg-core`'s
`.github/workflows/dispatch-client-generation.yml`):

```yaml
name: Dispatch client generation

on:
  push:
    branches: [ main ]
    paths:
      - 'openapi/eliferpg-api-v1.json'

jobs:
  dispatch:
    runs-on: ubuntu-latest
    steps:
      - name: Generate GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v3
        with:
          app-id: ${{ vars.DISPATCH_APP_ID }}
          private-key: ${{ secrets.DISPATCH_APP_PRIVATE_KEY }}
          repositories: backend-api-client-dotnet

      - name: Notify backend-api-client-dotnet
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          gh api repos/ELifeRPG/backend-api-client-dotnet/dispatches \
            -f event_type=core-spec-updated \
            -f "client_payload[sha]=${{ github.sha }}"
```
