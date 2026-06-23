from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "dev" / "pr_body_tool.py"

spec = importlib.util.spec_from_file_location("pr_body_tool", MODULE_PATH)
pr_body_tool = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(pr_body_tool)


class PrBodyToolTests(unittest.TestCase):
    def test_validate_allows_project_common_markdown(self) -> None:
        text = """摘要：中文正文保持 UTF-8。

```powershell
git -c core.quotepath=false status --short
```

```cmd
dir
```

```yaml
base: main
```
"""
        self.assertEqual([], pr_body_tool.validate_text(text))

    def test_validate_rejects_damaged_single_backtick_fence(self) -> None:
        errors = pr_body_tool.validate_text("`powershell\nGet-ChildItem\n```\n")
        self.assertIn("damaged Markdown code fence is not allowed", "; ".join(errors))

    def test_validate_rejects_unpaired_fence(self) -> None:
        errors = pr_body_tool.validate_text("```powershell\nGet-ChildItem\n")
        self.assertIn("triple-backtick code fences must be paired", "; ".join(errors))

    def test_normalize_file_writes_utf8_lf(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            source = Path(temp_dir) / "body.md"
            target = Path(temp_dir) / "normalized.md"
            source.write_bytes("\ufeff摘要\r\n\r\n```yaml\r\nok: true\r\n```\r\n".encode("utf-8"))

            result = pr_body_tool.normalize_file(source, target)

            self.assertEqual(target.resolve(), result)
            self.assertEqual("摘要\n\n```yaml\nok: true\n```\n", target.read_text(encoding="utf-8"))

    def test_compare_body_text_rejects_mismatch(self) -> None:
        with self.assertRaises(pr_body_tool.PrBodyError):
            pr_body_tool.compare_body_text("摘要：正确\n", "摘要：损坏\n")

    def test_compare_body_text_accepts_line_ending_difference(self) -> None:
        pr_body_tool.compare_body_text("摘要\r\n", "摘要\n")


if __name__ == "__main__":
    unittest.main()
