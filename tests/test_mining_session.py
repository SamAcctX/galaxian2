"""Android mining session proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import mining_session as reader

APPROACH, DRILL = {'scope': 'first_mining_approach'}, {'scope': 'ordinary_mining_drill'}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidMiningSessionTests(unittest.TestCase):
    def extract(self, lib, approach=APPROACH, drill=DRILL):
        return reader.extract_mining_session(lib, {}, approach, drill)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract, values='MAC_VALUES')
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['failure_instruction']['text_id'] = 0
            data['stop_audio_events'].clear()
            self.assertEqual((reader.MAC_VALUES['failure_instruction']['text_id'], reader.MAC_VALUES['stop_audio_events']), (606, [1, 3]))
            for name, changes in {'other approach': dict(approach={'scope': 'first_mining_asteroid_selection'}), 'no approach': dict(approach={}),
                                  'none': dict(approach=None), 'other drill': dict(drill={'scope': 'first_mining_drill'}), 'no drill': dict(drill={})}.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_constants(self):
        from gof2_content.text_ids import canonical_id
        rows, values = reader.ANDROID, reader.MAC_VALUES
        number = lambda key: int(thumb(rows[key][3])[0][1].split('#')[1], 0)
        # Hud::hudEvent: tbh on event - 1; entry 7 (event 8) at +54 reaches the getText(528) case.
        entry, = struct.unpack('<H', bytes.fromhex(rows['failure_jump_entry'][3]))
        self.assertEqual(((rows['failure_jump_entry'][1] - 40) // 2 + 1, 40 + 2 * entry), (values['failure_notification'], rows['failure_text'][1]))
        self.assertEqual(canonical_id(int(thumb(rows['failure_text'][3])[1][1].split('#')[1], 0)), values['failure_text_id'])
        instruction = values['failure_instruction']
        self.assertEqual(canonical_id(number('instruction_text')), instruction['text_id'])
        self.assertEqual(canonical_id(number('instruction_title_id')), instruction['title_text_id'])
        self.assertEqual(number('instruction_cursor'), instruction['campaign_cursor'])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'mining_session_definitions.gd', values='MAC_VALUES')
