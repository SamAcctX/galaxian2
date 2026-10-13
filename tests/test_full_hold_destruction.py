"""Android second-trip pirate destruction proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import full_hold_destruction as reader

CONTROL = {'scope': 'full_hold_pirate_control'}
NPC = {k: {'x': 1} for k in ['destruction', 'death_accounting', 'construction']}


class AndroidFullHoldDestructionTests(unittest.TestCase):
    def extract(self, lib, control=CONTROL, npc=NPC):
        return reader.extract_full_hold_destruction(lib, {}, control, {'npc_initialization': npc})

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
            cases = {'other control': dict(control={'scope': 'x'}), 'no control': dict(control={}), 'none': dict(control=None),
                     'no npc': dict(npc=None), **{'no ' + k: dict(npc=dict(NPC, **{k: {}})) for k in NPC}}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.VALUES
        self.assertEqual(struct.unpack('<2f', bytes.fromhex(rows['drift_constants'][3])), (values['cargo_drift_decay'], values['cargo_drift_cutoff']))
        self.assertEqual(struct.unpack('<2f', bytes.fromhex(rows['angle_constants'][3])), (values['cargo_angle_fraction'], values['cargo_angle_tau']))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'full_hold_destruction_definitions.gd', values='VALUES')
