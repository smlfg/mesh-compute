#!/usr/bin/env bash
set -euo pipefail

MESH_COMPUTE_URL="${MESH_COMPUTE_URL:-http://samuel-mbp:11434/v1}"
MODEL="${MODEL:-mistral:latest}"
BASE_URL="${MESH_COMPUTE_URL%/}"
CHAT_URL="${BASE_URL}/chat/completions"

echo "smoke test: tool_calls via ${CHAT_URL}"
echo "model: ${MODEL}"
echo ""

PAYLOAD="$(cat <<EOF
{
  "model": "${MODEL}",
  "messages": [
    {
      "role": "user",
      "content": "What time is it? Use the get_time tool."
    }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_time",
        "description": "Return the current local time as an ISO-8601 string.",
        "parameters": {
          "type": "object",
          "properties": {},
          "required": []
        }
      }
    }
  ],
  "tool_choice": "auto"
}
EOF
)"

if ! RESPONSE="$(curl -fsS --connect-timeout 15 --max-time 120 \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" \
  "${CHAT_URL}")"; then
  echo "error: chat/completions request failed" >&2
  exit 1
fi

RESULT="$(echo "${RESPONSE}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
choice = (data.get('choices') or [{}])[0]
message = choice.get('message') or {}
tool_calls = message.get('tool_calls') or []
has_tools = len(tool_calls) > 0
print('HAS_TOOL_CALLS=' + ('yes' if has_tools else 'no'))
print('TOOL_CALL_COUNT=' + str(len(tool_calls)))
if tool_calls:
    for i, tc in enumerate(tool_calls):
        fn = (tc.get('function') or {})
        print(f'TOOL_{i}_NAME=' + str(fn.get('name', '')))
content = message.get('content')
if content:
    preview = str(content).replace(chr(10), ' ')[:200]
    print('CONTENT_PREVIEW=' + preview)
")"

echo "${RESULT}"
echo ""

if echo "${RESULT}" | grep -q '^HAS_TOOL_CALLS=yes'; then
  echo "pass: model emitted tool_calls (verified for Hermes fallback compatibility)"
  exit 0
fi

echo "fail: no tool_calls in response — this model may not be suitable as primary fallback." >&2
echo "hint: mistral:latest is known to work; qwen3:8b / qwen2.5-coder:7b advertise tools but often omit tool_calls." >&2
echo "raw response:" >&2
echo "${RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${RESPONSE}" >&2
exit 1
