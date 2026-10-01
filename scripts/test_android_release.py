import unittest
from publish_android import validate_apk

SIGNATURE = 'Verified using v2 scheme (APK Signature Scheme v2): true\nSigner #1 certificate SHA-256 digest: ' + 'a' * 64
VALID = "package: name='com.ningso.aps' versionCode='2' versionName='1.0.0'\nsdkVersion:'26'"

class ReleaseValidationTests(unittest.TestCase):
    def test_accepts_stable_release(self):
        self.assertEqual(validate_apk(VALID, SIGNATURE, '1.0.0', 2), 'a' * 64)
    def test_rejects_old_version(self):
        with self.assertRaises(ValueError): validate_apk(VALID.replace('1.0.0', '0.1.0-debug'), SIGNATURE, '1.0.0', 2)
    def test_rejects_debug_package(self):
        with self.assertRaises(ValueError): validate_apk(VALID.replace('com.ningso.aps', 'com.ningso.aps.debug'), SIGNATURE, '1.0.0', 2)
    def test_rejects_debuggable(self):
        with self.assertRaises(ValueError): validate_apk(VALID + '\napplication-debuggable', SIGNATURE, '1.0.0', 2)
    def test_rejects_debug_certificate(self):
        with self.assertRaises(ValueError): validate_apk(VALID, SIGNATURE + '\nCN=Android Debug', '1.0.0', 2)
    def test_rejects_missing_signature(self):
        with self.assertRaises(ValueError): validate_apk(VALID, '', '1.0.0', 2)
    def test_rejects_wrong_version_code(self):
        with self.assertRaises(ValueError): validate_apk(VALID, SIGNATURE, '1.0.0', 3)

if __name__ == '__main__': unittest.main()
