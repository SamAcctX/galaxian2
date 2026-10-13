"""Android second-trip pirate appearance proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from unittest.mock import patch
from gof2_content import full_hold_appearance as reader

STORY, DEATH = {'scope': 'full_hold_mining_story'}, {'scope': 'full_hold_pirate_destruction'}
NAMES = ['_ZN13PlayerFighter12setShipGroupEP10AEGeometryib', '_ZN13PlayerFighter5awakeEv', '_ZN13PlayerFighter11setPositionEfff']


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidFullHoldAppearanceTests(unittest.TestCase):
    def extract(self, lib, story=STORY, death=DEATH):
        return reader.extract_full_hold_appearance(lib, {}, story, death)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with patch.object(reader, 'ANDROID_VTABLES', {}):
            with roomy_layouts():
                verify_android_proof(self, reader, self.extract, values='VALUES')
                image, layout, _ = layout_library(reader.ANDROID)
            with patch.object(reader, 'ANDROID', layout):
                lib = AndroidLibrary(image)
                for name, changes in {'other story': dict(story={'scope': 'x'}), 'no story': dict(story={}), 'none': dict(story=None),
                                      'other death': dict(death={'scope': 'x'}), 'no death': dict(death={})}.items():
                    self.assertEqual(self.extract(lib, **changes), {}, name)
                slot = {'placement_virtual': {'offset': 1, 'bytes': 4, 'anchor': 0}}
                with patch.object(reader, 'vtable_proof', lambda lib, rows: slot):
                    self.assertEqual(self.extract(lib)['provenance']['placement_virtual'], slot['placement_virtual'])
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(self.extract(AndroidLibrary(image)), {})

    def test_vtable_slots(self):
        from android_text_fixture import text_library
        table = [0, 0, 0, 0, NAMES[0], NAMES[1]] + [0] * 14 + [NAMES[2], 0]
        lib, _ = text_library({n: 'bx lr' for n in NAMES}, {'_ZTV13PlayerFighter': table})
        proof = reader.vtable_proof(lib, reader.ANDROID_VTABLES)
        self.assertEqual({k: (v['offset'] - v['anchor'], v['bytes']) for k, v in proof.items()}, {'model_install_virtual': (16, 8), 'placement_virtual': (80, 4)})
        swapped = [0, 0, 0, 0, NAMES[1], NAMES[0]] + [0] * 14 + [NAMES[2], 0]
        lib, _ = text_library({n: 'bx lr' for n in NAMES}, {'_ZTV13PlayerFighter': swapped})
        self.assertIsNone(reader.vtable_proof(lib, reader.ANDROID_VTABLES))

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.VALUES
        x, z = struct.unpack('<2f', bytes.fromhex(rows['offsets'][3]))
        self.assertEqual([x, 0, z], values['offset'])
        yaw = thumb(rows['yaw'][3])
        low, high = int(yaw[0][1].split('#')[1], 0), int(yaw[1][1].split('#')[1], 0)
        self.assertEqual(struct.unpack('<f', struct.pack('<I', high << 16 | low))[0], values['yaw_radians'])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        layout = {**reader.ANDROID, **{k: (t, 8 + 4 * first, 4 * len(n), '00') for k, (t, first, n) in reader.ANDROID_VTABLES.items()}}
        with patch.object(reader, 'ANDROID', layout):
            assert_native_android(self, reader, 'full_hold_appearance_definitions.gd', values='VALUES')
