"""Original special-planet selection guard; no executable payload.

Android: Status::inPlanetRingOrbit (stations 120, 126, 130 and 132, compared
with Station::equals and Station::getIndex) and StarSystem's constructor
(26000 size units in those orbits). Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_ordinary_worlds(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'ordinary_world_planet_guard',
 'special_planets': {'station_ids': [120, 126, 130, 132], 'size_units': 26000}}

LAYOUTS = {'ordinary_world_special_planet': [872426,
                                   80,
                                   '__text',
                                   '1a698012e1d64fe9f8b90dc3981140a3db6c10f9d9e30979020a9bcf1aa84051'],
 'ordinary_world_station_equality': [853288,
                                     22,
                                     '__text',
                                     '88fd654fbe9f154dc3b1abf97b31858eb99c0710a7cb258faaef2c2e729145e5'],
 'ordinary_world_station_id': [851352,
                               10,
                               '__text',
                               'eba6838af910ef1073f4aee9812ff89c920b16bd09dfcad38577c3aa80965a9c'],
 'ordinary_world_special_size': [843373,
                                 59,
                                 '__text',
                                 '2d207244eadace0eff8dea57bcd9b618a200450435b70a6f5d28d9cf38a094a9']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'ordinary_world_special_planet': [873058,
                                   80,
                                   '__text',
                                   '1a698012e1d64fe9f8b90dc3981140a3db6c10f9d9e30979020a9bcf1aa84051'],
 'ordinary_world_station_equality': [853920,
                                     22,
                                     '__text',
                                     '88fd654fbe9f154dc3b1abf97b31858eb99c0710a7cb258faaef2c2e729145e5'],
 'ordinary_world_station_id': [851984,
                               10,
                               '__text',
                               'eba6838af910ef1073f4aee9812ff89c920b16bd09dfcad38577c3aa80965a9c'],
 'ordinary_world_special_size': [844005,
                                 59,
                                 '__text',
                                 '4cd7326a3141bf7a8127f4b343b8172a2ee6033ec0a645a6bdbb5962ac34e1fe']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {'ordinary_world_special_planet': ('_ZN6Status17inPlanetRingOrbitEv', 0, 54, 'sha256:0dec681b5d687ad340455f894940761ffca4a60990eaf22703e9902ffe0a415f'),
           'ordinary_world_station_equality': ('_ZN7Station6equalsEPS_', 0, 18, '0246002021b1896892688a4208bf01207047'),
           'ordinary_world_station_id': ('_ZN7Station8getIndexEv', 0, 4, '80687047'),
           'ordinary_world_special_size': ('_ZN10StarSystemC2Ei', 2238, 32, 'sha256:4f2a242f76defddcb4c5aaa5168b017e972f130523c3776de381e1d0f4762c03')}
