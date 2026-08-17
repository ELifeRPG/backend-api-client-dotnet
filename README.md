# backend-api-client-dotnet

Kiota-generated C# client for the ELifeRPG Central API ([`eliferpg-core`](https://github.com/ELifeRPG/backend)).

Published as the `ELifeRPG.BackendApiClient` NuGet package to GitHub Packages. Consumers (e.g.
`eliferpg-reforger-bridge`, `npc-virtual-simulation`) add a reference to that package instead of
generating their own client.

## Regenerating the client

`src/ELifeRPG.BackendApiClient/Generated` is Kiota-generated — never hand-edit it.

First time, restore the local `kiota` tool (defined in `.config/dotnet-tools.json`):

```sh
dotnet tool restore
```

`eliferpg-core` is vendored as a git submodule at `eliferpg-core/` (spec-only, via sparse-checkout)
so the exact commit the client was generated from is tracked in git history. Initialize it, then
generate against its spec:

```sh
git submodule update --init eliferpg-core

bash scripts/generate-client.sh --openapi eliferpg-core/openapi/eliferpg-api-v1.json
```

To regenerate against a newer Central API, update the submodule first (`cd eliferpg-core && git
pull origin main && cd ..`), then re-run the script and commit both the submodule bump and the
regenerated `Generated/` diff together.

Kiota's CLI targets a stable .NET runtime — this repo's `global.json` already pins one (unlike
`eliferpg-core`/`eliferpg-reforger-bridge`, which build against a preview SDK and need a stable
runtime installed side by side).

## Automated regeneration and release

`.github/workflows/release.yml` handles the full cycle, triggered either by a
`repository_dispatch` from `eliferpg-core` (sent whenever `openapi/eliferpg-api-v1.json` changes
on its `main` branch) or manually via `workflow_dispatch`.

**The `eliferpg-core` side of that trigger isn't wired up yet** — see
[`docs/eliferpg-core-dispatch-workflow.md`](docs/eliferpg-core-dispatch-workflow.md) for the
pending workflow to add there and why it's blocked. Until then, use `workflow_dispatch` (with an
optional `core_ref` input) to run a regeneration on demand.

Once triggered, the workflow:

1. Checks out the `eliferpg-core` submodule at its currently-committed pin (the "old" spec) and
   saves a copy of its spec file.
2. Updates the submodule to the target ref (the dispatched commit SHA, or `core_ref` on a manual
   run) and diffs the new spec against the saved copy using
   [`oasdiff`](https://github.com/oasdiff/oasdiff).
   - No differences → workflow stops, nothing is released, the submodule bump is discarded.
   - Only additive/non-breaking differences → **minor** version bump.
   - Any breaking differences → **major** version bump.
3. Regenerates the client, commits the diff (`feat:` / `feat!:` depending on breaking-ness) — the
   commit includes the submodule pointer bump, so the exact `eliferpg-core` commit the client was
   generated from is always recoverable from git history — and tags `vX.Y.Z`.
4. Packs and publishes `ELifeRPG.BackendApiClient` to GitHub Packages, and creates a GitHub
   Release with an `oasdiff`-derived changelog.

## Consuming the package

Add the ELifeRPG GitHub Packages NuGet source (requires a PAT with `read:packages`) and reference
`ELifeRPG.BackendApiClient` like any other NuGet package:

```sh
dotnet nuget add source https://nuget.pkg.github.com/ELifeRPG/index.json \
  --name eliferpg-github \
  --username <your-github-username> \
  --password <PAT-with-read:packages> \
  --store-password-in-clear-text

dotnet add package ELifeRPG.BackendApiClient
```
