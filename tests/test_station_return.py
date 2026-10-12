"""Android station return proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import station_return as reader


class AndroidStationReturnTests(unittest.TestCase):
    def extract(self, lib, flight={'scope': 'first_mining_flight_construction'}):
        return reader.extract_station_return(lib, {}, flight)

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
            self.assertEqual(len(reader.MAC_VALUES['events']), 5)
            for name, flight in {'other flight': {'scope': 'first_station_departure'}, 'no flight': {}, 'none': None}.items():
                self.assertEqual(self.extract(lib, flight), {}, name)

    def test_android_tables(self):
        from gof2_content.text_ids import canonical_id
        events = reader.MAC_VALUES['events']
        pairs = struct.unpack('<10i', bytes.fromhex(reader.ANDROID['mode1_return_events'][3]))
        self.assertEqual([(pairs[i], canonical_id(pairs[i + 1])) for i in range(0, 10, 2)], [(e['speaker_id'], e['text_id']) for e in events])
        voices = struct.unpack('<10i', bytes.fromhex(reader.ANDROID['voices'][3]))
        self.assertEqual([(canonical_id(voices[i]), voices[i + 1]) for i in range(0, 10, 2)], [(e['text_id'], e['voice_event_id']) for e in events])
        # Cursor 3 has 2 x 5 success entries, after 0 + 38 + 6 (the records' start / 4).
        counts = struct.unpack('<4i', bytes.fromhex(reader.ANDROID['mode1_counts'][3]))
        self.assertEqual((counts[3], sum(counts[:3]) * 4), (10, reader.ANDROID['mode1_return_events'][5]))
        self.assertEqual(struct.unpack('<f', bytes.fromhex(reader.ANDROID['contact_radius_constant'][3]))[0], reader.MAC_VALUES['contact_radius'])

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'station_return_definitions.gd', values='MAC_VALUES')
