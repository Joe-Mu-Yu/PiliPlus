import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/prefetch_native_dependencies.py'
SPEC = importlib.util.spec_from_file_location('prefetch_native_dependencies', SCRIPT)
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


class PrefetchNativeDependenciesTest(unittest.TestCase):
    def test_github_api_downloads_use_the_ephemeral_workflow_token(self):
        with mock.patch.dict(
            MODULE.os.environ,
            {'GITHUB_TOKEN': ''.join(('unit', '-', 'test'))},
            clear=True,
        ):
            api_headers = MODULE.download_headers(
                'https://api.github.com/repos/example/project/releases/assets/1'
            )
            release_headers = MODULE.download_headers(
                'https://github.com/example/project/releases/download/v1/file.zip'
            )

        self.assertEqual(
            api_headers['Authorization'],
            'Bearer unit-test',
        )
        self.assertEqual(api_headers['X-GitHub-Api-Version'], '2022-11-28')
        self.assertNotIn('Authorization', release_headers)

    def test_cross_host_asset_redirect_drops_authorization(self):
        request = MODULE.Request(
            'https://api.github.com/repos/example/project/releases/assets/1',
            headers={'Authorization': 'Bearer unit-test'},
        )
        redirected = MODULE.SafeAuthorizationRedirectHandler().redirect_request(
            request,
            None,
            302,
            'Found',
            {},
            'https://release-assets.githubusercontent.com/download/file.zip',
        )

        self.assertIsNotNone(redirected)
        self.assertIsNone(redirected.get_header('Authorization'))

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

    def test_ffmpeg_dependencies_pin_linux_and_android_hashes(self):
        destinations = {
            str(destination): checksum
            for _url, checksum, destination in MODULE.FFMPEG_DEPENDENCIES
        }
        self.assertEqual(
            set(destinations),
            {
                'linux/bundle-base-linux-x86_64-shared-lgpl.zip',
                'android/bundle-base-shared-lgpl-release.aar',
            },
        )
        self.assertTrue(all(len(checksum) == 64 for checksum in destinations.values()))

    def test_media_kit_asset_api_covers_all_android_abis(self):
        self.assertEqual(
            set(MODULE.MEDIA_KIT_ASSET_URLS),
            {
                'default-arm64-v8a.jar',
                'default-armeabi-v7a.jar',
                'default-x86_64.jar',
            },
        )
        self.assertTrue(
            all('/releases/assets/' in url for url in MODULE.MEDIA_KIT_ASSET_URLS.values())
        )

    def test_sqlite_dependencies_pin_test_host_and_android_abis(self):
        destinations = {
            str(destination): checksum
            for _url, checksum, destination in MODULE.SQLITE_DEPENDENCIES
        }
        self.assertEqual(
            set(destinations),
            {
                'download-3a800a4d/libsqlite3.so',
                'download-b372f69d/libsqlite3.so',
                'download-d9cd44fa/libsqlite3.so',
                'download-1ff25026/libsqlite3.so',
            },
        )
        self.assertTrue(all(len(checksum) == 64 for checksum in destinations.values()))


if __name__ == '__main__':
    unittest.main()
