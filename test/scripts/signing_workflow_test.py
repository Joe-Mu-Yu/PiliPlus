import base64
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/android-release.yml'
REQUIRED = (
    'SIGN_KEYSTORE_BASE64', 'KEYSTORE_PASSWORD', 'KEY_ALIAS', 'KEY_PASSWORD',
)
FIREBASE_REQUIRED = (
    'HYPER_FIREBASE_ANDROID_API_KEY',
    'PURE_LIVE_FIREBASE_ANDROID_API_KEY',
)


class SigningWorkflowTest(unittest.TestCase):
    def setUp(self):
        self.workflow = WORKFLOW.read_text()
        self.step, self.command = self.extract_step('Validate release signing secrets')
        self.firebase_step, self.firebase_command = self.extract_step(
            'Validate Android Firebase configuration secrets',
        )
        self.decode_step, self.decode_command = self.extract_step('Decode signing keystore')

    def extract_step(self, name):
        match = re.search(
            r'^      - name: ' + re.escape(name) + r'\n'
            r'(.*?)(?=^      - |\Z)',
            self.workflow, re.MULTILINE | re.DOTALL,
        )
        self.assertIsNotNone(match)
        step = match.group(0)
        command = (
            textwrap.dedent(step.split('        run: |\n', 1)[1])
            if '        run: |\n' in step
            else ''
        )
        return step, command

    def run_step(self, supplied, command=None):
        with tempfile.TemporaryDirectory() as temporary:
            environment = {
                **{
                    name: value
                    for name, value in os.environ.items()
                    if name not in REQUIRED + FIREBASE_REQUIRED
                },
                'RUNNER_TEMP': temporary,
                'GITHUB_REPOSITORY': 'Joe-Mu-Yu/PiliPlus',
                'GITHUB_SERVER_URL': 'https://github.com',
                **supplied,
            }
            result = subprocess.run(
                ['bash', '-c', command or self.command], env=environment,
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(list(Path(temporary).iterdir()))
            return result.stdout + result.stderr

    def test_reports_all_missing_secrets_with_repair_instructions(self):
        output = self.run_step({})
        for name in REQUIRED:
            self.assertIn(name, output)
        self.assertIn('::error', output)
        self.assertIn('Settings', output)
        self.assertIn('secrets: inherit', output)
        self.assertNotIn('Traceback', output)

    def test_each_missing_secret_fails_without_printing_other_values(self):
        for missing in REQUIRED:
            with self.subTest(missing=missing):
                supplied = {
                    name: 'private-placeholder-' + name
                    for name in REQUIRED if name != missing
                }
                output = self.run_step(supplied)
                self.assertIn(missing, output)
                self.assertIn('::error', output)
                for value in supplied.values():
                    self.assertNotIn(value, output)

    def test_invalid_base64_has_safe_actionable_error(self):
        supplied = {name: 'private-placeholder-' + name for name in REQUIRED}
        output = self.run_step(supplied, self.decode_command)
        self.assertIn('::error', output)
        self.assertIn('SIGN_KEYSTORE_BASE64', output)
        self.assertIn('Base64', output)
        self.assertNotIn('Traceback', output)
        for value in supplied.values():
            self.assertNotIn(value, output)

    def test_whitespace_base64_is_rejected_without_creating_a_file(self):
        supplied = {name: 'private-placeholder-' + name for name in REQUIRED}
        supplied['SIGN_KEYSTORE_BASE64'] = ' \n\t '
        output = self.run_step(supplied, self.decode_command)
        self.assertIn('::error', output)
        self.assertIn('Empty signing keystore', output)
        self.assertNotIn('Traceback', output)

    def test_decoder_preserves_bytes_and_uses_private_file_permissions(self):
        payload = b'ordinary decoder test data, not a signing key'
        encoded = base64.b64encode(payload).decode()
        with tempfile.TemporaryDirectory() as temporary:
            result = subprocess.run(
                ['bash', '-c', self.decode_command],
                env={
                    **os.environ,
                    'RUNNER_TEMP': temporary,
                    'SIGN_KEYSTORE_BASE64': encoded,
                },
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            path = Path(temporary) / 'hyper-release.jks'
            self.assertEqual(path.read_bytes(), payload)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertNotIn(encoded, result.stdout + result.stderr)
            self.assertNotIn(payload.decode(), result.stdout + result.stderr)

    def test_signing_check_precedes_sdk_and_dependency_setup(self):
        self.assertLess(
            self.workflow.index(self.step),
            self.workflow.index('      - name: Resolve flavor version'),
        )
        self.assertLess(
            self.workflow.index(self.step),
            self.workflow.index('      - name: Set up Java'),
        )
        self.assertGreater(
            self.workflow.index(self.decode_step),
            self.workflow.index('      - name: Test release metadata and app'),
        )

    def test_firebase_check_reports_only_missing_secret_names(self):
        for missing in FIREBASE_REQUIRED:
            with self.subTest(missing=missing):
                supplied = {
                    name: 'private-placeholder-' + name
                    for name in FIREBASE_REQUIRED if name != missing
                }
                output = self.run_step(supplied, self.firebase_command)
                self.assertIn(missing, output)
                self.assertIn('::error', output)
                self.assertIn('Do not commit', output)
                for value in supplied.values():
                    self.assertNotIn(value, output)

    def test_android_build_injects_only_android_firebase_keys(self):
        build_step, _ = self.extract_step('Build signed APKs')
        for name in FIREBASE_REQUIRED:
            self.assertIn('${{ secrets.' + name + ' }}', build_step)
            self.assertIn('--dart-define=' + name, build_step)
        self.assertNotIn('PURE_LIVE_FIREBASE_APPLE_API_KEY', build_step)
        self.assertNotIn('PURE_LIVE_FIREBASE_WINDOWS_API_KEY', build_step)

    def test_firebase_check_precedes_sdk_and_dependency_setup(self):
        self.assertLess(
            self.workflow.index(self.firebase_step),
            self.workflow.index('      - name: Resolve flavor version'),
        )
        self.assertLess(
            self.workflow.index(self.firebase_step),
            self.workflow.index('      - name: Set up Java'),
        )


if __name__ == '__main__':
    unittest.main()
