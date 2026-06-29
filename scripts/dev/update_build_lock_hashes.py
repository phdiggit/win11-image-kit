#!/usr/bin/env python3
"""Update selected hash entries in manifests/build-lock.json.

The helper is intentionally narrow: it only updates existing entries selected by
explicit paths or by a validator report, and dry-run is the default.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


HASH_PATTERN = re.compile(r'("hash":\s*")[A-Fa-f0-9]{64}(")')


def repo_relative_path(repo_root: Path, value: str) -> str:
    candidate = Path(value)
    if candidate.is_absolute():
        candidate = candidate.resolve()
        try:
            candidate = candidate.relative_to(repo_root)
        except ValueError as exc:
            raise ValueError(f"path is outside repo root: {value}") from exc

    return candidate.as_posix().lstrip("./")


def collect_report_paths(report_path: Path) -> list[str]:
    report = json.loads(report_path.read_text(encoding="utf-8-sig"))
    paths: list[str] = []
    for entry in report.get("entries", []):
        if entry.get("status") != "failed":
            continue
        if not entry.get("exists", False):
            continue
        path = entry.get("path")
        if isinstance(path, str) and path:
            paths.append(path)
    return paths


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def replace_entry_hash(text: str, path: str, new_hash: str) -> str:
    path_token = '"path": ' + json.dumps(path, ensure_ascii=False)
    path_index = text.find(path_token)
    if path_index < 0:
        raise ValueError(f"entry not found while writing: {path}")

    block_start = text.rfind("    {", 0, path_index)
    block_end = text.find("    }", path_index)
    if block_start < 0 or block_end < 0:
        raise ValueError(f"could not locate entry block: {path}")

    block_end += len("    }")
    block = text[block_start:block_end]
    replaced, count = HASH_PATTERN.subn(rf"\g<1>{new_hash}\2", block, count=1)
    if count != 1:
        raise ValueError(f"could not locate hash field: {path}")

    return text[:block_start] + replaced + text[block_end:]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Dry-run or update selected manifests/build-lock.json hash entries."
    )
    parser.add_argument("--lock", default="manifests/build-lock.json")
    parser.add_argument("--repo-root", default=None)
    parser.add_argument("--paths", nargs="*", default=[])
    parser.add_argument("--from-report", default=None)
    parser.add_argument("--write", action="store_true", help="write selected hash updates")
    parser.add_argument("--dry-run", action="store_true", help="print selected updates only")
    parser.add_argument("--allow-many", action="store_true", help="allow more than --max-updates")
    parser.add_argument("--max-updates", type=int, default=25)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.write and args.dry_run:
        print("--write and --dry-run cannot be combined", file=sys.stderr)
        return 2

    repo_root = Path(args.repo_root).resolve() if args.repo_root else Path(__file__).resolve().parents[2]
    lock_path = (repo_root / args.lock).resolve()
    if not lock_path.exists():
        print(f"Build Lock manifest not found: {lock_path}", file=sys.stderr)
        return 2

    selected = list(args.paths)
    if args.from_report:
        selected.extend(collect_report_paths((repo_root / args.from_report).resolve()))

    normalized: list[str] = []
    seen: set[str] = set()
    for item in selected:
        try:
            relative = repo_relative_path(repo_root, item)
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 2
        if relative not in seen:
            seen.add(relative)
            normalized.append(relative)

    if not normalized:
        print("No paths selected. Use --paths or --from-report.", file=sys.stderr)
        return 2

    lock_text = lock_path.read_text(encoding="utf-8-sig")
    lock_json = json.loads(lock_text)
    entries = {entry["path"]: entry for entry in lock_json.get("entries", [])}

    updates: list[tuple[str, str, str]] = []
    skipped: list[tuple[str, str]] = []
    for relative in normalized:
        entry = entries.get(relative)
        if entry is None:
            skipped.append((relative, "not in Build Lock entries"))
            continue

        target_path = repo_root / relative
        if not target_path.exists():
            skipped.append((relative, "file missing"))
            continue

        actual_hash = sha256_file(target_path)
        current_hash = str(entry.get("hash", "")).lower()
        if actual_hash == current_hash:
            skipped.append((relative, "hash already current"))
            continue
        updates.append((relative, current_hash, actual_hash))

    if len(updates) > args.max_updates and not args.allow_many:
        print(
            f"{len(updates)} updates selected; rerun with --allow-many for a dedicated normalization pass.",
            file=sys.stderr,
        )
        return 2

    mode = "write" if args.write else "dry-run"
    print(f"Build Lock hash update mode: {mode}")
    print(f"selected={len(normalized)} update={len(updates)} skipped={len(skipped)}")

    for relative, old_hash, new_hash in updates:
        print(f"UPDATE {relative} {old_hash} -> {new_hash}")
    for relative, reason in skipped:
        print(f"SKIP {relative} ({reason})")

    if args.write and updates:
        updated_text = lock_text
        for relative, _old_hash, new_hash in updates:
            updated_text = replace_entry_hash(updated_text, relative, new_hash)
        lock_path.write_text(updated_text, encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
