#!/usr/bin/env python3
"""Exercise actual sync step scripts with isolated git/gh commands; no network calls."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = (
    "reusable-node-web.yml",
    "reusable-node-mobile.yml",
    "reusable-java-backend.yml",
    "reusable-api-contracts.yml",
)

MOCK_GH = """import json, os, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as log:
    log.write(json.dumps(args) + '\\n')
if args[:2] == ['pr', 'list']:
    if os.environ['CASE'] == 'pr-list-failure':
        sys.exit(1)
    print(os.environ['EXISTING'])
elif args[:2] == ['label', 'list']:
    if os.environ['CASE'] == 'label-list-failure':
        sys.exit(1)
    print(os.environ['LABELS'])
elif args[:2] == ['pr', 'create']:
    if os.environ['CASE'] == 'create-failure':
        sys.exit(1)
else:
    sys.exit(2)
"""


def read_step(workflow):
    source = (ROOT / '.github/workflows' / workflow).read_text()
    marker = ('      - name: Create PR (when there are content changes)' if
              workflow == 'reusable-api-contracts.yml' else
              '      - name: Create sync PR (if there are content changes)')
    section = source.split(marker, 1)[1].split('        run: |\n', 1)[1]
    lines = []
    for line in section.splitlines():
        if line.strip() and not line.startswith('          '):
            break
        lines.append(line[10:])
    script = '\n'.join(lines) + '\n'
    script = script.replace('${{ steps.merge.outputs.branch }}', 'sync-release-1.0.0')
    script = script.replace('${{ steps.version.outputs.value }}', '1.0.0')
    if '${{' in script:
        raise AssertionError('Unresolved Actions expression in isolated test')
    return script


class SyncLabelsTest(unittest.TestCase):
    def test_sync_label_and_pr_scenarios(self):
        cases = (
            ('both', 'chore\nsync', '', ['chore', 'sync'], True),
            ('none', 'bug\nchore-extra\nsync-extra', '', [], True),
            ('partial', 'sync', '', ['sync'], True),
            ('label-list-failure', '', '', [], True),
            ('existing', '', '12', None, True),
            ('create-failure', '', '', [], False),
            ('pr-list-failure', '', '', None, False),
        )
        for workflow in WORKFLOWS:
            for name, labels, existing, expected, success in cases:
                with self.subTest(workflow=workflow, scenario=name):
                    with tempfile.TemporaryDirectory(prefix='wendara-sync-test-') as directory:
                        root = Path(directory)
                        script = root / 'sync.sh'
                        script.write_text(read_step(workflow))
                        subprocess.run(['bash', '-n', str(script)], check=True)
                        git = root / 'git'
                        git.write_text('#!/bin/sh\nexit 0\n')
                        git.chmod(0o755)
                        gh = root / 'gh'
                        gh.write_text('#!' + sys.executable + '\n' + MOCK_GH)
                        gh.chmod(0o755)
                        log = root / 'calls.jsonl'
                        env = {**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH'],
                               'GH_TOKEN': 'isolated-test-token', 'CASE': name, 'LABELS': labels,
                               'EXISTING': existing, 'CALLS': str(log)}
                        result = subprocess.run(['bash', str(script)], env=env, capture_output=True, text=True)
                        self.assertEqual(result.returncode == 0, success, result.stderr)
                        calls = [json.loads(line) for line in log.read_text().splitlines()]
                        creates = [args for args in calls if args[:2] == ['pr', 'create']]
                        if expected is None:
                            self.assertEqual(creates, [])
                            if name == 'existing':
                                self.assertFalse(any(args[:2] == ['label', 'list'] for args in calls))
                        else:
                            self.assertEqual(len(creates), 1)
                            args = creates[0]
                            actual = [args[index + 1] for index, arg in enumerate(args) if arg == '--label']
                            self.assertEqual(actual, expected)
                            self.assertEqual(args[args.index('--base') + 1], 'develop')
                            head = ('chore/sync-main-into-develop' if workflow == 'reusable-api-contracts.yml'
                                    else 'sync-release-1.0.0')
                            self.assertEqual(args[args.index('--head') + 1], head)
                            self.assertTrue(args[args.index('--title') + 1])
                            self.assertIn('main', args[args.index('--body') + 1])


if __name__ == '__main__':
    unittest.main(verbosity=2)
