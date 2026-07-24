#!/usr/bin/env python3
"""Run a privacy-preserving live audit of the icloud-cli command surface.

The script executes each command against the current Mac and prints only status,
exit code, shape/count, and short error messages. It intentionally does not
print command payloads because many commands touch local private metadata.
"""

from __future__ import annotations

import argparse
from collections import Counter
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


def command_catalog(cache_dir: str, tag: str) -> list[tuple[str, list[str]]]:
    return [
        ("snapshot", ["snapshot", "--format", "json"]),
        ("account status", ["account", "status", "--format", "json"]),
        ("backup status", ["backup", "status", "--format", "json"]),
        ("family status", ["family", "status", "--format", "json"]),
        ("storage status", ["storage", "status", "--format", "json"]),
        ("focus status", ["focus", "status", "--format", "json"]),
        ("devices list", ["devices", "list", "--format", "json"]),
        ("wallet passes", ["wallet", "passes", "--format", "json"]),
        ("handoff list", ["handoff", "list", "--limit", "10", "--format", "json"]),
        ("drive list", ["drive", "list", "--depth", "1", "--scan-limit", "2000", "--timeout-ms", "10000", "--format", "json"]),
        ("drive containers", ["drive", "containers", "--sort-by", "name", "--format", "json"]),
        ("drive status", ["drive", "status", "--scan-limit", "2000", "--timeout-ms", "10000", "--format", "json"]),
        ("drive errors", ["drive", "errors", "--limit", "25", "--scan-limit", "2000", "--timeout-ms", "10000", "--format", "json"]),
        ("drive shared", ["drive", "shared", "--limit", "25", "--scan-limit", "2000", "--timeout-ms", "10000", "--format", "json"]),
        ("drive recents", ["drive", "recents", "--limit", "25", "--scan-limit", "2000", "--timeout-ms", "10000", "--format", "json"]),
        ("shortcuts list", ["shortcuts", "list", "--format", "json"]),
        ("photos screenshots", ["photos", "screenshots", "--format", "json"]),
        ("photos list", ["photos", "list", "--limit", "25", "--format", "json"]),
        ("photos shared-albums", ["photos", "shared-albums", "--format", "json"]),
        ("photos shared-library", ["photos", "shared-library", "--format", "json"]),
        ("notes list", ["notes", "list", "--format", "json"]),
        ("notes accounts", ["notes", "accounts", "--format", "json"]),
        ("notes folders", ["notes", "folders", "--format", "json"]),
        ("notes tags", ["notes", "tags", "--format", "json"]),
        ("notes shared", ["notes", "shared", "--format", "json"]),
        ("reminders lists", ["reminders", "lists", "--format", "json"]),
        ("reminders list", ["reminders", "list", "--format", "json"]),
        ("reminders flagged", ["reminders", "flagged", "--limit", "25", "--format", "json"]),
        ("reminders today", ["reminders", "today", "--limit", "25", "--format", "json"]),
        ("reminders scheduled", ["reminders", "scheduled", "--limit", "25", "--format", "json"]),
        ("reminders assigned", ["reminders", "assigned", "--limit", "25", "--format", "json"]),
        ("calendar accounts", ["calendar", "accounts", "--format", "json"]),
        ("calendar list", ["calendar", "list", "--format", "json"]),
        ("calendar events", ["calendar", "events", "--limit", "25", "--format", "json"]),
        ("contacts list", ["contacts", "list", "--limit", "25", "--format", "json"]),
        ("findmy devices", ["findmy", "devices", "--format", "json"]),
        ("findmy people", ["findmy", "people", "--format", "json"]),
        ("mail accounts", ["mail", "accounts", "--format", "json"]),
        ("mail mailboxes", ["mail", "mailboxes", "--format", "json"]),
        ("mail recent", ["mail", "recent", "--confirm-sensitive", "--limit", "10", "--format", "json"]),
        ("messages conversations", ["messages", "conversations", "--limit", "25", "--format", "json"]),
        ("messages recent", ["messages", "recent", "--confirm-sensitive", "--limit", "10", "--format", "json"]),
        ("maps favorites", ["maps", "favorites", "--format", "json"]),
        ("maps recents", ["maps", "recents", "--limit", "25", "--format", "json"]),
        ("news history", ["news", "history", "--limit", "25", "--format", "json"]),
        ("news topics", ["news", "topics", "--format", "json"]),
        ("books collections", ["books", "collections", "--format", "json"]),
        ("books list", ["books", "list", "--limit", "25", "--format", "json"]),
        ("voice-memos list", ["voice-memos", "list", "--limit", "25", "--format", "json"]),
        ("home homes", ["home", "homes", "--format", "json"]),
        ("home rooms", ["home", "rooms", "--format", "json"]),
        ("home accessories", ["home", "accessories", "--format", "json"]),
        ("home scenes", ["home", "scenes", "--format", "json"]),
        ("health summary", ["health", "summary", "--confirm-sensitive", "--format", "json"]),
        ("freeform list", ["freeform", "list", "--limit", "25", "--format", "json"]),
        ("music status", ["music", "status", "--format", "json"]),
        ("music playlists", ["music", "playlists", "--limit", "25", "--format", "json"]),
        ("music tracks", ["music", "tracks", "--limit", "25", "--format", "json"]),
        ("stocks watchlist", ["stocks", "watchlist", "--format", "json"]),
        ("stocks groups", ["stocks", "groups", "--format", "json"]),
        ("weather favorites", ["weather", "favorites", "--format", "json"]),
        ("tags list", ["tags", "list", "--format", "json"]),
        ("tags items", ["tags", "items", "--tag", tag, "--limit", "25", "--scan-limit", "2000", "--timeout-ms", "10000", "--format", "json"]),
        ("permissions doctor", ["permissions", "doctor", "--format", "json"]),
        ("safari tabs", ["safari", "tabs", "--source", "all", "--format", "json"]),
        ("safari history", ["safari", "history", "--confirm-sensitive", "--limit", "10", "--redact-urls", "--format", "json"]),
        ("safari bookmarks", ["safari", "bookmarks", "--format", "json"]),
        ("safari reading-list", ["safari", "reading-list", "--format", "json"]),
        ("safari frequently-visited", ["safari", "frequently-visited", "--limit", "10", "--format", "json"]),
        ("safari cloud-tabs probe", ["safari", "cloud-tabs", "probe", "--format", "json"]),
        ("safari cloud-tabs list", ["safari", "cloud-tabs", "list", "--confirm-sensitive", "--format", "json"]),
        ("safari profiles list", ["safari", "profiles", "list", "--format", "json"]),
        ("safari extensions list", ["safari", "extensions", "list", "--format", "json"]),
        ("cache status", ["cache", "status", "--format", "json", "--output-dir", cache_dir]),
        ("watch once", ["watch", "--once", "--scan-limit", "2000", "--timeout-ms", "10000", "--output-dir", cache_dir]),
        ("cache read drive-list", ["cache", "read", "drive-list", "--format", "json", "--output-dir", cache_dir]),
    ]


def payload_shape(payload: Any) -> tuple[int, str, str]:
    if isinstance(payload, list):
        return len(payload), "array", ""
    if isinstance(payload, dict):
        if payload.get("schemaVersion") == "icloud-cli.crawl.v1" and "data" in payload:
            count, shape, _ = payload_shape(payload["data"])
            return count, f"crawl:{shape}", scalar_note(payload)
        for key in (
            "items",
            "files",
            "containers",
            "passes",
            "activities",
            "photos",
            "screenshots",
            "notes",
            "reminders",
            "contacts",
            "conversations",
            "messages",
            "favorites",
            "recents",
            "history",
            "topics",
            "collections",
            "books",
            "recordings",
            "homes",
            "rooms",
            "accessories",
            "scenes",
            "boards",
            "playlists",
            "tracks",
            "watchlist",
            "groups",
            "locations",
            "tags",
            "devices",
            "people",
            "accounts",
            "mailboxes",
            "events",
            "calendars",
            "errors",
            "sharedItems",
        ):
            value = payload.get(key)
            if isinstance(value, list):
                return len(value), f"{key}[]", scalar_note(payload)
        return len(payload), "object-keys", scalar_note(payload)
    return 0, type(payload).__name__, ""


def scalar_note(payload: dict[str, Any]) -> str:
    for key in ("status", "state", "message", "error", "signedIn", "available", "readable"):
        value = payload.get(key)
        if value is not None and not isinstance(value, (list, dict)):
            return f"{key}={value}"[:120]
    return ""


def classify(exe: Path, args: list[str], timeout: int) -> tuple[str, str, int, str, str]:
    try:
        process = subprocess.run(
            [str(exe), *args],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        stderr = error.stderr if isinstance(error.stderr, str) else ""
        return "TIMEOUT", "-", 0, "-", stderr.replace("\n", " ")[:220]

    stdout = process.stdout.strip()
    stderr = process.stderr.strip()
    if process.returncode != 0:
        return "FAIL", str(process.returncode), 0, "-", (stderr or stdout).replace("\n", " ")[:220]
    if not stdout:
        return "EMPTY", "0", 0, "-", "no stdout"

    try:
        payload = json.loads(stdout)
        count, shape, note = payload_shape(payload)
        if isinstance(payload, dict) and payload.get("state") == "timeout":
            return "TIMEOUT", "0", count, shape, note
        status = "OK_DATA" if count > 0 else "OK_EMPTY"
        return status, "0", count, shape, note
    except json.JSONDecodeError:
        return "OK_TEXT", "0", len(stdout), "text", stdout.replace("\n", " ")[:220]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", default=".build/debug/icloud-cli", help="Path to the icloud-cli binary")
    parser.add_argument("--timeout", type=int, default=18, help="Per-command timeout in seconds")
    parser.add_argument("--tag", default="Red", help="Finder tag name to use for the tags items probe")
    args = parser.parse_args()

    exe = Path(args.binary).expanduser().resolve()
    if not exe.exists():
        print(f"error: binary not found: {exe}", file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix="icloud-cli-live-cache-") as cache_dir:
        totals: Counter[str] = Counter()
        print("command\tstatus\texit\tcount\tshape\tnote")
        for name, command_args in command_catalog(cache_dir, args.tag):
            status, exit_code, count, shape, note = classify(exe, command_args, args.timeout)
            print(f"{name}\t{status}\t{exit_code}\t{count}\t{shape}\t{note}")
            if status == "TIMEOUT":
                totals["timeout"] += 1
            elif status == "FAIL":
                totals["fail"] += 1
            elif status in {"EMPTY", "OK_EMPTY"}:
                totals["empty"] += 1
            else:
                totals["pass"] += 1
        print(
            "summary\t"
            f"pass={totals['pass']}\tempty={totals['empty']}\t"
            f"fail={totals['fail']}\ttimeout={totals['timeout']}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
