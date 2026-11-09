#!/usr/bin/env python3
"""Download CI native binaries with retries and SHA-256 checks."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import time
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urlparse
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
MEDIA_KIT_PACKAGE = 'media_kit_libs_android_video'
DEPENDENCY_PATTERN = re.compile(
    r'\["url": "(?P<url>https://[^"]+)", '
    r'"sha256": "(?P<sha256>[0-9a-f]{64})", '
    r'"destination": file\("\$buildDir/(?P<destination>[^"]+)"\)\]'
)
FFMPEG_DEPENDENCIES = (
    (
        'https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/'
        'v0.11.1-android/bundle-base-shared-lgpl-release.aar',
        'b214c2aafb20af5416989600826b2b7cb59c8f1572fb78547cc4a222b65134fc',
        Path('android/bundle-base-shared-lgpl-release.aar'),
    ),
)


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
            request = Request(url, headers={'User-Agent': 'Hyper-PiliPlus-Android-CI'})
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

    for url, expected_sha256, relative_destination in dependencies:
        destination = (build_directory / relative_destination).resolve()
        if not destination.is_relative_to(build_directory.resolve()):
            raise ValueError(f'Invalid media_kit destination: {relative_destination}')
        download_verified(url, expected_sha256, destination)


def main() -> None:
    prefetch_ffmpeg()
    prefetch_media_kit()


if __name__ == '__main__':
    main()
