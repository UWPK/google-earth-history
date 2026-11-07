import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('setup_skill', Path(__file__).parents[1] / 'scripts/setup.py')
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)

class PlatformSelection(unittest.TestCase):
    def test_platform_assets(self):
        assets = [{'name': 'GEHistoricalImagery.0.7.1-' + x} for x in
                  ['macOS-arm64.dmg', 'macOS-x64.dmg', 'win-x64.zip']]
        for system, cpu, expected in [('Darwin','arm64','macOS-arm64.dmg'),
                                      ('Darwin','x86_64','macOS-x64.dmg'),
                                      ('Windows','AMD64','win-x64.zip')]:
            self.assertTrue(setup.select_asset(assets, system, cpu)['name'].endswith(expected))
        with self.assertRaises(RuntimeError):
            setup.select_asset(assets, 'Windows', 'ARM64')
        with self.assertRaises(RuntimeError):
            setup.select_asset([], 'Darwin', 'arm64')

if __name__ == '__main__':
    unittest.main()
