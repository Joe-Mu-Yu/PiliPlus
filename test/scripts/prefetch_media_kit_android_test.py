import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/prefetch_media_kit_android.py'
SPEC = importlib.util.spec_from_file_location('prefetch_media_kit_android', SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class _Response:
    def __init__(self, content):
        self.content = content
        self.offset = 0

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self, size):
        chunk = self.content[self.offset:self.offset + size]
        self.offset += len(chunk)
        return chunk


class PrefetchMediaKitAndroidTest(unittest.TestCase):
    def test_parse_dependencies_uses_upstream_urls_and_checksums(self):
        checksum = 'a' * 64
        with tempfile.TemporaryDirectory() as directory:
            build_file = Path(directory) / 'build.gradle'
            build_file.write_text(
                '["url": "https://example.test/default.jar", '
                f'"sha256": "{checksum}", '
                '"destination": file("$buildDir/release/default.jar")]'
            )

            self.assertEqual(
                MODULE.parse_dependencies(build_file),
                [('https://example.test/default.jar', checksum, Path('release/default.jar'))],
            )

    def test_download_retries_then_atomically_installs_verified_file(self):
        content = b'verified native library'
        checksum = hashlib.sha256(content).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / 'default.jar'
            with (
                mock.patch.object(
                    MODULE,
                    'urlopen',
                    side_effect=[MODULE.URLError('temporary 504'), _Response(content)],
                ) as opener,
                mock.patch.object(MODULE.time, 'sleep') as sleep,
            ):
                MODULE.download_verified(
                    'https://example.test/default.jar',
                    checksum,
                    destination,
                    attempts=2,
                )

            self.assertEqual(destination.read_bytes(), content)
            self.assertFalse(destination.with_suffix('.jar.part').exists())
            self.assertEqual(opener.call_count, 2)
            sleep.assert_called_once_with(5)

    def test_verified_cached_file_skips_network(self):
        content = b'already cached'
        checksum = hashlib.sha256(content).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / 'default.jar'
            destination.write_bytes(content)
            with mock.patch.object(MODULE, 'urlopen') as opener:
                MODULE.download_verified(
                    'https://example.test/default.jar', checksum, destination
                )
            opener.assert_not_called()


if __name__ == '__main__':
    unittest.main()
