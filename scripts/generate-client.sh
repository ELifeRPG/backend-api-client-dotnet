#!/usr/bin/env bash
# Regenerates src/ELifeRPG.BackendApiClient/Generated (the Kiota client for the Central API)
# from a local copy of the OpenAPI spec. Unlike eliferpg-reforger-bridge's version of this
# script, this one never talks to a live Central API instance itself — the spec is always a
# local file, fetched by whatever invokes this script (see .github/workflows/release.yml for the
# automated path, which pulls openapi/eliferpg-api-v1.json from eliferpg-core).

set -euo pipefail
cd "$(dirname "$0")/.."

openapi_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --openapi)
      openapi_path="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$openapi_path" ]]; then
  echo "Usage: $0 --openapi <path-to-openapi-spec.json>" >&2
  exit 1
fi

if [[ ! -f "$openapi_path" ]]; then
  echo "OpenAPI spec not found at ${openapi_path}" >&2
  exit 1
fi

echo "Generating client from ${openapi_path} ..."
dotnet kiota generate \
  --openapi "${openapi_path}" \
  --language CSharp \
  --class-name EliferpgApiClient \
  --namespace-name ELifeRPG.BackendApiClient \
  --output src/ELifeRPG.BackendApiClient/Generated \
  --clean-output

rm -f src/ELifeRPG.BackendApiClient/Generated/.kiota.log

echo "Done. Review the diff in src/ELifeRPG.BackendApiClient/Generated/ before committing."
