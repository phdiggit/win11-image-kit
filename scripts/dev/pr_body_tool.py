from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TEMP_BODY_DIR = Path(".tmp/pr-bodies")
DAMAGED_FENCE_PATTERNS = (
    re.compile(r"^`\\[A-Za-z]", re.MULTILINE),
    re.compile(r"^`[A-Za-z][A-Za-z0-9_-]*\s*$", re.MULTILINE),
)


class PrBodyError(ValueError):
    pass


def repo_root() -> Path:
    return ROOT.resolve()


def body_root() -> Path:
    return (repo_root() / TEMP_BODY_DIR).resolve(strict=False)


def _is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def resolve_repo_path(path: str | Path, *, purpose: str = "path") -> Path:
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = repo_root() / candidate
    resolved = candidate.resolve(strict=False)
    if not _is_relative_to(resolved, repo_root()):
        raise PrBodyError(f"{purpose} must stay inside repository root: {path}")
    return resolved


def resolve_body_path(path: str | Path, *, purpose: str = "body file") -> Path:
    resolved = resolve_repo_path(path, purpose=purpose)
    if not _is_relative_to(resolved, body_root()):
        raise PrBodyError(f"{purpose} must be under {TEMP_BODY_DIR.as_posix()}/: {path}")
    return resolved


def default_normalized_path(input_path: str | Path) -> Path:
    source = Path(input_path)
    name = source.name if source.name else "pr-body.md"
    return resolve_body_path(TEMP_BODY_DIR / name, purpose="normalize output")


def canonical_text(text: str) -> str:
    return text.lstrip("\ufeff").replace("\r\n", "\n").replace("\r", "\n")


def read_repo_text(path: str | Path, *, purpose: str = "input file") -> str:
    target = resolve_repo_path(path, purpose=purpose)
    try:
        return canonical_text(target.read_text(encoding="utf-8-sig"))
    except UnicodeDecodeError as exc:
        raise PrBodyError(f"{purpose} is not valid UTF-8: {path}") from exc


def read_body_text(path: str | Path) -> str:
    target = resolve_body_path(path)
    try:
        return canonical_text(target.read_text(encoding="utf-8-sig"))
    except UnicodeDecodeError as exc:
        raise PrBodyError(f"body file is not valid UTF-8: {path}") from exc


def write_body_text(path: str | Path, text: str) -> Path:
    target = resolve_body_path(path, purpose="body output")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(canonical_text(text), encoding="utf-8", newline="\n")
    return target


def _format_char(char: str) -> str:
    return f"U+{ord(char):04X}"


def _find_control_chars(text: str) -> list[str]:
    return sorted(
        {
            _format_char(char)
            for char in text
            if (ord(char) < 32 and char not in {"\n", "\t"}) or ord(char) == 127
        }
    )


def _validate_code_fences(text: str) -> list[str]:
    errors: list[str] = []
    fence_lines = [
        (line_number, line.strip())
        for line_number, line in enumerate(text.splitlines(), start=1)
        if line.strip().startswith("```")
    ]

    if len(fence_lines) % 2 != 0:
        errors.append("triple-backtick code fences must be paired")

    for pair_index, (line_number, line) in enumerate(fence_lines):
        if pair_index % 2 == 1 and line != "```":
            errors.append(f"line {line_number}: closing code fence must be plain ```")

    return errors


def validate_text(text: str) -> list[str]:
    errors: list[str] = []
    canonical = canonical_text(text)
    controls = _find_control_chars(canonical)
    if controls:
        errors.append(f"control characters are not allowed: {', '.join(controls)}")
    if "\ufffd" in canonical:
        errors.append("Unicode replacement character U+FFFD is not allowed")
    if "???" in canonical:
        errors.append("obvious encoding anomaly ??? is not allowed")
    for pattern in DAMAGED_FENCE_PATTERNS:
        if pattern.search(canonical):
            errors.append("damaged Markdown code fence is not allowed")
            break
    errors.extend(_validate_code_fences(canonical))
    return errors


def validate_file(path: str | Path) -> None:
    errors = validate_text(read_body_text(path))
    if errors:
        raise PrBodyError("; ".join(errors))


def normalize_file(input_path: str | Path, output_path: str | Path | None = None) -> Path:
    text = read_repo_text(input_path, purpose="normalize input")
    errors = validate_text(text)
    if errors:
        raise PrBodyError("; ".join(errors))
    target = resolve_body_path(output_path, purpose="normalize output") if output_path else default_normalized_path(input_path)
    write_body_text(target, text)
    validate_file(target)
    return target


def compare_body_text(expected: str, actual: str) -> None:
    expected_text = canonical_text(expected)
    actual_text = canonical_text(actual)
    if expected_text != actual_text:
        raise PrBodyError(
            "GitHub PR body does not match the local UTF-8 body file; "
            "do not mark the PR ready until the body is repaired"
        )


def parse_draft_value(value: str | bool | None) -> bool | None:
    if value is None or isinstance(value, bool):
        return value
    normalized = value.strip().lower()
    if normalized in {"true", "1", "yes"}:
        return True
    if normalized in {"false", "0", "no"}:
        return False
    raise PrBodyError("--draft must be true or false")


def _assert_metadata(name: str, actual: object, expected: object | None) -> None:
    if expected is None:
        return
    if actual != expected:
        raise PrBodyError(f"GitHub PR {name} mismatch: expected {expected!r}, got {actual!r}")


def compare_pr_metadata(
    info: dict[str, object],
    *,
    title: str | None = None,
    base: str | None = None,
    head: str | None = None,
    draft: bool | None = None,
) -> None:
    _assert_metadata("title", info.get("title"), title)
    _assert_metadata("base", info.get("baseRefName"), base)
    _assert_metadata("head", info.get("headRefName"), head)
    _assert_metadata("draft", info.get("isDraft"), draft)


def ensure_gh_available() -> None:
    if shutil.which("gh") is None:
        raise PrBodyError("gh CLI is not available")


def run_gh(args: list[str], *, capture_json: bool = False) -> str:
    ensure_gh_available()
    completed = subprocess.run(
        ["gh", *args],
        cwd=repo_root(),
        check=True,
        stdout=subprocess.PIPE if capture_json else None,
        stderr=None,
        encoding="utf-8",
        errors="replace",
    )
    return completed.stdout or ""


def fetch_pr_info(pr_selector: str) -> dict[str, object]:
    raw = run_gh(
        [
            "pr",
            "view",
            pr_selector,
            "--json",
            "number,title,body,baseRefName,headRefName,isDraft,url",
        ],
        capture_json=True,
    )
    return json.loads(raw)


def verify_pr_body(
    pr_selector: str,
    body_file: str | Path,
    *,
    title: str | None = None,
    base: str | None = None,
    head: str | None = None,
    draft: bool | None = None,
) -> dict[str, object]:
    validate_file(body_file)
    info = fetch_pr_info(pr_selector)
    compare_body_text(read_body_text(body_file), str(info.get("body") or ""))
    compare_pr_metadata(info, title=title, base=base, head=head, draft=draft)
    return info


def create_pr_body(
    *,
    title: str,
    body_file: str | Path,
    base: str | None = None,
    head: str | None = None,
    draft: bool = False,
) -> dict[str, object]:
    validate_file(body_file)
    args = ["pr", "create", "--title", title, "--body-file", str(resolve_body_path(body_file))]
    if base:
        args.extend(["--base", base])
    if head:
        args.extend(["--head", head])
    if draft:
        args.append("--draft")

    output = run_gh(args, capture_json=True).strip()
    selector = output.splitlines()[-1] if output else head or title
    return verify_pr_body(selector, body_file, title=title, base=base, head=head, draft=draft)


def edit_pr_body(
    pr_selector: str,
    body_file: str | Path,
    *,
    title: str | None = None,
    base: str | None = None,
    head: str | None = None,
    draft: bool | None = None,
) -> dict[str, object]:
    validate_file(body_file)
    args = ["pr", "edit", pr_selector, "--body-file", str(resolve_body_path(body_file))]
    if title:
        args.extend(["--title", title])
    run_gh(args)
    return verify_pr_body(pr_selector, body_file, title=title, base=base, head=head, draft=draft)


def _emit_stdout(message: str) -> None:
    sys.stdout.buffer.write((message + "\n").encode("utf-8"))


def _emit_stderr(message: str) -> None:
    sys.stderr.buffer.write((message + "\n").encode("utf-8"))


def _format_pr_info(info: dict[str, object]) -> str:
    return (
        f"PR #{info.get('number')} verified: "
        f"title={info.get('title')!r}, "
        f"{info.get('baseRefName')} <- {info.get('headRefName')}, "
        f"draft={info.get('isDraft')}, {info.get('url')}"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Normalize, validate, create, edit, and verify UTF-8 GitHub PR bodies."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    normalize_parser = subparsers.add_parser("normalize", help="Normalize a Markdown body to UTF-8 no BOM and LF.")
    normalize_parser.add_argument("--input", required=True)
    normalize_parser.add_argument("--output", help=f"default: {TEMP_BODY_DIR.as_posix()}/<input-name>")

    validate_parser = subparsers.add_parser("validate", help="Validate a Markdown body file.")
    validate_parser.add_argument("body_file")

    create_parser = subparsers.add_parser("create", help="Create a PR with gh, then read back and verify the body.")
    create_parser.add_argument("--title", required=True)
    create_parser.add_argument("--body-file", required=True)
    create_parser.add_argument("--base", required=True)
    create_parser.add_argument("--head", required=True)
    create_parser.add_argument("--draft", action="store_true")

    edit_parser = subparsers.add_parser("edit", help="Edit a PR body with gh, then read back and verify it.")
    edit_parser.add_argument("--pr", required=True)
    edit_parser.add_argument("--body-file", required=True)
    edit_parser.add_argument("--title")
    edit_parser.add_argument("--base")
    edit_parser.add_argument("--head")
    edit_parser.add_argument("--draft", choices=["true", "false"])

    verify_parser = subparsers.add_parser("verify", help="Read back a PR and compare it to expected local metadata.")
    verify_parser.add_argument("--pr", required=True)
    verify_parser.add_argument("--body-file", required=True)
    verify_parser.add_argument("--title")
    verify_parser.add_argument("--base")
    verify_parser.add_argument("--head")
    verify_parser.add_argument("--draft", choices=["true", "false"])

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "normalize":
            output = normalize_file(args.input, args.output)
            _emit_stdout(f"normalized PR body: {output}")
        elif args.command == "validate":
            validate_file(args.body_file)
            _emit_stdout(f"valid PR body: {resolve_body_path(args.body_file)}")
        elif args.command == "create":
            info = create_pr_body(
                title=args.title,
                body_file=args.body_file,
                base=args.base,
                head=args.head,
                draft=args.draft,
            )
            _emit_stdout(_format_pr_info(info))
        elif args.command == "edit":
            info = edit_pr_body(
                args.pr,
                args.body_file,
                title=args.title,
                base=args.base,
                head=args.head,
                draft=parse_draft_value(args.draft),
            )
            _emit_stdout(_format_pr_info(info))
        elif args.command == "verify":
            info = verify_pr_body(
                args.pr,
                args.body_file,
                title=args.title,
                base=args.base,
                head=args.head,
                draft=parse_draft_value(args.draft),
            )
            _emit_stdout(_format_pr_info(info))
        else:  # pragma: no cover - argparse enforces commands
            raise AssertionError(f"unknown command: {args.command}")
    except (PrBodyError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        _emit_stderr(f"error: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
