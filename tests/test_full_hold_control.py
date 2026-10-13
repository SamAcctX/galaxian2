"""Android second-trip NPC control proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import unittest
from gof2_content import full_hold_control as reader

PIRATE = {'scope': 'full_hold_pirate_combat'}
NPC = {k: {'x': 1} for k in ['guidance', 'flight', 'holding', 'routes', 'construction', 'hostility']}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidFullHoldControlTests(unittest.TestCase):
    def extract(self, lib, pirate=PIRATE, npc=NPC):
        return reader.extract_full_hold_control(lib, {}, pirate, {'npc_initialization': npc})

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
            cases = {'other pirate': dict(pirate={'scope': 'full_hold_pirate'}), 'no pirate': dict(pirate={}), 'none': dict(pirate=None),
                     'no npc': dict(npc=None), **{'no ' + k: dict(npc=dict(NPC, **{k: {}})) for k in NPC}}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_helpers(self):
        rows = reader.ANDROID
        # PlayerEgo::isInRocketControl tests the rocket, getTargetFollowCamera returns the camera, getTarget its target.
        self.assertEqual(thumb(rows['alternate_body_test'][3])[1], ('cmp', 'r0, #0'))
        self.assertEqual(thumb(rows['model_request'][3])[0][0], 'strb.w')
        self.assertEqual(len(bytes.fromhex(rows['target_activity'][3])), 6)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'full_hold_control_definitions.gd', values='VALUES')
