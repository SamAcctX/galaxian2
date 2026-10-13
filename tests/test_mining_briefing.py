"""Android first mining briefing proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import mining_briefing as reader

FLIGHT, PRESENTATION = {'scope': 'first_mining_flight_construction'}, {'scope': 'first_station_presentation'}


class AndroidMiningBriefingTests(unittest.TestCase):
    def extract(self, lib, flight=FLIGHT, presentation=PRESENTATION, desktop={}):
        return reader.extract_mining_briefing(lib, {}, flight, presentation, desktop)

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
            data['events'][0]['text_id'] = 0
            self.assertEqual(reader.ANDROID_VALUES['events'][0]['text_id'], 1710)
            # Android has no desktop text: the briefing does not need its pairs.
            self.assertEqual(self.extract(lib, desktop={'scope': 'mac_desktop_text', 'pairs': [[1714, 1715]]}), self.extract(lib))
            for name, changes in {'other flight': dict(flight={'scope': 'first_station_departure'}), 'no flight': dict(flight={}),
                                  'none': dict(flight=None), 'other presentation': dict(presentation={'scope': 'x'}),
                                  'no presentation': dict(presentation={})}.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_values(self):
        from gof2_content.text_ids import canonical_id
        values = reader.ANDROID_VALUES
        # Only the desktop key token is gone: Android never substitutes text 1714 with 1715 (#KEY_DOCK).
        self.assertEqual({k for k in reader.MAC_VALUES if reader.MAC_VALUES[k] != values[k]}, {'key_token'})
        self.assertEqual((reader.MAC_VALUES['key_token'], values['key_token']), ('#KEY_DOCK', None))
        rows = reader.ANDROID
        counts = struct.unpack('<3i', bytes.fromhex(rows['count_prefix'][3]))
        self.assertEqual((counts[2], sum(counts[:2]) * 4), (2 * len(values['events']), rows['events'][5]))
        pairs = struct.unpack('<10i', bytes.fromhex(rows['events'][3]))
        self.assertEqual([(pairs[i], canonical_id(pairs[i + 1])) for i in range(0, 10, 2)], [(e['speaker_id'], e['text_id']) for e in values['events']])
        voices = struct.unpack('<8i', bytes.fromhex(rows['voice_events'][3]))
        self.assertEqual([(canonical_id(voices[i]), voices[i + 1]) for i in range(0, 8, 2)], [(e['text_id'], e['voice_event_id']) for e in values['events'][:4]])
        self.assertEqual(values['events'][4]['voice_event_id'], -1)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'mining_briefing_definitions.gd')
