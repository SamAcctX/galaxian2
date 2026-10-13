"""Android second-trip story proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import full_hold_story as reader

FLIGHT, BRIEFING, OBJECTIVE = {'scope': 'full_hold_mining_flight_construction'}, {'scope': 'first_mining_briefing'}, {'scope': 'first_mining_cargo_objective'}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidFullHoldStoryTests(unittest.TestCase):
    def extract(self, lib, flight=FLIGHT, briefing=BRIEFING, objective=OBJECTIVE):
        return reader.extract_full_hold_story(lib, {}, flight, briefing, objective)

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
            data['completion_events'].clear()
            self.assertEqual(len(reader.MAC_VALUES['completion_events']), 2)
            cases = {'other flight': dict(flight={'scope': 'x'}), 'no flight': dict(flight={}), 'none': dict(flight=None),
                     'other briefing': dict(briefing={'scope': 'x'}), 'no objective': dict(objective={}), 'other objective': dict(objective={'scope': 'x'})}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_tables(self):
        from gof2_content.text_ids import canonical_id
        rows, values = reader.ANDROID, reader.MAC_VALUES
        words = lambda key: struct.unpack('<%di' % (rows[key][2] // 4), bytes.fromhex(rows[key][3]))
        counts0, counts1 = words('mode0_counts'), words('mode1_counts')
        self.assertEqual((counts0[4], sum(counts0[:4]) * 4), (2 * len(values['briefing_events']), rows['mode0_events'][5]))
        self.assertEqual((counts1[4], sum(counts1[:4]) * 4), (2 * len(values['completion_events']), rows['mode1_events'][5]))
        for key, events in (('mode0_events', values['briefing_events']), ('mode1_events', values['completion_events'])):
            pairs = words(key)
            self.assertEqual([(pairs[i], canonical_id(pairs[i + 1])) for i in range(0, len(pairs), 2)], [(e['speaker_id'], e['text_id']) for e in events])
        voices = words('briefing_voice') + words('completion_voices')
        events = values['briefing_events'] + values['completion_events']
        self.assertEqual([(canonical_id(voices[i]), voices[i + 1]) for i in range(0, len(voices), 2)], [(e['text_id'], e['voice_event_id']) for e in events])
        entries = struct.unpack('<2H', bytes.fromhex(rows['mission_dispatch'][3]))
        self.assertEqual([68 + 2 * e for e in entries], [rows['mission_factory'][1], rows['next_mission'][1]])
        self.assertEqual(thumb(rows['mission_factory'][3])[-2], ('movs', 'r1, #0x%x' % values['required_cargo']))
        nxt = thumb(rows['next_mission'][3])
        self.assertIn(('movs', 'r1, #0x%x' % values['next_kind']), nxt)
        self.assertIn(('movs', 'r3, #0x%x' % values['station_id']), nxt)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'full_hold_story_definitions.gd', values='MAC_VALUES')
