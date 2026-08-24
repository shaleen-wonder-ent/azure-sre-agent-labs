#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCE_GROUP="${RESOURCE_GROUP:-$(azd env get-value RESOURCE_GROUP_NAME 2>/dev/null || true)}"

if [[ -z "$RESOURCE_GROUP" ]]; then
  echo "ERROR: RESOURCE_GROUP_NAME is not available in the current azd environment."
  exit 1
fi

AGENT_NAME=$(az resource list --resource-group "$RESOURCE_GROUP" \
  --resource-type Microsoft.App/agents --query "[0].name" -o tsv)
AGENT_ENDPOINT=$(az resource show --resource-group "$RESOURCE_GROUP" \
  --resource-type Microsoft.App/agents --name "$AGENT_NAME" \
  --query properties.agentEndpoint -o tsv)

if [[ -z "$AGENT_ENDPOINT" ]]; then
  echo "ERROR: Azure SRE Agent endpoint was not found in $RESOURCE_GROUP."
  exit 1
fi

TOKEN=$(az account get-access-token --resource https://azuresre.dev \
  --query accessToken -o tsv)
SKILL_FILE="$LAB_DIR/skills/vm-availability-reporting/SKILL.md"
RULES_FILE="$LAB_DIR/docs/slo-and-availability-rules.md"
FIXTURE_FILE="$LAB_DIR/docs/vm-availability-30d-fixture.json"

if command -v cygpath &>/dev/null; then
  SKILL_FILE=$(cygpath -w "$SKILL_FILE")
  RULES_FILE=$(cygpath -w "$RULES_FILE")
  FIXTURE_FILE=$(cygpath -w "$FIXTURE_FILE")
fi

HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" \
  -X POST "$AGENT_ENDPOINT/api/v1/AgentMemory/upload" \
  -H "Authorization: Bearer $TOKEN" \
  -F "triggerIndexing=true" \
  -F "files=@$RULES_FILE;type=text/markdown" \
  -F "files=@$FIXTURE_FILE;type=application/json")

if [[ ! "$HTTP_CODE" =~ ^20[0-4]$ ]]; then
  echo "ERROR: Knowledge upload returned HTTP $HTTP_CODE."
  exit 1
fi

SKILL_BODY=$(python -c "import json, pathlib; content=pathlib.Path(r'$SKILL_FILE').read_text(); print(json.dumps({'name':'vm-availability-reporting','type':'Skill','properties':{'description':'Produces transparent read-only VM availability reports from observed Azure evidence or a labeled workshop fixture','tools':['SearchMemory','GetAzCliHelp','RunAzCliReadCommands'],'skillContent':content,'additionalFiles':[]}}))")
HTTP_CODE=$(printf '%s' "$SKILL_BODY" | curl -sS -o /dev/null -w "%{http_code}" \
  -X PUT "$AGENT_ENDPOINT/api/v2/extendedAgent/skills/vm-availability-reporting" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @-)

if [[ ! "$HTTP_CODE" =~ ^20[0-4]$ ]]; then
  echo "ERROR: Skill registration returned HTTP $HTTP_CODE."
  exit 1
fi

echo "Availability demo configured on $AGENT_NAME."
echo "Fixture: 2026-07-25T00:00:00Z through 2026-08-24T00:00:00Z"
echo "Use the vm-availability-reporting skill and explicitly request the prepared synthetic fixture."