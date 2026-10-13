"""Android second station return proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import full_hold_return as reader

FIRST, STORY = {'scope': 'first_mining_station_return'}, {'scope': 'full_hold_mining_story'}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidFullHoldReturnTests(unittest.TestCase):
    def extract(self, lib, first=FIRST, story=STORY):
        return reader.extract_full_hold_return(lib, {}, first, story)

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
            data['events'].clear()
            self.assertEqual(len(reader.MAC_VALUES['events']), 6)
            for name, changes in {'other first': dict(first={'scope': 'x'}), 'no first': dict(first={}), 'none': dict(first=None),
                                  'other story': dict(story={'scope': 'x'}), 'no story': dict(story={})}.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_tables(self):
        from gof2_content.text_ids import canonical_id
        rows, values = reader.ANDROID, reader.MAC_VALUES
        words = lambda key: struct.unpack('<%di' % (rows[key][2] // 4), bytes.fromhex(rows[key][3]))
        counts, pairs, voices = words('mode1_counts'), words('mode1_return_events'), words('voices')
        self.assertEqual((counts[5], sum(counts[:5]) * 4), (2 * len(values['events']), rows['mode1_return_events'][5]))
        self.assertEqual([(pairs[i], canonical_id(pairs[i + 1])) for i in range(0, 12, 2)], [(e['speaker_id'], e['text_id']) for e in values['events']])
        self.assertEqual([(canonical_id(voices[i]), voices[i + 1]) for i in range(0, 10, 2)], [(e['text_id'], e['voice_event_id']) for e in values['events'][:5]])
        self.assertEqual(values['events'][5]['voice_event_id'], -1)
        self.assertEqual(struct.unpack('<f', bytes.fromhex(rows['contact_radius_constant'][3]))[0], values['contact_radius'])
        entry, = struct.unpack('<H', bytes.fromhex(rows['cursor6_dispatch'][3]))
        self.assertEqual(((rows['cursor6_dispatch'][1] - 68) // 2 + 1, 68 + 2 * entry), (values['cursor_after_acknowledgement'], rows['cursor6_factory'][1]))
        code = thumb(rows['cursor6_factory'][3])
        self.assertIn(('movs', 'r1, #0x%x' % values['next_mission_kind']), code)
        self.assertIn(('movs', 'r2, #%d' % values['next_mission_parameter']), code)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'full_hold_return_definitions.gd', values='MAC_VALUES')
