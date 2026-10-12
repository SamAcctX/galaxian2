"""Android flight notice proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import unittest
from gof2_content import flight_notices as reader


class AndroidFlightNoticeTests(unittest.TestCase):
    def extract(self, lib, flight={'scope': 'first_mining_flight_construction'}):
        return reader.extract_flight_notices(lib, {}, flight)

    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        from test_arrival_staging import roomy_layouts
        with roomy_layouts():
            verify_android_proof(self, reader, self.extract, values='VALUES')
            image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            data = self.extract(lib)
            data['messages']['27']['rgb'][1] = 0
            self.assertEqual(reader.VALUES['messages']['27']['rgb'], [255, 42, 0])
            for name, flight in {'other flight': {'scope': 'first_station_departure'}, 'no flight': {}, 'none': None}.items():
                self.assertEqual(self.extract(lib, flight), {}, name)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'flight_notice_definitions.gd', values='VALUES')
        # The two message separators.
        separators = {bytes.fromhex(reader.ANDROID[k][3]).rstrip(b'\0').decode() for k in ('space_separator', 'colon_separator')}
        self.assertEqual(separators, {m['separator'] for m in reader.VALUES['messages'].values()} - {''})
