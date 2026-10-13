"""Mac 1.0.7 numbering for Android string tables."""
import unittest
from gof2_content import text_ids


class TextIdTests(unittest.TestCase):
    def test_android_table_reorders_into_mac_numbering(self):
        android = ['a%d' % i for i in range(text_ids.ANDROID_STRINGS)]
        mac = text_ids.canonical_strings(android)
        self.assertEqual(len(mac), text_ids.ANDROID_STRINGS)
        self.assertEqual(sorted(mac), sorted(android))  # a permutation
        # Insertions: one credit line before Mac 48, ten lines before Mac 188, five appended.
        for mac_id, android_id in ((0, 0), (47, 47), (48, 49), (187, 188), (188, 199), (3384, 3395)):
            self.assertEqual(mac[mac_id], 'a%d' % android_id)
            self.assertEqual(text_ids.android_id(mac_id), android_id)
            self.assertEqual(text_ids.canonical_id(android_id), mac_id)
        self.assertEqual(mac[3385:], ['a48'] + ['a%d' % i for i in range(189, 199)] + ['a%d' % i for i in range(3396, 3401)])
        self.assertEqual(text_ids.canonical_id(191), 3388)
        self.assertIsNone(text_ids.canonical_id(3401))

    def test_other_table_sizes_are_refused(self):
        for size in (3385, 3400, 3402):
            with self.assertRaises(ValueError):
                text_ids.canonical_strings(['x'] * size)


if __name__ == '__main__':
    unittest.main()
