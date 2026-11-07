from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class FirebaseRetirementTest(unittest.TestCase):
    def test_runtime_dependencies_do_not_include_firebase(self):
        manifests = (
            ROOT / 'pubspec.yaml',
            ROOT / 'third_party/pure_live/pubspec.yaml',
        )
        for manifest in manifests:
            with self.subTest(manifest=manifest):
                content = manifest.read_text().lower()
                self.assertNotIn('firebase_', content)
                self.assertNotIn('cloud_firestore', content)

    def test_removed_firebase_runtime_and_platform_files_stay_absent(self):
        retired = (
            '.firebaserc',
            'firebase.json',
            'firestore.rules',
            'lib/firebase_options.dart',
            'lib/services/private_device_services.dart',
            'third_party/pure_live/lib/firebase_options.dart',
            '.github/workflows/firebase-broadcast.yml',
            'scripts/firebase_broadcast.mjs',
        )
        for relative_path in retired:
            with self.subTest(path=relative_path):
                self.assertFalse((ROOT / relative_path).exists())
        auth_directory = ROOT / 'third_party/pure_live/lib/modules/auth'
        self.assertEqual(list(auth_directory.rglob('*.dart')), [])

    def test_android_release_does_not_require_firebase_defines(self):
        workflow = (ROOT / '.github/workflows/android-release.yml').read_text()
        self.assertNotIn('FIREBASE', workflow.upper())
        self.assertNotRegex(workflow, r'--dart-define=[^\s]*FIREBASE')


if __name__ == '__main__':
    unittest.main()
