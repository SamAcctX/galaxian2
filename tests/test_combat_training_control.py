"""Android combat-training control proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import unittest
from unittest.mock import patch
from gof2_content import combat_training_control as reader

TRAINING = {'scope': 'combat_training_encounter_construction'}
NPC = {'guidance': {'x': 1}, 'flight': {'x': 1}, 'routes': {'x': 1}, 'hull': {'x': 1}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidCombatTrainingControlTests(unittest.TestCase):
    def extract(self, lib, training=TRAINING, npc=NPC):
        return reader.extract_combat_training_control(lib, {}, training, {'npc_initialization': npc})

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
                data = self.extract(lib)
                data['target_memberships'][0].append(1)
                self.assertEqual(reader.VALUES['target_memberships'][0], [-1, 3])
                cases = {'other training': dict(training={'scope': 'full_hold_pirate_combat'}), 'no training': dict(training={}),
                         'none': dict(training=None), 'no guidance': dict(npc=dict(NPC, guidance={})),
                         'no flight': dict(npc=dict(NPC, flight=None)), 'no routes': dict(npc={k: v for k, v in NPC.items() if k != 'routes'}),
                         'no hull': dict(npc=dict(NPC, hull={})), 'bad npc': dict(npc=None)}
                for name, changes in cases.items():
                    self.assertEqual(self.extract(lib, **changes), {}, name)
                slot = {'npc_model_vtable': {'offset': 1, 'bytes': 4, 'anchor': 0}}
                with patch.object(reader, 'vtable_proof', lambda lib, rows: slot):
                    self.assertEqual(self.extract(lib)['provenance']['npc_model_vtable'], slot['npc_model_vtable'])
        # The code spans alone are not enough: slot 2 must hold PlayerFighter::setShipGroup.
        with roomy_layouts():
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.recognize_symbols(lib, layout))
            self.assertEqual(self.extract(lib), {})

    def test_vtable_slot(self):
        from android_text_fixture import text_library
        name = '_ZN13PlayerFighter12setShipGroupEP10AEGeometryib'
        lib, _ = text_library({name: 'bx lr', '_ZN1X1yEv': 'bx lr'}, {'_ZTV13PlayerFighter': [0, 0, 0, 0, name, 0]})
        proof = reader.vtable_proof(lib, reader.ANDROID_VTABLES)
        self.assertEqual(proof['npc_model_vtable']['offset'] - proof['npc_model_vtable']['anchor'], 8 + 4 * 2)
        lib, _ = text_library({name: 'bx lr', '_ZN1X1yEv': 'bx lr'}, {'_ZTV13PlayerFighter': [0, 0, 0, name, 0, 0]})
        self.assertIsNone(reader.vtable_proof(lib, reader.ANDROID_VTABLES))

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.VALUES
        # setBoostProb(0) on actor 3 ([actors + 0xc]).
        code = thumb(rows['companion_boost'][3])
        self.assertIn(('movs', 'r1, #%d' % values['companion_boost_chance']), code)
        self.assertIn(('ldr', 'r0, [r0, #0xc]'), code)
        self.assertEqual(thumb(rows['boost_chance'][3])[0], ('str.w', 'r1, [r0, #0x1b0]'))
        self.assertEqual(thumb(rows['friendly_test'][3])[0], ('ldrb.w', 'r0, [r0, #0xed]'))
        self.assertEqual(thumb(rows['attached_test'][3])[0], ('ldrb.w', 'r0, [r0, #0xd8]'))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        layout = {**reader.ANDROID, **{k: (t, 8 + 4 * first, 4 * len(n), '00') for k, (t, first, n) in reader.ANDROID_VTABLES.items()}}
        with patch.object(reader, 'ANDROID', layout):
            assert_native_android(self, reader, 'combat_training_control_definitions.gd', values='VALUES')
