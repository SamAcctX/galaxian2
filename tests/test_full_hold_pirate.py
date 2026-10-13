"""Android second-trip pirate proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from unittest.mock import patch
from gof2_content import full_hold_pirate as reader

FLIGHT = {'scope': 'full_hold_mining_flight_construction'}
NPC = {'hull': {'rank': 0}, 'guidance': {'x': 1}, 'holding': {'x': 1}, 'hostility': {'x': 1}, 'primary_weapon': {'x': 1}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidFullHoldPirateTests(unittest.TestCase):
    def extract(self, lib, flight=FLIGHT, npc=NPC, handoff={'x': 1}):
        return reader.extract_full_hold_pirate(lib, {}, flight, {'npc_initialization': npc}, handoff)

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
                data['primary_weapon']['actor_ids'].append(1)
                self.assertEqual(reader.VALUES['primary_weapon']['actor_ids'], [0])
                cases = {'other flight': dict(flight={'scope': 'first_mining_flight_construction'}), 'no flight': dict(flight={}),
                         'none': dict(flight=None), 'no handoff': dict(handoff={}), 'other rank': dict(npc=dict(NPC, hull={'rank': 1})),
                         'no guidance': dict(npc=dict(NPC, guidance={})), 'no weapon': dict(npc=dict(NPC, primary_weapon=None)),
                         'no holding': dict(npc={k: v for k, v in NPC.items() if k != 'holding'}), 'no hostility': dict(npc=dict(NPC, hostility={})),
                         'no npc': dict(npc=None)}
                for name, changes in cases.items():
                    self.assertEqual(self.extract(lib, **changes), {}, name)
                slot = {'placement_virtual': {'offset': 1, 'bytes': 4, 'anchor': 0}}
                with patch.object(reader, 'vtable_proof', lambda lib, rows: slot):
                    self.assertEqual(self.extract(lib)['provenance']['placement_virtual'], slot['placement_virtual'])
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(self.extract(AndroidLibrary(image)), {})

    def test_vtable_slots(self):
        from android_text_fixture import text_library
        names = ['_ZN13PlayerFighter11setPositionEfff', '_ZN13PlayerFighter5awakeEv']
        table = [0, 0] + [0] * 3 + [names[1]] + [0] * 14 + [names[0], 0]
        lib, _ = text_library({n: 'bx lr' for n in names}, {'_ZTV13PlayerFighter': table})
        proof = reader.vtable_proof(lib, reader.ANDROID_VTABLES)
        self.assertEqual({k: v['offset'] - v['anchor'] for k, v in proof.items()}, {'placement_virtual': 8 + 4 * 18, 'activation_virtual': 8 + 4 * 3})
        swapped = [0, 0] + [0] * 3 + [names[0]] + [0] * 14 + [names[1], 0]
        lib, _ = text_library({n: 'bx lr' for n in names}, {'_ZTV13PlayerFighter': swapped})
        self.assertIsNone(reader.vtable_proof(lib, reader.ANDROID_VTABLES))

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.VALUES
        x, z = struct.unpack('<2f', bytes.fromhex(rows['activation_offsets'][3]))
        self.assertEqual([x, 0, z], values['activation_offset'])
        self.assertEqual(struct.unpack('<2f', bytes.fromhex(rows['proximity_constants'][3])), (values['proximity_half_extent'], -values['proximity_half_extent']))
        code = thumb(rows['scripted_activation'][3])
        self.assertIn(('cmp', 'r0, #%d' % values['activation_cursor']), code)
        low = int(next(op for m, op in code if m == 'movw' and op.startswith('r2,')).split('#')[1], 0)
        high = int(next(op for m, op in code if m == 'movt' and op.startswith('r2,')).split('#')[1], 0)
        self.assertEqual(struct.unpack('<f', struct.pack('<I', high << 16 | low))[0], values['activation_yaw_radians'])
        self.assertEqual(code[-3:-1], [('movs', 'r0, #%d' % values['activation_phase_after']), ('str.w', 'r0, [sl, #0x1c]')])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        layout = {**reader.ANDROID, **{k: (t, 8 + 4 * first, 4 * len(n), '00') for k, (t, first, n) in reader.ANDROID_VTABLES.items()}}
        with patch.object(reader, 'ANDROID', layout):
            assert_native_android(self, reader, 'full_hold_pirate_definitions.gd', values='VALUES')
