from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import runtime_paths


class RuntimePathsTests(unittest.TestCase):
    def test_source_records_stay_in_project(self):
        with patch.object(runtime_paths, 'FROZEN', False):
            self.assertEqual(runtime_paths.records_dir(), runtime_paths.BUNDLE_DIR / 'registros')

    def test_executable_records_survive_bundle_replacement(self):
        with patch.object(runtime_paths, 'FROZEN', True), patch.dict('os.environ', {'LOCALAPPDATA': 'C:/Users/Test/AppData/Local'}):
            self.assertEqual(runtime_paths.records_dir(), Path('C:/Users/Test/AppData/Local/FabulaTEA/registros'))

    def test_custom_image_and_bundle_fallback(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            custom, bundle = root / 'custom', root / 'bundle'
            (custom / 'assets').mkdir(parents=True)
            image = custom / 'assets' / 'card.png'
            image.write_bytes(b'test')
            with patch.object(runtime_paths, 'CATALOG_PATH', custom / 'historias.json'), patch.object(runtime_paths, 'BUNDLE_DIR', bundle):
                self.assertEqual(runtime_paths.image_path('assets/card.png'), image)
                self.assertEqual(runtime_paths.image_path('assets/other.png'), bundle / 'assets/other.png')
