"""Boundary tests: malformed Bootspec must never select a different boot path."""

import hashlib
import json
import tempfile
import unittest
from dataclasses import FrozenInstanceError
from pathlib import Path

from secure_uki.metadata import Generation, read_generation


class MetadataTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.store = Path(self.tmp.name) / "store"
        self.closure = self.store / "fixture-system"
        (self.closure / "etc").mkdir(parents=True)
        for name in ("kernel", "initrd", "init"):
            (self.closure / name).write_bytes(b"fixture")
        (self.closure / "etc/os-release").write_text("ID=nixos\n")
        self.payload = {
            "org.nixos.bootspec.v1": {
                "toplevel": str(self.closure), "system": "x86_64-linux",
                "kernel": str(self.closure / "kernel"),
                "initrd": str(self.closure / "initrd"),
                "init": str(self.closure / "init"),
                "kernelParams": ["console=ttyS0", "quiet"], "label": "fixture",
            },
            "org.nixos.specialisation.v1": {},
        }
        self.write_payload()

    @property
    def spec(self):
        return self.payload["org.nixos.bootspec.v1"]

    def write_payload(self):
        (self.closure / "boot.json").write_text(json.dumps(self.payload))

    def read(self):
        return read_generation(self.closure, store_root=self.store)

    def test_selected_components_and_exact_cmdline(self):
        generation = self.read()
        self.assertIsInstance(generation, Generation)
        self.assertEqual(generation.closure, self.closure)
        self.assertEqual(generation.kernel, self.closure / "kernel")
        self.assertEqual(generation.initrd, self.closure / "initrd")
        self.assertEqual(generation.init, self.closure / "init")
        self.assertEqual(generation.os_release, self.closure / "etc/os-release")
        self.assertEqual(generation.cmdline, f"init={self.closure}/init console=ttyS0 quiet")
        self.assertEqual(generation.label, "fixture")

    def test_canonical_identity_and_metadata_order(self):
        generation = self.read()
        self.assertIsInstance(generation, Generation)
        expected_identity = {
            "version": 1, "closure": str(self.closure),
            "kernel": str(self.closure / "kernel"), "initrd": str(self.closure / "initrd"),
            "init": str(self.closure / "init"), "os_release": str(self.closure / "etc/os-release"),
            "cmdline": f"init={self.closure}/init console=ttyS0 quiet", "label": "fixture",
        }
        digest = hashlib.sha256(json.dumps(expected_identity, sort_keys=True,
                                          separators=(",", ":")).encode()).hexdigest()
        self.assertEqual(generation.generation_id, digest)
        self.payload = dict(reversed(list(self.payload.items())))
        self.write_payload()
        self.assertEqual(self.read().generation_id, digest)

    def test_changed_cmdline_changes_identity(self):
        original = self.read()
        self.assertIsInstance(original, Generation)
        self.spec["kernelParams"].append("debug")
        self.write_payload()
        self.assertNotEqual(self.read().generation_id, original.generation_id)

    def test_generation_is_immutable(self):
        generation = self.read()
        self.assertIsInstance(generation, Generation)
        with self.assertRaises(FrozenInstanceError):
            generation.label = "changed"

    def test_alias_closure_is_canonicalized(self):
        alias = Path(self.tmp.name) / "system-profile"
        alias.symlink_to(self.closure, target_is_directory=True)
        generation = read_generation(alias, store_root=self.store)
        self.assertIsInstance(generation, Generation)
        self.assertEqual(generation.closure, self.closure)

    def test_store_contained_component_symlink(self):
        kernel = self.store / "kernel-package/bzImage"
        kernel.parent.mkdir()
        kernel.write_bytes(b"kernel")
        (self.closure / "kernel").unlink()
        (self.closure / "kernel").symlink_to(kernel)
        generation = self.read()
        self.assertIsInstance(generation, Generation)
        self.assertEqual(generation.kernel, kernel)

    def test_rejects_missing_required_fields(self):
        for field in ("toplevel", "system", "kernel", "initrd", "init", "kernelParams", "label"):
            with self.subTest(field=field):
                value = self.spec.pop(field)
                self.write_payload()
                with self.assertRaises(ValueError):
                    self.read()
                self.spec[field] = value

    def test_rejects_missing_or_nonregular_files(self):
        for name in ("kernel", "initrd", "init", "etc/os-release", "boot.json"):
            with self.subTest(name=name):
                path = self.closure / name
                contents = path.read_bytes()
                path.unlink()
                with self.assertRaises(ValueError):
                    self.read()
                path.mkdir()
                with self.assertRaises(ValueError):
                    self.read()
                path.rmdir()
                path.write_bytes(contents)

    def test_rejects_path_escape(self):
        outside = Path(self.tmp.name) / "outside-kernel"
        outside.write_bytes(b"fixture")
        self.spec["kernel"] = str(outside)
        self.write_payload()
        with self.assertRaisesRegex(ValueError, "store"):
            self.read()

    def test_rejects_symlink_escape(self):
        outside = Path(self.tmp.name) / "outside-kernel"
        outside.write_bytes(b"fixture")
        (self.closure / "kernel").unlink()
        (self.closure / "kernel").symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "store"):
            self.read()

    def test_rejects_ambiguous_canonical_init_paths(self):
        for name in ("init extra=1", 'init"extra', "init\nextra"):
            with self.subTest(name=name):
                target = self.store / "init-package" / name
                target.parent.mkdir(exist_ok=True)
                target.write_bytes(b"init")
                path = self.closure / "init"
                path.unlink()
                path.symlink_to(target)
                with self.assertRaises(ValueError):
                    self.read()

    def test_rejects_metadata_symlink_escape(self):
        outside = Path(self.tmp.name) / "outside-json"
        outside.write_text(json.dumps(self.payload))
        (self.closure / "boot.json").unlink()
        (self.closure / "boot.json").symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "store"):
            self.read()

    def test_rejects_nonmatching_toplevel(self):
        other = self.store / "other-system"
        other.mkdir()
        self.spec["toplevel"] = str(other)
        self.write_payload()
        with self.assertRaises(ValueError):
            self.read()

    def test_rejects_different_generation_init(self):
        other = self.store / "other-system/init"
        other.parent.mkdir()
        other.write_bytes(b"init")
        self.spec["init"] = str(other)
        self.write_payload()
        with self.assertRaises(ValueError):
            self.read()

    def test_rejects_invalid_path_values(self):
        for value in (None, 42, "", "kernel", "bad\x00path"):
            with self.subTest(value=value):
                self.spec["kernel"] = value
                self.write_payload()
                with self.assertRaises(ValueError):
                    self.read()

    def test_rejects_unsupported_system(self):
        self.spec["system"] = "aarch64-linux"
        self.write_payload()
        with self.assertRaises(ValueError):
            self.read()

    def test_rejects_malformed_schema(self):
        for payload in ([], None, {}, {"org.nixos.bootspec.v1": []},
                        {"org.nixos.bootspec.v2": self.spec}):
            with self.subTest(payload=payload):
                (self.closure / "boot.json").write_text(json.dumps(payload))
                with self.assertRaises(ValueError):
                    self.read()

    def test_accepts_pinned_auxiliary_extensions_without_changing_components(self):
        original = self.read()
        self.payload["org.nixos.nixos-init.v1"] = {
            "firmware": str(self.store / "firmware/lib/firmware"),
            "modprobe_binary": str(self.store / "kmod/bin/modprobe"),
            "nix_store_mount_opts": ["ro"],
            "sh_binary": str(self.store / "bash/bin/sh"),
            "env_binary": str(self.store / "coreutils/bin/env"),
        }
        self.payload["org.nixos.systemd-boot"] = {"sortKey": "nixos"}
        self.write_payload()
        try:
            augmented = self.read()
        except ValueError as exc:
            self.fail(f"Pinned NixOS auxiliary metadata was rejected: {exc}")
        self.assertEqual(augmented, original)

    def test_rejects_malformed_auxiliary_extensions(self):
        for name in ("org.nixos.nixos-init.v1", "org.nixos.systemd-boot"):
            for value in ([], None, "not an object"):
                with self.subTest(name=name, value=value):
                    self.payload[name] = value
                    self.write_payload()
                    with self.assertRaises(ValueError):
                        self.read()
                    self.payload.pop(name)

    def test_rejects_unknown_auxiliary_version(self):
        self.payload["org.nixos.nixos-init.v2"] = {}
        self.write_payload()
        with self.assertRaises(ValueError):
            self.read()

    def test_rejects_unknown_schema_alongside_v1(self):
        self.payload["org.nixos.bootspec.v2"] = self.spec.copy()
        self.write_payload()
        with self.assertRaises(ValueError):
            self.read()

    def test_rejects_specialisations(self):
        for value in ({"other": self.spec.copy()}, [], None):
            with self.subTest(value=value):
                self.payload["org.nixos.specialisation.v1"] = value
                self.write_payload()
                with self.assertRaises(ValueError):
                    self.read()

    def test_accepts_absent_empty_specialisations(self):
        self.payload.pop("org.nixos.specialisation.v1")
        self.write_payload()
        self.assertIsInstance(self.read(), Generation)

    def test_rejects_invalid_json(self):
        (self.closure / "boot.json").write_text("{not json}")
        with self.assertRaises(ValueError):
            self.read()

    def test_rejects_duplicate_json_keys(self):
        text = json.dumps(self.payload)
        text = text.replace('"label": "fixture"', '"label": "fixture", "label": "other"')
        (self.closure / "boot.json").write_text(text)
        with self.assertRaises(ValueError):
            self.read()

    def test_rejects_invalid_kernel_params(self):
        for value in ("quiet", None, [42], [""], ["quiet\n"], ["quiet\x00"],
                      ["init=/other/init"], ["foo=1 init=/other/init"], ["two words"]):
            with self.subTest(value=value):
                self.spec["kernelParams"] = value
                self.write_payload()
                with self.assertRaises(ValueError):
                    self.read()

    def test_rejects_invalid_labels(self):
        for value in (None, 42, "", "bad\nlabel", "bad\x00label"):
            with self.subTest(value=value):
                self.spec["label"] = value
                self.write_payload()
                with self.assertRaises(ValueError):
                    self.read()


if __name__ == "__main__":
    unittest.main()
