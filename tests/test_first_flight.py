"""Android first mining flight proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import unittest
from gof2_content import first_flight as reader


class AndroidFirstFlightTests(unittest.TestCase):
    def extract(self, lib, departure={'scope': 'first_station_departure'}, environment={'present': True}, world={'present': True}):
        return reader.extract_first_flight(lib, {}, departure, environment, world)

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
            data['player_position'][2] = 0
            self.assertEqual(reader.VALUES['player_position'], [10, 10, 10000])
            for name, changes in {'other departure': dict(departure={'scope': 'full_hold_station_departure'}), 'no departure': dict(departure={}),
                                  'no environment': dict(environment={}), 'no world': dict(world={})}.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_native_declarations(self):
        import struct
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'first_flight_definitions.gd', values='VALUES')
        # createPlayer's pool: the angle fraction and tau.
        self.assertEqual(list(struct.unpack('<2f', bytes.fromhex(reader.ANDROID['yaw_constants'][3]))), [reader.VALUES['angle_fraction'], reader.VALUES['angle_tau']])
        self.assertEqual(struct.unpack('<2f', bytes.fromhex(reader.ANDROID['camera_constants'][3]))[1], reader.VALUES['camera_z'])

