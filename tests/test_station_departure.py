"""Android station departure proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import unittest
from gof2_content import station_departure as reader
ANDROID_PLAYER = {'flight_cache': {'present': True}, 'repair': {'present': True}}


class AndroidStationDepartureTests(unittest.TestCase):
    def extract(self, lib, station={'scope': 'first_station_entry'}, player=ANDROID_PLAYER):
        return reader.extract_station_departure(lib, {}, station, player)

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
            self.assertTrue(self.extract(lib))
            for name, changes in {'other station': dict(station={'scope': 'kappa_campaign_return'}), 'no station': dict(station={}),
                                  'no cache': dict(player={**ANDROID_PLAYER, 'flight_cache': {}}),
                                  'no repair': dict(player={**ANDROID_PLAYER, 'repair': {}}), 'no player': dict(player={})}.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'station_departure_definitions.gd', values='VALUES')
