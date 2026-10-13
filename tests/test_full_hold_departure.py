"""Android second mining departure proofs, without original fixtures (the Mac layouts are in test_first_flight_layouts)."""
import struct
import unittest
from gof2_content import full_hold_departure as reader

DEPARTURE = {'scope': 'first_station_departure'}
RETURN = {'scope': 'first_mining_station_return', 'cursor_after_acknowledgement': 4, 'next_mission_kind': 154, 'next_mission_parameter': 25}


def thumb(hex_code):
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    return [(i.mnemonic, i.op_str) for i in decoder.disasm(bytes.fromhex(hex_code), 0)]


class AndroidFullHoldDepartureTests(unittest.TestCase):
    def extract(self, lib, departure=DEPARTURE, station_return=RETURN):
        return reader.extract_full_hold_departure(lib, {}, departure, station_return)

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
            cases = {'other departure': dict(departure={'scope': 'full_hold_station_departure'}), 'no departure': dict(departure={}),
                     'none': dict(departure=None), 'other return': dict(station_return=dict(RETURN, scope='x')),
                     'other cursor': dict(station_return=dict(RETURN, cursor_after_acknowledgement=5)),
                     'other kind': dict(station_return=dict(RETURN, next_mission_kind=11)),
                     'other parameter': dict(station_return=dict(RETURN, next_mission_parameter=10)), 'no return': dict(station_return={})}
            for name, changes in cases.items():
                self.assertEqual(self.extract(lib, **changes), {}, name)

    def test_android_constants(self):
        rows, values = reader.ANDROID, reader.VALUES
        entry, = struct.unpack('<H', bytes.fromhex(rows['mission_dispatch'][3]))
        # tbh entry 3 (cursor 4) reaches the factory.
        self.assertEqual(((rows['mission_dispatch'][1] - 68) // 2 + 1, 68 + 2 * entry), (values['campaign_cursor'], rows['mission_factory'][1]))
        code = thumb(rows['mission_factory'][3])
        self.assertEqual(code[1], ('movs', 'r1, #0'))
        self.assertIn(('movs', 'r1, #0x%x' % values['mission_kind']), code)
        self.assertIn(('movs', 'r3, #0x%x' % values['station_id']), code)
        self.assertEqual(code[-2], ('movs', 'r1, #0x%x' % values['mission_parameter']))

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'full_hold_departure_definitions.gd', values='VALUES')
