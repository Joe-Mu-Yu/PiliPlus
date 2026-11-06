import re
import subprocess
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
GOOGLE_API_KEY = re.compile(rb'AI' rb'za[0-9A-Za-z_-]{20,}')


class CredentialHygieneTest(unittest.TestCase):
    def test_tracked_files_do_not_contain_google_api_key_literals(self):
        tracked = subprocess.check_output(
            ['git', 'ls-files', '-z'], cwd=ROOT,
        ).split(b'\0')
        leaked_paths = []
        for raw_path in tracked:
            if not raw_path:
                continue
            path = ROOT / raw_path.decode()
            if path.is_file() and GOOGLE_API_KEY.search(path.read_bytes()):
                leaked_paths.append(str(path.relative_to(ROOT)))
        self.assertEqual(
            leaked_paths,
            [],
            'Google API key literals found in tracked files: '
            + ', '.join(leaked_paths),
        )

    def test_google_services_json_is_not_present(self):
        self.assertFalse((ROOT / 'android/app/google-services.json').exists())


if __name__ == '__main__':
    unittest.main()
