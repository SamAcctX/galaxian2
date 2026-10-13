"""Android asteroid selection proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import unittest
from gof2_content import mining_targeting as reader


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidMiningTargetingTests(unittest.TestCase):
    def extract(self, lib, flight={'scope': 'first_mining_flight_construction'}):
        return reader.extract_mining_targeting(lib, {}, flight)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract)
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            for name, flight in {'other flight': {'scope': 'first_station_departure'}, 'no flight': {}, 'none': None}.items():
                self.assertEqual(self.extract(lib, flight), {}, name)

    def test_android_values(self):
        # Only the window differs: Radar::Radar divides Globals::w by 16 (the Mac by 18).
        self.assertEqual({k for k in reader.VALUES if reader.VALUES[k] != reader.ANDROID_VALUES[k]}, {'window_divisor'})
        self.assertEqual(set(reader.ANDROID_VALUES), set(reader.VALUES))
        window = thumb(reader.ANDROID['window'][3])
        self.assertIn(('asrs', 'r6, r6, #4'), window)
        self.assertEqual(1 << 4, reader.ANDROID_VALUES['window_divisor'])
        self.assertEqual(window[-1], ('strd', 'r6, r2, [sl, #0x124]'))
        storage = thumb(reader.ANDROID['candidate_storage'][3])
        self.assertEqual(storage[5:8], [('movs', 'r0, #0x14'), ('blx', storage[6][1]), ('movs', 'r1, #0x14')])
        self.assertEqual(0x14 // 4, reader.ANDROID_VALUES['candidate_slots'])
        size = thumb(reader.ANDROID['mineable_size'][3])
        self.assertEqual(size[1:3], [('cmp', 'r6, #%d' % (reader.ANDROID_VALUES['mineable_size_min'] - 1)), ('it', 'gt')])
        self.assertIn(('cmp', 'r1, #4'), thumb(reader.ANDROID['retired_accessor'][3]))
        self.assertIn(('cmp', 'r1, #3'), thumb(reader.ANDROID['destruction_accessor'][3]))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'mining_targeting_definitions.gd')
