#!/usr/bin/env bash
# Idempotently create the HCP Terraform Stack bound to this repo's root.
#
# One repo == one stack, so there is no app-detection step and no working-directory
# to get wrong. Once the stack exists, every merge to the tracked branch fetches a
# new stack configuration and plans each deployment; applies wait for a human.
#
# Requires: TFE_TOKEN TFC_ORG TFC_PROJECT_ID OAUTH_TOKEN_ID STACK_NAME REPO BRANCH
set -euo pipefail

: "${TFE_TOKEN:?}" "${TFC_ORG:?}" "${TFC_PROJECT_ID:?}" "${OAUTH_TOKEN_ID:?}"
: "${STACK_NAME:?}" "${REPO:?}" "${BRANCH:?}"

API="https://app.terraform.io/api/v2"
hdr=(-H "Authorization: Bearer ${TFE_TOKEN}" -H "Content-Type: application/vnd.api+json")

# GET /projects/{id}/stacks does NOT exist — verified live, it 404s. The real list
# route is org-scoped, and its project filter is not dependable, so match on both
# name and project id client-side. Never treat a non-empty list as "mine".
resp="$(curl -sS --fail-with-body "${hdr[@]}" "${API}/organizations/${TFC_ORG}/stacks")"
existing="$(printf '%s' "$resp" | STACK_NAME="$STACK_NAME" TFC_PROJECT_ID="$TFC_PROJECT_ID" python3 -c '
import json, os, sys
want_name, want_proj = os.environ["STACK_NAME"], os.environ["TFC_PROJECT_ID"]
for s in json.load(sys.stdin).get("data", []):
    proj = s.get("relationships", {}).get("project", {}).get("data", {}).get("id")
    if s["attributes"].get("name") == want_name and proj == want_proj:
        print(s["id"])
        break
')"

if [ -n "$existing" ]; then
  echo "stack '${STACK_NAME}' already exists in ${TFC_PROJECT_ID}: ${existing}"
  exit 0
fi

created="$(curl -sS --fail-with-body "${hdr[@]}" -X POST "${API}/stacks" -d @- <<JSON
{
  "data": {
    "type": "stacks",
    "attributes": {
      "name": "${STACK_NAME}",
      "vcs-repo": {
        "identifier": "${REPO}",
        "oauth-token-id": "${OAUTH_TOKEN_ID}",
        "branch": "${BRANCH}"
      }
    },
    "relationships": {
      "project": { "data": { "type": "projects", "id": "${TFC_PROJECT_ID}" } }
    }
  }
}
JSON
)"

id="$(printf '%s' "$created" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("data",{}).get("id",""))')"
if [ -z "$id" ]; then
  echo "stack creation returned no id — raw response follows:" >&2
  printf '%s\n' "$created" >&2
  exit 1
fi
echo "stack '${STACK_NAME}' created: ${id}"
