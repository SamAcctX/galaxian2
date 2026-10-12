"""Static declaration recognition with relocated synthetic layouts only."""
import copy
import unittest
from declaration_fixture import literal_fixture
from gof2_content import flight_player_cache as reader


def variants():
    return [('x86_64',reader.LAYOUTS['x86_64']),
            ('armv7',reader.LAYOUTS['armv7']),
            ('x86_64',reader.MAC_ALTERNATE)]


def fixture(arch,rows,shift=0):
    constants=[k for k,v in rows.items() if v[0]=='__const']
    mach,origin,offset,low=literal_fixture(arch,{k:v[1:] for k,v in rows.items()},shift,constants)
    opening={'station_id':78,'provenance':{'declaration':{'offset':origin,'bytes':376 if arch=='x86_64' else 284}}}
    actors={'player_initialization':{'repair':{'supported':True}}}
    arrival={'campaign_cursor':1}
    return mach,opening,actors,arrival,offset,low


class FlightPlayerCacheTests(unittest.TestCase):
    def test_relocation_and_data_only_output(self):
        for arch,layout in variants():
            for shift in [0, 0x1200000]:
                m, o, a, r, *_ = fixture(arch,layout,shift)
                data = reader.extract_flight_player_cache(m, o, a, r)
                self.assertEqual({k: v for k, v in data.items() if k != 'provenance'}, reader.VALUES)
                for key, span in data['provenance'].items():
                    self.assertEqual(set(span), {'offset', 'bytes'})
                    self.assertEqual(span['offset'], o['provenance']['declaration']['offset'] + layout[key][1])
                data['provenance'].clear()
                self.assertTrue(reader.extract_flight_player_cache(m, o, a, r)['provenance'])

    def test_altered_spans_and_truncation(self):
        for arch,layout in variants():
            m, o, a, r, offset, low = fixture(arch,layout)
            for name, (_, delta, size, _) in layout.items():
                for index in [0, size-1]:
                    changed = copy.copy(m)
                    raw = bytearray(m.data)
                    raw[offset+delta-low+index] ^= 255
                    changed.data = bytes(raw)
                    self.assertEqual(reader.extract_flight_player_cache(changed, o, a, r), {}, (arch, name, index))
            m.data = m.data[:offset+16]
            self.assertEqual(reader.extract_flight_player_cache(m, o, a, r), {})

    def test_context_and_bounds(self):
        for arch,layout in variants():
            for key in ['player', 'repair', 'cursor', 'origin', 'size', 'section', 'arch', 'hazard_low', 'hazard_high']:
                m, o, a, r, *_ = fixture(arch,layout)
                if key == 'player': a.clear()
                elif key == 'repair': a['player_initialization']['repair'] = {}
                elif key == 'cursor': r['campaign_cursor'] = 95
                elif key == 'origin': o['provenance']['declaration']['offset'] += 2
                elif key == 'size': o['provenance']['declaration']['bytes'] += 1
                elif key == 'section': m.sections[0]['segment'] = b'__DATA'
                elif key == 'arch': m.architecture = 'unsupported'
                elif key == 'hazard_low': o['station_id'] = 109
                else: o['station_id'] = 113
                self.assertEqual(reader.extract_flight_player_cache(m, o, a, r), {}, (arch, key))


ANDROID_PARENTS = ({'station_id': 78}, {'player_initialization': {'repair': {'supported': True}}}, {'campaign_cursor': 1})


class AndroidFlightPlayerCacheTests(unittest.TestCase):
    def test_android_proofs(self):
        from android_fixture import layout_library, verify_android_proof
        from unittest.mock import patch
        from gof2_content.android_library import AndroidLibrary
        verify_android_proof(self, reader, lambda lib: reader.extract_flight_player_cache(lib, *ANDROID_PARENTS))
        image, layout, _ = layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            lib = AndroidLibrary(image)
            self.assertTrue(reader.extract_flight_player_cache(lib, *ANDROID_PARENTS))
            opening, actors, arrival = ANDROID_PARENTS
            for name, parents in {'later arrival': (opening, actors, {'campaign_cursor': 2}),
                                  'no repair': (opening, {'player_initialization': {'repair': {}}}, arrival),
                                  'hazard station low': ({'station_id': 109}, actors, arrival),
                                  'hazard station high': ({'station_id': 113}, actors, arrival),
                                  'no opening': ({}, actors, arrival)}.items():
                self.assertEqual(reader.extract_flight_player_cache(lib, *parents), {}, name)
            for station in (108, 114):
                self.assertTrue(reader.extract_flight_player_cache(lib, {'station_id': station}, actors, arrival), station)
        # Only the special-quest gamma differs: Android has none.
        self.assertEqual({k for k in reader.VALUES if reader.VALUES[k] != reader.ANDROID_VALUES[k]}, {'gamma_special_quest'})

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'flight_player_cache_definitions.gd')
