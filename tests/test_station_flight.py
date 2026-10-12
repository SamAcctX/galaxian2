"""Android station flight proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import unittest
from gof2_content import station_flight as reader


class AndroidStationFlightTests(unittest.TestCase):
    def extract(self, lib, flight={'scope': 'first_mining_flight_construction'}):
        return reader.extract_station_flight(lib, {}, flight)

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
            data['target_notice']['rgb'][0] = 0
            self.assertEqual(reader.VALUES['target_notice']['rgb'], [255, 255, 255])
            for name, flight in {'other flight': {'scope': 'first_station_departure'}, 'no flight': {}, 'none': None}.items():
                self.assertEqual(self.extract(lib, flight), {}, name)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'station_flight_definitions.gd', values='VALUES')
