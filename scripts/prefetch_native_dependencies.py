#!/usr/bin/env python3
"""Download CI native binaries with retries and SHA-256 checks."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import time
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener


ROOT = Path(__file__).resolve().parents[1]
MEDIA_KIT_PACKAGE = 'media_kit_libs_android_video'
MEDIA_KIT_ASSET_URLS = {
    'default-arm64-v8a.jar': (
        'https://api.github.com/repos/My-Responsitories/'
        'libmpv-android-video-build/releases/assets/547100357'
    ),
    'default-armeabi-v7a.jar': (
        'https://api.github.com/repos/My-Responsitories/'
        'libmpv-android-video-build/releases/assets/547100358'
    ),
    'default-x86_64.jar': (
        'https://api.github.com/repos/My-Responsitories/'
        'libmpv-android-video-build/releases/assets/547100356'
    ),
}
DEPENDENCY_PATTERN = re.compile(
    r'\["url": "(?P<url>https://[^"]+)", '
    r'"sha256": "(?P<sha256>[0-9a-f]{64})", '
    r'"destination": file\("\$buildDir/(?P<destination>[^"]+)"\)\]'
)
FFMPEG_DEPENDENCIES = (
    (
        'https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/'
        'releases/assets/537133408',
        '08e005ef66d4f934dbd956a11b11caf34341fd2c717b67b7d84d70181894023c',
        Path('linux/bundle-base-linux-x86_64-shared-lgpl.zip'),
    ),
    (
        'https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/'
        'v0.11.1-android/bundle-base-shared-lgpl-release.aar',
        'b214c2aafb20af5416989600826b2b7cb59c8f1572fb78547cc4a222b65134fc',
        Path('android/bundle-base-shared-lgpl-release.aar'),
    ),
)
SQLITE_DEPENDENCIES = (
    (
        'https://api.github.com/repos/simolus3/sqlite3.dart/'
        'releases/assets/637354587',
        '3a800a4da3def29f85cef1e40f27c463f2842206593a8a60cfeb6d0a52435e70',
        Path('download-3a800a4d/libsqlite3.so'),
    ),
    (
        'https://api.github.com/repos/simolus3/sqlite3.dart/'
        'releases/assets/637354621',
        'b372f69dd455ad4c1b26015eb848acce7017cc7a95f8fb37b4962ddda70528ec',
        Path('download-b372f69d/libsqlite3.so'),
    ),
    (
        'https://api.github.com/repos/simolus3/sqlite3.dart/'
        'releases/assets/637354686',
        'd9cd44fadd4f856ee5e0980811364e651f69b93c418cb02ccfc433eb6df1b65d',
        Path('download-d9cd44fa/libsqlite3.so'),
    ),
    (
        'https://api.github.com/repos/simolus3/sqlite3.dart/'
        'releases/assets/637354701',
        '1ff25026f7bcd7e740f98d5b852ae6e79d2400c076f046096295f91a5b60aeb8',
        Path('download-1ff25026/libsqlite3.so'),
    ),
)


class SafeAuthorizationRedirectHandler(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, new_url):
        redirected = super().redirect_request(
            request,
            fp,
            code,
            msg,
            headers,
            new_url,
        )
        if (
            redirected is not None
            and urlparse(request.full_url).hostname != urlparse(new_url).hostname
        ):
            redirected.remove_header('Authorization')
        return redirected


urlopen = build_opener(SafeAuthorizationRedirectHandler()).open


def resolved_package_directory(package_config: Path, package_name: str) -> Path:
    packages = json.loads(package_config.read_text())['packages']
    package = next(item for item in packages if item['name'] == package_name)
    uri = urlparse(package['rootUri'])
    if uri.scheme not in ('', 'file'):
        raise ValueError(f'{package_name} must resolve to a local directory')
    return (package_config.parent / unquote(uri.path)).resolve()


def parse_dependencies(build_file: Path) -> list[tuple[str, str, Path]]:
    dependencies = [
        (match['url'], match['sha256'], Path(match['destination']))
        for match in DEPENDENCY_PATTERN.finditer(build_file.read_text())
    ]
    if not dependencies:
        raise ValueError(f'No verified media_kit downloads found in {build_file}')
    return dependencies


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def download_headers(url: str) -> dict[str, str]:
    headers = {
        'Accept': 'application/octet-stream',
        'User-Agent': 'Hyper-PiliPlus-Android-CI',
    }
    github_token = os.environ.get('GITHUB_TOKEN', '').strip()
    if github_token and urlparse(url).hostname == 'api.github.com':
        headers['Authorization'] = f'Bearer {github_token}'
        headers['X-GitHub-Api-Version'] = '2022-11-28'
    return headers


def download_verified(
    url: str,
    expected_sha256: str,
    destination: Path,
    *,
    attempts: int = 5,
    timeout: int = 120,
) -> None:
    if destination.exists() and sha256(destination) == expected_sha256:
        print(f'Using verified native binary: {destination.name}')
        return

    destination.unlink(missing_ok=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + '.part')

    for attempt in range(1, attempts + 1):
        temporary.unlink(missing_ok=True)
        try:
            request = Request(url, headers=download_headers(url))
            with urlopen(request, timeout=timeout) as response, temporary.open('wb') as output:
                while chunk := response.read(1024 * 1024):
                    output.write(chunk)
            actual_sha256 = sha256(temporary)
            if actual_sha256 != expected_sha256:
                raise ValueError(
                    f'SHA-256 mismatch for {destination.name}: {actual_sha256}'
                )
            temporary.replace(destination)
            print(f'Downloaded verified native binary: {destination.name}')
            return
        except (HTTPError, URLError, OSError, ValueError) as error:
            temporary.unlink(missing_ok=True)
            if attempt == attempts:
                raise RuntimeError(
                    f'Failed to download {destination.name} after {attempts} attempts'
                ) from error
            delay = attempt * 5
            print(
                f'Download attempt {attempt}/{attempts} failed for '
                f'{destination.name}: {error}; retrying in {delay}s'
            )
            time.sleep(delay)


def prefetch_ffmpeg() -> None:
    package_config = ROOT / '.dart_tool/package_config.json'
    package_directory = resolved_package_directory(
        package_config, 'ffmpeg_kit_extended_flutter'
    )
    hook_source = (package_directory / 'hook/build.dart').read_text()
    if 'const String version = "0.11.1";' not in hook_source:
        raise ValueError('Update pinned FFmpeg URLs and SHA-256 hashes for this package')

    cache_directory = (
        ROOT
        / '.dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter/build/'
        'ffmpeg_kit_cache'
    )
    for url, expected_sha256, relative_destination in FFMPEG_DEPENDENCIES:
        download_verified(
            url,
            expected_sha256,
            cache_directory / relative_destination,
        )


def prefetch_media_kit() -> None:
    package_config = ROOT / '.dart_tool/package_config.json'
    package_directory = resolved_package_directory(package_config, MEDIA_KIT_PACKAGE)
    dependencies = parse_dependencies(package_directory / 'android/build.gradle')
    build_directory = ROOT / 'build' / MEDIA_KIT_PACKAGE

    for _url, expected_sha256, relative_destination in dependencies:
        destination = (build_directory / relative_destination).resolve()
        if not destination.is_relative_to(build_directory.resolve()):
            raise ValueError(f'Invalid media_kit destination: {relative_destination}')
        asset_url = MEDIA_KIT_ASSET_URLS.get(destination.name)
        if asset_url is None:
            raise ValueError(f'Update the media_kit asset URL for {destination.name}')
        download_verified(asset_url, expected_sha256, destination)


def prefetch_sqlite() -> None:
    package_config = ROOT / '.dart_tool/package_config.json'
    package_directory = resolved_package_directory(package_config, 'sqlite3')
    hashes_source = (package_directory / 'lib/src/hook/asset_hashes.dart').read_text()
    if "const String? releaseTag = 'sqlite3-3.7.1';" not in hashes_source:
        raise ValueError('Update pinned SQLite asset URLs and SHA-256 hashes')

    cache_directory = ROOT / '.dart_tool/hooks_runner/shared/sqlite3/build'
    for url, expected_sha256, relative_destination in SQLITE_DEPENDENCIES:
        download_verified(
            url,
            expected_sha256,
            cache_directory / relative_destination,
        )


def main() -> None:
    prefetch_ffmpeg()
    prefetch_media_kit()
    prefetch_sqlite()


if __name__ == '__main__':
    main()
