#!/bin/bash
set -euo pipefail

TASK_NAME="${1:-integrationTest}"

echo "🔎 Summarizing failed ${TASK_NAME} test reports..."

REPORTS=()
while IFS= read -r report_path; do
  REPORTS+=("${report_path}")
done < <(find . -type f -path "*/build/test-results/${TASK_NAME}/TEST-*.xml" | sort)

if [ "${#REPORTS[@]}" -eq 0 ]; then
  echo "⚠️ No JUnit XML reports found for ${TASK_NAME}."
  exit 0
fi

python3 - "${TASK_NAME}" "${REPORTS[@]}" <<'PY'
import re
import os
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

task_name = sys.argv[1]
report_paths = sys.argv[2:]
summary_path = Path(sys.argv[3]) if len(sys.argv) > 3 else Path(os.environ["GITHUB_STEP_SUMMARY"]) if os.environ.get("GITHUB_STEP_SUMMARY") else None

file_line_pattern = re.compile(r'([A-Za-z0-9_./$-]+\.java):(\d+)')
failures = []

for report_path in report_paths:
    try:
        root = ET.parse(report_path).getroot()
    except ET.ParseError as exc:
        print(f"⚠️ Could not parse {report_path}: {exc}")
        continue

    for testcase in root.iter("testcase"):
        node = testcase.find("failure")
        node_kind = "failure"
        if node is None:
            node = testcase.find("error")
            node_kind = "error"
        if node is None:
            continue

        text = (node.text or "").strip()
        message = node.attrib.get("message", "").strip()
        summary = message or (text.splitlines()[0].strip() if text else f"{node_kind} without message")
        location = None
        match = file_line_pattern.search(text)
        if match:
            location = f"{match.group(1)}:{match.group(2)}"

        failures.append(
            {
                "classname": testcase.attrib.get("classname", "<unknown>"),
                "name": testcase.attrib.get("name", "<unknown>"),
                "location": location,
                "summary": summary,
                "report_path": report_path,
            }
        )

if not failures:
    print(f"✅ No failed {task_name} test cases found in the XML reports.")
    sys.exit(0)

print(f"❌ Found {len(failures)} failed {task_name} test case(s).")
markdown_lines = [
    f"## {task_name} failures",
    "",
    f"Found {len(failures)} failed test case(s).",
    "",
    "| Test | Reason |",
    "| --- | --- |",
]
for failure in failures[:10]:
    location = f" [{failure['location']}]" if failure["location"] else ""
    print(f"- {failure['classname']}#{failure['name']}{location}")
    print(f"  {failure['summary']}")
    print(f"  Report: {failure['report_path']}")
    summary_reason = failure["summary"].replace("|", "\\|")
    summary_test = f"{failure['classname']}#{failure['name']}"
    if failure["location"]:
        summary_test = f"{summary_test} ({failure['location']})"
    markdown_lines.append(f"| `{summary_test}` | {summary_reason} |")

remaining = len(failures) - 10
if remaining > 0:
    print(f"... and {remaining} more failed test case(s).")
    markdown_lines.append(f"| _{remaining} more..._ | _See the artifact for the full list_ |")

markdown_lines.extend(
    [
        "",
        f"Artifact: `integration-test-reports`",
        "",
        "Open the uploaded artifact to inspect the full XML and HTML reports.",
    ]
)

if summary_path is not None:
    summary_path.write_text("\n".join(markdown_lines) + "\n", encoding="utf-8")
PY
