#!/usr/bin/env python3
"""Executable positive and regression controls for the immutable native lane."""
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

class NativePolicy(unittest.TestCase):
    def check(self, caller_change=None, callee_change=None):
        with tempfile.TemporaryDirectory() as directory:
            caller = (ROOT / ".github/workflows/pr-fast-ci.yml").read_text()
            callee = (ROOT / ".github/workflows/native-trusted.yml").read_text()
            if caller_change:
                self.assertIn(caller_change[0], caller)
                caller = caller.replace(*caller_change)
            if callee_change:
                self.assertIn(callee_change[0], callee)
                callee = callee.replace(*callee_change)
            a, b = pathlib.Path(directory)/"caller.yml", pathlib.Path(directory)/"callee.yml"
            a.write_text(caller); b.write_text(callee)
            return subprocess.run(["bash", "scripts/ci/check-ci-policy.sh", "scripts/ci/run-fast-checks.sh", str(a), str(b)], cwd=ROOT, capture_output=True).returncode

    def test_positive(self):
        self.assertEqual(self.check(), 0)

    def test_complete_callee_contract(self):
        # C7 used to pass: required substrings remain even when PR events are added.
        mutations = [
            ("github.event_name == 'push' || github.event_name == 'workflow_dispatch'",
             "github.event_name == 'push' || github.event_name == 'workflow_dispatch' || github.event_name == 'pull_request'"),
            ("github.repository == 'OMT-Global/icloud-cli' &&",
             "true || github.repository == 'OMT-Global/icloud-cli' &&"),
            ("    if: >-", "    if: true # >-"),
            ("      - name: Verify Xcode", "      - run: echo unexpected-step\n      - name: Verify Xcode"),
        ]
        for before, after in mutations:
            with self.subTest(mutation=after):
                self.assertNotEqual(self.check(callee_change=(before, after)), 0)

    def test_regressions(self):
        for before, after in [
            ("github.repository == 'OMT-Global/icloud-cli'", "true"),
            ("github.ref == 'refs/heads/main'", "true"),
            ("group: macos-public-trusted", "group: macos-private"),
            ("persist-credentials: false", "persist-credentials: true"),
            ("0d498ddd01bade25de87a09364337a080cc85261", "untrusted-branch"),
            ("bash scripts/ci/run-fast-checks.sh", "echo skipped"),
            ("  workflow_call:", "  workflow_call:\n    inputs:"),
        ]:
            with self.subTest(before=before):
                self.assertNotEqual(self.check(callee_change=(before, after)), 0)
        self.assertNotEqual(self.check(caller_change=("      - macos-15", "      - self-hosted")), 0)
        self.assertNotEqual(self.check(caller_change=("@8ceaef64cbdd26396d5bd042daa890b27b6b8d2f", "@main")), 0)

if __name__ == "__main__":
    unittest.main()
