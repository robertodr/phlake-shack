"""Offline checks for the pinned package; never execute upstream skill scripts."""

import importlib.util
import json
from pathlib import Path
import re
import sys
import unittest

import yaml


PLAN = json.loads(Path(sys.argv[1]).read_text())
ROOT = Path(sys.argv[2])
SPEC = importlib.util.spec_from_file_location("visibility", sys.argv[3])
visibility = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(visibility)


def split_document(text):
    match = re.fullmatch(r"---\n(.*?)\n---(\n.*)", text, re.DOTALL)
    if match is None:
        raise ValueError("Missing YAML frontmatter")
    return yaml.safe_load(match[1]), match[2]


class CommunitySkills(unittest.TestCase):
    def test_explicit_allowlist(self):
        self.assertEqual(len(PLAN["sources"]), 38)
        self.assertEqual(
            {path.relative_to(ROOT).as_posix() for path in ROOT.rglob("SKILL.md")},
            {f"{name}/{name}/SKILL.md" for name in PLAN["sources"]},
        )
        self.assertEqual(
            set(PLAN["autoInvoke"]),
            {"dispatching-parallel-agents", "subagent-driven-development"},
        )

    def test_metadata_and_bodies(self):
        for name, source in PLAN["sources"].items():
            with self.subTest(skill=name):
                before, original_body = split_document(
                    (Path(source) / "SKILL.md").read_text()
                )
                after, packaged_body = split_document(
                    (ROOT / name / name / "SKILL.md").read_text()
                )
                self.assertEqual(after["name"], name)
                self.assertIsInstance(after["description"], str)
                self.assertTrue(after["description"].strip())
                self.assertIs(
                    after.pop("disable-model-invocation", False),
                    name not in PLAN["autoInvoke"],
                )
                before.pop("disable-model-invocation", None)
                self.assertEqual(before, after)
                self.assertEqual(original_body, packaged_body)

    def test_complete_resource_directories(self):
        for name, source in PLAN["sources"].items():
            with self.subTest(skill=name):
                original = Path(source)
                packaged = ROOT / name / name
                files = {p.relative_to(original) for p in original.rglob("*")}
                self.assertEqual(
                    files, {p.relative_to(packaged) for p in packaged.rglob("*")}
                )
                for relative in files:
                    a, b = original / relative, packaged / relative
                    self.assertEqual(a.is_symlink(), b.is_symlink())
                    self.assertEqual(a.is_dir(), b.is_dir())
                    if a.is_symlink():
                        self.assertEqual(a.readlink(), b.readlink())
                    elif a.is_file():
                        self.assertEqual(
                            a.stat().st_mode & 0o111, b.stat().st_mode & 0o111
                        )
                        if relative != Path("SKILL.md"):
                            self.assertEqual(a.read_bytes(), b.read_bytes())

    def test_provenance_and_licenses(self):
        docs = ROOT.parent / "doc" / "community-skills"
        sources = json.loads((docs / "sources.json").read_text())
        self.assertEqual(
            {key: len(source["skills"]) for key, source in sources.items()},
            {"superpowers": 14, "mattpocock": 23, "vercel": 1},
        )
        for key, source in sources.items():
            with self.subTest(source=key):
                self.assertRegex(source["rev"], r"^[0-9a-f]{40}$")
                self.assertTrue(source["hash"].startswith("sha256-"))
                license_text = (docs / key / "LICENSE").read_text()
                self.assertIn("MIT License", license_text)
                self.assertIn("Permission is hereby granted", license_text)

    def test_visibility_only_changes_its_metadata(self):
        for original_flag in (
            "",
            "disable-model-invocation: true\n",
            "disable-model-invocation: false\n",
        ):
            for enabled in (True, False):
                with self.subTest(flag=original_flag, enabled=enabled):
                    text = (
                        "---\nname: fixture\ndescription: |-\n  Literal description\n"
                        + original_flag
                        + "---\n\n# Body\n\n"
                        + "disable-model-invocation: leave body alone\n"
                    )
                    result = visibility.configure(text, enabled)
                    before, body_before = split_document(text)
                    after, body_after = split_document(result)
                    self.assertIs(
                        after.pop("disable-model-invocation", False), not enabled
                    )
                    before.pop("disable-model-invocation", None)
                    self.assertEqual(before, after)
                    self.assertEqual(body_before, body_after)
                    self.assertEqual(result, visibility.configure(result, enabled))

    def test_reject_missing_frontmatter(self):
        for text in ("# Not a skill\n", "---\nname: broken\n"):
            with self.subTest(text=text):
                with self.assertRaises(ValueError):
                    visibility.configure(text, False)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]], verbosity=2)
