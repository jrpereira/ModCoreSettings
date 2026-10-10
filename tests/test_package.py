import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package_mod', ROOT / 'tools/package.py')
pack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pack)

class PackageTests(unittest.TestCase):
    def test_allowlist_checksum_and_reproducibility(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'repo'
            shutil.copytree(ROOT, root, ignore=shutil.ignore_patterns('.git', 'dist', '__pycache__'))
            (root / 'config.ini').write_text('PERSONAL_CONFIGURATION_MUST_NOT_SHIP')
            (root / 'crash.dmp').write_bytes(b'PRIVATE_DUMP')
            (root / 'Scripts/temporary_probe.lua').write_text('TEMPORARY_PROBE')
            archive = pack.build(root)
            before = archive.read_bytes()
            self.assertEqual(before, pack.build(root).read_bytes())
            self.assertEqual(archive.with_suffix('.zip.sha256').read_text().split()[0], hashlib.sha256(before).hexdigest())
            with ZipFile(archive) as bundle:
                names = bundle.namelist()
                self.assertIn(pack.MODULE + '/Scripts/main.lua', names)
                # Every package ships enabled by default.
                self.assertIn(pack.MODULE + '/enabled.txt', names)
                self.assertNotIn(pack.MODULE + '/Scripts/temporary_probe.lua', names)
                declared = json.loads((ROOT / 'release-manifest.json').read_text())['files']
                self.assertEqual({n for n in names if '/Scripts/' in n},
                                 {pack.MODULE + '/' + n for n in declared if n.startswith('Scripts/')})
                self.assertIn(pack.MODULE + '/data/module_categories.lua', names)
                self.assertIn(pack.MODULE + '/data/folder_categories.lua', names)
                self.assertNotIn(pack.MODULE + '/data/module_fingerprints.lua', names)
                # The shared manifest reader is loaded by the DMM extension.
                self.assertIn('1_ModCore_Settings/Scripts/mcs_manifest.lua', names)
                self.assertIn('1_ModCore_Settings/Scripts/dmm_extension.lua', names)
                self.assertIn('1_ModCore_Settings/Scripts/navigation.lua', names)
                self.assertIn('1_ModCore_Settings/Scripts/browser_groups.lua', names)
                self.assertIn('1_ModCore_Settings/Scripts/error_log.lua', names)
                # MCS's own page is contributed menu data, not a DMM manifest on disk.
                self.assertNotIn('1_ModCore_Settings/mod_settings.ini', names)
                self.assertIn('1_ModCore_Settings/Scripts/mcs_page.lua', names)
                # Documents in docs/ are published at the module root.
                for doc in ('README.md', 'CHANGELOG.md', 'BUILD.md', 'DEVELOPERS.md'):
                    self.assertIn('1_ModCore_Settings/' + doc, names)
                # The BBCode Nexus description stays in the repository only.
                self.assertNotIn('1_ModCore_Settings/NEXUS.bb', names)
                self.assertFalse(any('/docs/' in n for n in names))
                self.assertFalse(any('/dlls/' in n or n.lower().endswith('.dll') for n in names))
                self.assertIn('1_ModCore_Settings/Scripts/dirty_labels.lua', names)
                self.assertIn('1_ModCore_Settings/Scripts/init_config.lua', names)
                self.assertIn('1_ModCore_Settings/Scripts/vendor/settings_api.lua', names)
                self.assertFalse(any(n.endswith('/config.ini') or n.endswith('.dmp') or '/tests/' in n for n in names))
                if pack.MODULE == 'QuickslotsForever':
                    self.assertEqual(bundle.read(pack.MODULE + '/config.example.ini'), (root / 'distribution/config.ini').read_bytes())
                for name in names:
                    self.assertNotIn(b'PERSONAL_CONFIGURATION_MUST_NOT_SHIP', bundle.read(name))

    def test_release_version_mismatch_rejected(self):
        with self.assertRaises(ValueError):
            pack.build(expected='999.0.0')

    def test_release_candidate_version(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'Scripts').mkdir()
            (root / 'Scripts/main.lua').write_text("local VERSION='0.1.31-rc.1'")
            shutil.copy2(ROOT / 'release-manifest.json', root / 'release-manifest.json')
            self.assertEqual(pack.version(root), '0.1.31-rc.1')

    def test_invalid_source_version_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'Scripts').mkdir()
            (root / 'Scripts/main.lua').write_text('local VERSION="invalid"')
            shutil.copy2(ROOT / 'release-manifest.json', root / 'release-manifest.json')
            with self.assertRaises(ValueError):
                pack.version(root)

if __name__ == '__main__':
    unittest.main()
