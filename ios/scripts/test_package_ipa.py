#!/usr/bin/env python3
"""Offline publication regression checks; these do not run an iOS app."""
import unittest
from package_ipa import validate_info


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.info = {'DTPlatformName': 'iphoneos', 'CFBundleSupportedPlatforms': ['iPhoneOS'],
                     'CFBundleIdentifier': 'com.ningso.aps.ios', 'CFBundleShortVersionString': '1.0.0',
                     'CFBundleExecutable': 'APS'}

    def test_device_metadata(self):
        validate_info(self.info)

    def test_simulator_is_rejected(self):
        self.info['DTPlatformName'] = 'iphonesimulator'
        with self.assertRaises(AssertionError):
            validate_info(self.info)

    def test_wrong_platform_is_rejected(self):
        self.info['CFBundleSupportedPlatforms'] = ['iPhoneSimulator']
        with self.assertRaises(AssertionError):
            validate_info(self.info)

    def test_wrong_app_is_rejected(self):
        self.info['CFBundleIdentifier'] = 'com.example.other'
        with self.assertRaises(AssertionError):
            validate_info(self.info)

    def test_invalid_version_is_rejected(self):
        self.info['CFBundleShortVersionString'] = '../invalid'
        with self.assertRaises(AssertionError):
            validate_info(self.info)


if __name__ == '__main__':
    unittest.main()
