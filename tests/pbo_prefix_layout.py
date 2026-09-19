"""Guard the HEMTT source-link/prefix regression found in alpha7.

HEMTT creates temporary links at each addon prefix before binarization. A prefix
nested below another addon can therefore create a link inside that addon's source.
HEMTT 1.21's recursive packer treats the nested $PBOPREFIX$ as another PBO header,
which can replace the core prefix while reporting a successful build.
"""

from pathlib import Path
import hashlib
import os
import re
import struct
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


def check_prefixes(prefixes):
    normalized = {}
    for name, prefix in prefixes.items():
        parts = tuple(prefix.replace("/", "\\").strip("\\").lower().split("\\"))
        if not all(parts) or any(part in {".", ".."} for part in parts):
            raise ValueError(f"Invalid prefix for {name}: {prefix!r}")
        for other_name, other in normalized.items():
            length = min(len(parts), len(other))
            if parts[:length] == other[:length]:
                raise ValueError(f"Overlapping addon prefixes: {other_name} and {name}")
        normalized[name] = parts


def source_prefixes(root):
    result = {}
    for addon in sorted((root / "addons").iterdir()):
        if not addon.is_dir():
            continue
        if addon.is_symlink() or getattr(addon, "is_junction", lambda: False)():
            raise ValueError(f"Linked addon source: {addon}")
        result[addon.name] = (addon / "$PBOPREFIX$").read_text().strip()
        for directory, dirs, files in os.walk(addon, followlinks=False):
            current = Path(directory)
            for name in dirs:
                child = current / name
                if child.is_symlink() or getattr(child, "is_junction", lambda: False)():
                    raise ValueError(f"Generated link inside addon: {child}")
            if current != addon and "$PBOPREFIX$" in files:
                raise ValueError(f"Nested prefix marker: {current}")
    check_prefixes(result)
    return result


def read_pbo(path):
    data = path.read_bytes()
    if data[-21:-20] != b"\0" or hashlib.sha1(data[:-21]).digest() != data[-20:]:
        raise ValueError(f"Invalid PBO checksum: {path}")
    offset = 0
    properties, entries = {}, []

    def string():
        nonlocal offset
        end = data.index(b"\0", offset)
        value = data[offset:end].decode("utf-8")
        offset = end + 1
        return value

    while True:
        name = string()
        method, original, reserved, timestamp, size = struct.unpack_from("<5I", data, offset)
        offset += 20
        if not name and method == 0x56657273:
            while True:
                key = string()
                if not key:
                    break
                properties[key] = string()
            continue
        if not name:
            break
        if method != 0:
            raise ValueError(f"Unexpected compressed entry: {path}: {name}")
        entries.append((name.replace("\\", "/").lower(), size))
    contents = {}
    for name, size in entries:
        contents[name] = data[offset:offset + size]
        offset += size
    if offset != len(data) - 21:
        raise ValueError(f"Invalid PBO payload length: {path}")
    return properties, contents


class PboPrefixLayout(unittest.TestCase):
    def test_source_prefixes_and_core_function_paths(self):
        prefixes = source_prefixes(ROOT)
        self.assertEqual(prefixes, {"gait": "gait", "heartbeat": "z\\gait\\addons\\heartbeat"})
        config = (ROOT / "addons/gait/config.cpp").read_text()
        self.assertIn('file = "\\gait\\functions";', config)
        paths = re.findall(r"'\\gait\\([^']+\.sqf)'", config)
        self.assertIn("functions\\fn_registerSettings.sqf", paths)
        for path in paths:
            self.assertTrue((ROOT / "addons/gait" / Path(path.replace("\\", "/"))).is_file(), path)

    def test_rejects_alpha7_nested_prefix_in_either_order(self):
        for prefixes in ({"gait": "gait", "heartbeat": "gait\\heartbeat"},
                         {"heartbeat": "GAIT/heartbeat", "gait": "gait"}):
            with self.assertRaisesRegex(ValueError, "Overlapping addon prefixes"):
                check_prefixes(prefixes)

    def test_rejects_leftover_nested_prefix_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            addon = root / "addons/gait"
            nested = addon / "heartbeat"
            nested.mkdir(parents=True)
            (addon / "$PBOPREFIX$").write_text("gait")
            (nested / "$PBOPREFIX$").write_text("gait\\heartbeat")
            with self.assertRaisesRegex(ValueError, "Nested prefix marker"):
                source_prefixes(root)

    def test_built_prefixes_settings_payload_and_checksums(self):
        build = ROOT / ".hemttout/build/addons"
        if not build.exists():
            self.skipTest("Run hemtt build to validate the packed PBOs")
        for addon, prefix in source_prefixes(ROOT).items():
            properties, contents = read_pbo(build / f"gait_{addon}.pbo")
            self.assertEqual(properties["prefix"], prefix)
            self.assertIn("config.bin", contents)
            self.assertFalse(any(name.startswith("heartbeat/") for name in contents))
            if addon == "gait":
                for source in (ROOT / "addons/gait/functions").glob("*.sqf"):
                    self.assertEqual(contents[f"functions/{source.name.lower()}"], source.read_bytes())


if __name__ == "__main__":
    unittest.main()
