from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "dev" / "pr_body_tool.py"
BODY_DIR = ROOT / ".tmp" / "pr-bodies"

spec = importlib.util.spec_from_file_location("pr_body_tool", MODULE_PATH)
pr_body_tool = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(pr_body_tool)


def write_body(name: str, text: str = "Summary\n") -> Path:
    BODY_DIR.mkdir(parents=True, exist_ok=True)
    path = BODY_DIR / name
    path.write_text(text, encoding="utf-8", newline="\n")
    return path


def pr_info(body: str = "Summary\n", **overrides: object) -> dict[str, object]:
    info: dict[str, object] = {
        "number": 22,
        "title": "Add local PR body guard",
        "body": body,
        "baseRefName": "main",
        "headRefName": "codex/add-pr-body-tool",
        "isDraft": False,
        "url": "https://github.com/phdiggit/win11-image-kit/pull/22",
    }
    info.update(overrides)
    return info


class PrBodyToolTests(unittest.TestCase):
    def tearDown(self) -> None:
        for path in BODY_DIR.glob("unit-*.md") if BODY_DIR.exists() else []:
            path.unlink()

    def test_validate_allows_unknown_opening_fence_language(self) -> None:
        text = """Summary

```mermaid
graph TD
```

```powershell
git -c core.quotepath=false status --short
```
"""
        self.assertEqual([], pr_body_tool.validate_text(text))

    def test_validate_rejects_damaged_single_backtick_fence(self) -> None:
        errors = pr_body_tool.validate_text("`powershell\nGet-ChildItem\n```\n")
        self.assertIn("damaged Markdown code fence is not allowed", "; ".join(errors))

    def test_validate_rejects_unpaired_fence(self) -> None:
        errors = pr_body_tool.validate_text("```powershell\nGet-ChildItem\n")
        self.assertIn("triple-backtick code fences must be paired", "; ".join(errors))

    def test_normalize_file_writes_utf8_lf_under_body_dir(self) -> None:
        source = write_body("unit-source.md", "\ufeff摘要\r\n\r\n```yaml\r\nok: true\r\n```\r\n")
        target = BODY_DIR / "unit-normalized.md"

        result = pr_body_tool.normalize_file(source, target)

        self.assertEqual(target.resolve(), result)
        self.assertEqual("摘要\n\n```yaml\nok: true\n```\n", target.read_text(encoding="utf-8"))

    def test_repo_path_escape_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            outside = Path(temp_dir) / "body.md"
            outside.write_text("Summary\n", encoding="utf-8")

            with self.assertRaisesRegex(pr_body_tool.PrBodyError, "repository root"):
                pr_body_tool.resolve_repo_path(outside, purpose="test path")

            with self.assertRaisesRegex(pr_body_tool.PrBodyError, "repository root"):
                pr_body_tool.normalize_file(outside, BODY_DIR / "unit-normalized.md")

    def test_body_file_must_be_under_pr_bodies_dir(self) -> None:
        with self.assertRaisesRegex(pr_body_tool.PrBodyError, ".tmp/pr-bodies"):
            pr_body_tool.validate_file(ROOT / "AGENTS.md")

        with self.assertRaisesRegex(pr_body_tool.PrBodyError, ".tmp/pr-bodies"):
            pr_body_tool.normalize_file(ROOT / "AGENTS.md", ROOT / ".tmp" / "unit-output.md")

    def test_compare_body_text_accepts_line_ending_difference(self) -> None:
        pr_body_tool.compare_body_text("摘要\r\n", "摘要\n")

    def test_compare_body_text_rejects_mismatch(self) -> None:
        with self.assertRaises(pr_body_tool.PrBodyError):
            pr_body_tool.compare_body_text("摘要：正确\n", "摘要：损坏\n")

    def test_verify_checks_title_base_head_and_draft(self) -> None:
        body_file = write_body("unit-verify.md")

        with patch.object(pr_body_tool, "fetch_pr_info", return_value=pr_info()):
            info = pr_body_tool.verify_pr_body(
                "22",
                body_file,
                title="Add local PR body guard",
                base="main",
                head="codex/add-pr-body-tool",
                draft=False,
            )

        self.assertEqual(22, info["number"])

    def test_verify_rejects_remote_body_mismatch(self) -> None:
        body_file = write_body("unit-body-mismatch.md")

        with patch.object(pr_body_tool, "fetch_pr_info", return_value=pr_info(body="Broken\n")):
            with self.assertRaisesRegex(pr_body_tool.PrBodyError, "body does not match"):
                pr_body_tool.verify_pr_body("22", body_file)

    def test_verify_rejects_metadata_mismatches(self) -> None:
        body_file = write_body("unit-metadata.md")
        cases = [
            ("title", {"title": "Wrong"}, {"title": "Add local PR body guard"}),
            ("base", {"baseRefName": "release"}, {"base": "main"}),
            ("head", {"headRefName": "wrong"}, {"head": "codex/add-pr-body-tool"}),
            ("draft", {"isDraft": True}, {"draft": False}),
        ]

        for name, remote_override, expected in cases:
            with self.subTest(name=name):
                with patch.object(pr_body_tool, "fetch_pr_info", return_value=pr_info(**remote_override)):
                    with self.assertRaisesRegex(pr_body_tool.PrBodyError, f"{name} mismatch"):
                        pr_body_tool.verify_pr_body("22", body_file, **expected)

    def test_create_uses_body_file_and_verifies_metadata(self) -> None:
        body_file = write_body("unit-create.md")
        calls: list[list[str]] = []

        def fake_run_gh(args: list[str], *, capture_json: bool = False) -> str:
            calls.append(args)
            if args[:2] == ["pr", "create"]:
                return "https://github.com/phdiggit/win11-image-kit/pull/22\n"
            if args[:2] == ["pr", "view"]:
                return json.dumps(pr_info())
            raise AssertionError(args)

        with patch.object(pr_body_tool, "run_gh", side_effect=fake_run_gh):
            pr_body_tool.create_pr_body(
                title="Add local PR body guard",
                body_file=body_file,
                base="main",
                head="codex/add-pr-body-tool",
                draft=False,
            )

        self.assertEqual("pr", calls[0][0])
        self.assertEqual("create", calls[0][1])
        self.assertIn("--body-file", calls[0])
        self.assertIn(str(body_file.resolve()), calls[0])
        self.assertIn("--base", calls[0])
        self.assertIn("--head", calls[0])

    def test_edit_uses_body_file_and_optional_metadata_verify(self) -> None:
        body_file = write_body("unit-edit.md")
        calls: list[list[str]] = []

        def fake_run_gh(args: list[str], *, capture_json: bool = False) -> str:
            calls.append(args)
            return ""

        with patch.object(pr_body_tool, "run_gh", side_effect=fake_run_gh):
            with patch.object(pr_body_tool, "fetch_pr_info", return_value=pr_info()):
                pr_body_tool.edit_pr_body("22", body_file, title="Add local PR body guard")

        self.assertEqual(
            ["pr", "edit", "22", "--body-file", str(body_file.resolve()), "--title", "Add local PR body guard"],
            calls[0],
        )

    def test_gh_unavailable_raises_clear_error(self) -> None:
        with patch.object(pr_body_tool.shutil, "which", return_value=None):
            with self.assertRaisesRegex(pr_body_tool.PrBodyError, "gh CLI is not available"):
                pr_body_tool.ensure_gh_available()

    def test_main_returns_nonzero_for_metadata_mismatch(self) -> None:
        body_file = write_body("unit-cli-mismatch.md")

        with patch.object(pr_body_tool, "fetch_pr_info", return_value=pr_info(baseRefName="release")):
            with patch.object(pr_body_tool, "_emit_stderr"):
                result = pr_body_tool.main(
                    [
                        "verify",
                        "--pr",
                        "22",
                        "--body-file",
                        str(body_file),
                        "--base",
                        "main",
                    ]
                )

        self.assertEqual(1, result)


if __name__ == "__main__":
    unittest.main()
