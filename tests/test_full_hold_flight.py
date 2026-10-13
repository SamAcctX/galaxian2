"""Android second mining flight proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from unittest.mock import patch
from gof2_content import full_hold_flight as reader

DEPARTURE, FIRST = {'scope': 'full_hold_station_departure'}, {'scope': 'first_mining_flight_construction'}
ACTORS = {'npc_initialization': {'construction': {'x': 1}, 'routes': {'x': 1}, 'world_initialization': {'x': 1}}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidFullHoldFlightTests(unittest.TestCase):
    def extract(self, lib, departure=DEPARTURE, first=FIRST, actors=ACTORS):
        return reader.extract_full_hold_flight(lib, {}, departure, first, actors)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        # Synthetic layouts hold no vtables; the slot is tested below.
        with patch.object(reader, 'ANDROID_VTABLES', {}):
            with roomy_layouts():
                verify_android_proof(self, reader, self.extract, values='VALUES')
                image, layout, _ = layout_library(reader.ANDROID)
            with patch.object(reader, 'ANDROID', layout):
                lib = AndroidLibrary(image)
                data = self.extract(lib)
                data['weapon_item_sequence'].append(1)
                self.assertEqual(reader.VALUES['weapon_item_sequence'], [0, 19])
                initial = ACTORS['npc_initialization']
                cases = {'other departure': dict(departure={'scope': 'first_station_departure'}), 'no departure': dict(departure={}),
                         'none': dict(departure=None), 'other first': dict(first={'scope': 'x'}), 'no first': dict(first={}),
                         'no routes': dict(actors={'npc_initialization': dict(initial, routes={})}),
                         'no construction': dict(actors={'npc_initialization': dict(initial, construction=None)}),
                         'no world': dict(actors={'npc_initialization': {k: v for k, v in initial.items() if k != 'world_initialization'}}),
                         'no initialization': dict(actors={}), 'bad initialization': dict(actors={'npc_initialization': None})}
                for name, changes in cases.items():
                    self.assertEqual(self.extract(lib, **changes), {}, name)
                # The vtable slot joins the provenance.
                slot = {'placement_virtual': {'offset': 1, 'bytes': 4, 'anchor': 0}}
                with patch.object(reader, 'vtable_proof', lambda lib, rows: slot):
                    self.assertEqual(self.extract(lib)['provenance']['placement_virtual'], slot['placement_virtual'])
        # The code spans alone are not enough: the vtable slot must hold PlayerFighter::setPosition.
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(self.extract(AndroidLibrary(image)), {})

    def vtables(self, slot='_ZN13PlayerFighter11setPositionEfff'):
        from android_text_fixture import text_library
        lib, _ = text_library({slot: 'bx lr', '_ZN1X1yEv': 'bx lr'}, {'_ZTV13PlayerFighter': [0, 0] + [0] * 18 + [slot, 0]})
        return lib

    def test_vtable_slot(self):
        from gof2_content.android_shapes import objects
        from gof2_content.declaration_layouts import data_bytes
        lib = self.vtables()
        anchor = data_bytes(lib, objects(lib)['_ZTV13PlayerFighter'], 4)[1]
        self.assertEqual(reader.vtable_proof(lib, reader.ANDROID_VTABLES), {'placement_virtual': {'offset': anchor + 8 + 4 * 18, 'bytes': 4, 'anchor': anchor}})
        self.assertIsNone(reader.vtable_proof(self.vtables('_ZN1X1yEv'), reader.ANDROID_VTABLES))

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.VALUES
        entry, = struct.unpack('<H', bytes.fromhex(rows['actor_entry'][3]))
        self.assertEqual(((rows['actor_entry'][1] - 566) // 2, 566 + 2 * entry), (values['campaign_cursor'], rows['actor_case'][1]))
        code = thumb(rows['actor_case'][3])
        self.assertIn(('movs', 'r1, #%d' % values['actor_kind']), code)
        self.assertIn(('movs', 'r3, #%d' % values['hull_catalogue_id']), code)
        low = int(next(op for m, op in code if m == 'movw' and op.startswith('r3,')).split('#')[1], 0)
        high = int(next(op for m, op in code if m == 'movt' and op.startswith('r3,')).split('#')[1], 0)
        self.assertEqual(struct.unpack('<f', struct.pack('<I', high << 16 | low))[0], values['actor_position'][2])
        self.assertIn(('movs', 'r0, #%d' % values['actor_mode']), thumb(rows['inactive_mode'][3]))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        layout = {**reader.ANDROID, **{k: (t, 8 + 4 * first, 4 * len(n), '00') for k, (t, first, n) in reader.ANDROID_VTABLES.items()}}
        with patch.object(reader, 'ANDROID', layout):
            assert_native_android(self, reader, 'full_hold_flight_definitions.gd', values='VALUES')
