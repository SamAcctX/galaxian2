"""Android station autopilot proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import station_autopilot as reader


class AndroidStationAutopilotTests(unittest.TestCase):
    def extract(self, lib, flight={'scope': 'first_mining_flight_construction'}):
        return reader.extract_station_autopilot(lib, {}, flight)

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
            data['target_position'][0] = 1
            self.assertEqual(reader.VALUES['target_position'], [0, 0, 0])
            for name, flight in {'other flight': {'scope': 'first_station_departure'}, 'no flight': {}, 'none': None}.items():
                self.assertEqual(self.extract(lib, flight), {}, name)

    def test_android_constants(self):
        values = reader.VALUES
        add, _, slew, _, turn, tau, bank, bank_tau = struct.unpack('<2f2f2d2f', bytes.fromhex(reader.ANDROID['guidance_constants'][3]))
        self.assertEqual((add, slew, turn, tau), (values['response_add'], values['bank_slew_scale'], values['turn_fraction'], values['angle_tau']))
        self.assertEqual((bank, bank_tau), (values['bank_angle_scale'], values['angle_tau']))
        self.assertEqual(struct.unpack('<3f', bytes.fromhex(reader.ANDROID['bank_constructor_floats'][3])),
                         (values['bank_limit_numerator'], values['bank_limit_divisor'], values['bank_limit_scale']))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'station_autopilot_definitions.gd', values='VALUES')
