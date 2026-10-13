"""Android player destruction proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import player_destruction as reader

FLIGHT = {'scope': 'full_hold_mining_flight_construction'}
ACTORS = {'npc_initialization': {'destruction': {'effect_type': 0, 'model_ids': [16821, 16820]}}}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidPlayerDestructionTests(unittest.TestCase):
    def extract(self, lib, flight=FLIGHT, actors=ACTORS):
        return reader.extract_player_destruction(lib, {}, flight, actors)

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
            data = self.extract(lib)
            data['stop_sound_ids'].clear()
            self.assertEqual(len(reader.ANDROID_VALUES['stop_sound_ids']), 8)
            death = ACTORS['npc_initialization']['destruction']
            cases = {'other flight': dict(flight={'scope': 'mining_flight_construction'}), 'no flight': dict(flight={}), 'none': dict(flight=None),
                     'other effect': dict(actors={'npc_initialization': {'destruction': dict(death, effect_type=1)}}),
                     'other models': dict(actors={'npc_initialization': {'destruction': dict(death, model_ids=[16820, 16821])}}),
                     'no destruction': dict(actors={'npc_initialization': {}}), 'no actors': dict(actors={})}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_values(self):
        # Only the game-over image differs: MGame never creates one on Android.
        self.assertEqual({k for k in reader.VALUES if reader.VALUES[k] != reader.ANDROID_VALUES[k]}, {'game_over_image_id'})
        self.assertEqual((reader.VALUES['game_over_image_id'], reader.ANDROID_VALUES['game_over_image_id']), (1313, None))
        self.assertEqual(set(reader.ANDROID_VALUES), set(reader.VALUES))

    def test_android_constants(self):
        values = reader.ANDROID_VALUES
        # PlayerEgo::update: movw/movt build the spin, passed to AEGeometry::rotate for all three axes.
        spin = thumb(reader.ANDROID['spin'][3])
        low, high = int(spin[0][1].split('#')[1], 0), int(spin[2][1].split('#')[1], 0)
        self.assertEqual([spin[0][0], spin[2][0]], ['movw', 'movt'])
        self.assertEqual(struct.unpack('<f', struct.pack('<I', high << 16 | low))[0], values['spin_per_update'])
        # PlayerEgo::explosionEnded: more than 8000 ms.
        ended = thumb(reader.ANDROID['failure_after'][3])
        self.assertEqual(ended[0], ('cmp.w', 'r1, #%#x' % values['failure_after_ms']))
        self.assertEqual(ended[1][0], 'it')
        # MGame::OnRender2D's pool: the 4000 ms fade to 255 and the blink rate.
        self.assertEqual(struct.unpack('<2f', bytes.fromhex(reader.ANDROID['fade_constants'][3])), (values['fade_ms'], 255.0))
        self.assertEqual(struct.unpack('<f', bytes.fromhex(reader.ANDROID['blink_constant'][3]))[0], 0.003000000026077032)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'player_destruction_definitions.gd')
