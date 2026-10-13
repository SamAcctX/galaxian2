"""Android combat-training construction proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from unittest.mock import patch
from gof2_content import combat_training as reader

EQUIPMENT = {'scope': 'var_hastra_equipment_tutorial'}
ACTORS = {'npc_initialization': {'construction': {'x': 1}, 'routes': {'x': 1}, 'world_initialization': {'x': 1}}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidCombatTrainingTests(unittest.TestCase):
    def extract(self, lib, equipment=EQUIPMENT, actors=ACTORS):
        return reader.extract_combat_training(lib, {}, equipment, actors)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        # Synthetic layouts hold no vtables; the slot is tested below.
        with patch.object(reader, 'ANDROID_VTABLES', {}):
            with roomy_layouts():
                verify_android_proof(self, reader, self.extract, values='MAC_VALUES')
                image, layout, _ = layout_library(reader.ANDROID)
            with patch.object(reader, 'ANDROID', layout):
                lib = AndroidLibrary(image)
                data = self.extract(lib)
                data['waypoints'][0].append(1)
                self.assertEqual(reader.MAC_VALUES['waypoints'][0], [-4000, -3000, 80000])
                initial = ACTORS['npc_initialization']
                cases = {'other equipment': dict(equipment={'scope': 'full_hold_station_return'}), 'no equipment': dict(equipment={}),
                         'none': dict(equipment=None), 'no routes': dict(actors={'npc_initialization': dict(initial, routes={})}),
                         'no construction': dict(actors={'npc_initialization': dict(initial, construction=None)}),
                         'no world': dict(actors={'npc_initialization': {k: v for k, v in initial.items() if k != 'world_initialization'}}),
                         'no initialization': dict(actors={}), 'bad initialization': dict(actors={'npc_initialization': None})}
                for name, changes in cases.items():
                    self.assertEqual(self.extract(lib, **changes), {}, name)
                slot = {'placement_virtual': {'offset': 1, 'bytes': 4, 'anchor': 0}}
                with patch.object(reader, 'vtable_proof', lambda lib, rows: slot):
                    self.assertEqual(self.extract(lib)['provenance']['placement_virtual'], slot['placement_virtual'])
        # The code spans alone are not enough: the vtable slot must hold PlayerFighter::setPosition.
        with roomy_layouts():
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.recognize_symbols(lib, layout))
            self.assertEqual(self.extract(lib), {})

    def test_vtable_slot(self):
        from android_text_fixture import text_library
        slot = '_ZN13PlayerFighter11setPositionEfff'
        lib, _ = text_library({slot: 'bx lr', '_ZN1X1yEv': 'bx lr'}, {'_ZTV13PlayerFighter': [0, 0] + [0] * 18 + [slot, 0]})
        proof = reader.vtable_proof(lib, reader.ANDROID_VTABLES)
        self.assertEqual(proof['placement_virtual']['offset'] - proof['placement_virtual']['anchor'], 8 + 4 * 18)
        lib, _ = text_library({slot: 'bx lr', '_ZN1X1yEv': 'bx lr'}, {'_ZTV13PlayerFighter': [0, 0] + [0] * 18 + ['_ZN1X1yEv', 0]})
        self.assertIsNone(reader.vtable_proof(lib, reader.ANDROID_VTABLES))

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.MAC_VALUES
        entry, = struct.unpack('<H', bytes.fromhex(rows['actor_entry'][3]))
        self.assertEqual(((rows['actor_entry'][1] - 566) // 2, 566 + 2 * entry), (values['campaign_cursor'], rows['actor_case'][1]))
        self.assertEqual(struct.unpack('<6i', bytes.fromhex(rows['waypoints'][3])), tuple(sum(values['waypoints'], [])))
        self.assertEqual(list(struct.unpack('<3f', bytes.fromhex(rows['companion_offset'][3]))), values['companion_position_offset'])
        effects = struct.unpack('<26i', bytes.fromhex(rows['weapon_effects'][3]))
        self.assertEqual([effects[i] for i in values['weapon_item_sequence']], values['weapon_effect_sequence'])
        self.assertEqual([effects[i] for i in values['companion_weapon_item_sequence']], values['companion_weapon_effect_sequence'])
        self.assertIn(('movs', 'r0, #%d' % values['pirate_mode']), thumb(rows['inactive_mode'][3]))
        self.assertEqual(thumb(rows['friendly'][3])[0], ('strb.w', 'r1, [r0, #0xed]'))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        layout = {**reader.ANDROID, **{k: (t, 8 + 4 * first, 4 * len(n), '00') for k, (t, first, n) in reader.ANDROID_VTABLES.items()}}
        with patch.object(reader, 'ANDROID', layout):
            assert_native_android(self, reader, 'combat_training_definitions.gd', values='MAC_VALUES')
