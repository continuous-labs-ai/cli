#!/usr/bin/env bash
# Posts a failed or cancelled run to Slack: the repository, the workflow, the
# commit, and each failed or cancelled job with its failed steps.
#
#   SLACK_ALERTS_WEBHOOK_URL=<url> GH_TOKEN=<token> slack-alert.sh
set -euo pipefail

if [[ -z ${SLACK_ALERTS_WEBHOOK_URL:-} ]]; then
  echo '::error::SLACK_ALERTS_WEBHOOK_URL is not set'
  exit 1
fi

repo_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY"

jobs=$(gh api --paginate "repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/jobs" \
  --jq '.jobs[] | select(.conclusion == "failure" or .conclusion == "cancelled") |
    {name, conclusion, steps: [.steps[]? | select(.conclusion == "failure") | .name]}') || jobs=''

text=$(jq -rs \
  --arg repo "$GITHUB_REPOSITORY" \
  --arg workflow "$GITHUB_WORKFLOW" \
  --arg event "$GITHUB_EVENT_NAME" \
  --arg sha "${GITHUB_SHA:0:7}" \
  --arg commit_url "$repo_url/commit/$GITHUB_SHA" \
  --arg run_url "$repo_url/actions/runs/$GITHUB_RUN_ID" '
  def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
  def steps: if .steps == [] then "" else " — failed step: " + (.steps | map(esc) | join(", ")) end;
  (if any(.[]; .conclusion == "failure") then "failed"
   elif length > 0 then "was cancelled"
   else "failed or was cancelled" end) as $outcome |
  [":red_circle: *\($repo | esc) · \($workflow | esc) \($outcome)*",
   "Commit <\($commit_url)|\($sha)> · \($event) run"]
  + (if length == 0 then ["No failed job was reported; see the run."]
     else map("• *\(.name | esc)*" + (if .conclusion == "cancelled" then " — cancelled" else steps end)) end)
  + ["<\($run_url)|Workflow run>"]
  | join("\n")
' <<<"$jobs")

jq -n --arg text "$text" '{text: $text}' |
  curl --fail-with-body --silent --show-error --retry 3 \
    -H 'Content-Type: application/json' --data @- "$SLACK_ALERTS_WEBHOOK_URL"
