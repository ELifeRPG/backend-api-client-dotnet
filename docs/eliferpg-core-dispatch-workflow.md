# Pending: `eliferpg-core` dispatch workflow

`.github/workflows/release.yml` in this repo is triggered by a `repository_dispatch` event sent
from `eliferpg-core` whenever its OpenAPI spec changes on `main`. That trigger doesn't exist yet —
`eliferpg-core`'s local clone has diverged from its GitHub remote (`origin/main`) and needs to be
reconciled before any workflow can be safely added and pushed there. This is tracked here so the
arrangement isn't lost; apply it once that repo is in a pushable state.

In the meantime, `release.yml` can still be run manually via `workflow_dispatch` (see
`README.md`), or the `core_ref` input can be pointed at any `eliferpg-core` ref on demand.

## Steps to apply, once `eliferpg-core` is ready

1. Reconcile `eliferpg-core`'s local `main` with `origin/main` (the local clone currently has
   only a single throwaway "Initial commit" that never matched the real remote history — a plain
   `git reset --hard origin/main` was the recommended fix when this was investigated, since the
   local clone had no work worth keeping).

2. Create a fine-grained GitHub PAT with `repo` scope (or at minimum permission to trigger
   `repository_dispatch`) against `ELifeRPG/backend-api-client-dotnet`, since the default
   `GITHUB_TOKEN` in `eliferpg-core`'s Actions runs cannot dispatch events to a different repo.
   Store it as a secret named `DISPATCH_TOKEN` in `eliferpg-core`'s repo settings
   (Settings → Secrets and variables → Actions).

3. Add the following file to `eliferpg-core` as
   `.github/workflows/dispatch-client-generation.yml`:

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
         - name: Notify backend-api-client-dotnet
           env:
             GH_TOKEN: ${{ secrets.DISPATCH_TOKEN }}
           run: |
             gh api repos/ELifeRPG/backend-api-client-dotnet/dispatches \
               -f event_type=core-spec-updated \
               -f "client_payload[sha]=${{ github.sha }}"
   ```

4. Commit and push. From then on, every push to `main` that changes
   `openapi/eliferpg-api-v1.json` will trigger `backend-api-client-dotnet`'s release workflow
   automatically with the exact commit SHA the spec came from.
