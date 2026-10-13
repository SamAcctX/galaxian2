"""Android first-mining approach proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import mining_approach as reader


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidMiningApproachTests(unittest.TestCase):
    def extract(self, lib, targeting={'scope': 'first_mining_asteroid_selection'}):
        return reader.extract_mining_approach(lib, {}, targeting)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract, values='VALUES')
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            for name, targeting in {'other targeting': {'scope': 'first_mining_approach'}, 'no targeting': {}, 'none': None}.items():
                self.assertEqual(self.extract(lib, targeting), {}, name)

    def test_android_constants(self):
        values, rows = reader.VALUES, reader.ANDROID
        def floats(key): return list(struct.unpack('<%df' % (rows[key][2] // 4), bytes.fromhex(rows[key][3])))
        self.assertEqual(floats('stand_off_scale'), [values['stand_off_scale']])
        self.assertEqual(floats('tilt_limit'), [values['tilt_limit']])
        self.assertEqual(floats('response_add'), [values['response_add']])
        self.assertEqual(floats('turn_fraction'), [values['turn_fraction']])
        self.assertEqual(floats('alignment_constants'), [values['alignment_angle'], values['tilt_rate'], values['angle_fraction'], values['angle_tau']])
        # MatrixGetDir reads column 2 (bytes 8, 24, 40), MatrixGetUp column 1 (4, 20, 36).
        self.assertEqual(thumb(rows['matrix_forward'][3])[:3], [('ldr', 'r3, [r1, #0x18]'), ('ldr', 'r2, [r1, #%d]' % (4 * values['visual_forward_axis'])), ('ldr', 'r1, [r1, #0x28]')])
        self.assertEqual(thumb(rows['matrix_up'][3])[:3], [('ldr', 'r3, [r1, #0x14]'), ('ldr', 'r2, [r1, #%d]' % (4 * values['alignment_reference_axis'])), ('ldr', 'r1, [r1, #0x24]')])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'mining_approach_definitions.gd', values='VALUES')
