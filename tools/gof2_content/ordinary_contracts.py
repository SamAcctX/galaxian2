"""Ordinary delivery traffic and selected courier construction. Constant declarations only.

Android: Level::createMission reseeds for ordinary orbits, sizes the pirate
group of a freelance mission of kind 0, 11 or 15 (Status::getFreelanceMission:
difficulty / 10 x 5), creates those pirates (kind 8, one hull per actor) at
the player's position + (-80000, -50000, -80000) + random(160000, 100000,
160000) (offsets in its literal pool, divisor and multiplier as immediates)
and builds no actors for a courier mission (kind 0 falls outside the kind
switch). Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_ordinary_contracts(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'ordinary_delivery_contracts',
 'population': {'side_kinds': [0, 11, 15],
                'difficulty_divisor': 10.0,
                'count_multiplier': 5.0,
                'actor_kind': 8,
                'subtype': 0,
                'enabled': True,
                'hull_choice': 'per_actor',
                'position_offsets': [-80000.0, -50000.0, -80000.0],
                'position_bounds': [160000, 100000, 160000]},
 'courier': {'kind': 0, 'actor_count': 0, 'reseed': False}}

LAYOUTS = {'ordinary_contracts_reseed': [-31265,
                               31,
                               '__text',
                               '65d52d01156e55c4553b21a842b923ada6abbb72e650fe3c51ac3b2ac5e0ed38'],
 'ordinary_contracts_side_slot': [859500,
                                  22,
                                  '__text',
                                  '435cd70592cf3d5ae79358d3aafb4659f2960d066098e8e84cb68f9f4dc4685b'],
 'ordinary_contracts_count': [-31097,
                              103,
                              '__text',
                              'b7499b70edfc70acc588afb8e7d95f2fd7c89f0825d9700a99b099676b3b042a'],
 'ordinary_contracts_pirates': [-18932,
                                503,
                                '__text',
                                '1bf756344878824eb5f9381915bb15bf82a412fd4753cc5e5b40d7f527d27e55'],
 'ordinary_contracts_dispatch': [-15605,
                                 124,
                                 '__text',
                                 '27b7d4979d531e73f621e5cf7dee85cb4e3d99aa5f472fce3e302ed843d7d831'],
 'ordinary_contracts_empty_return': [-4930,
                                     38,
                                     '__text',
                                     '0ea7ecbd4b8ef7e7aa24b95b4e6af683c6ca00f09d010348003ec954e144b011'],
 'ordinary_contracts_divisor': [1557090,
                                4,
                                '__const',
                                '80c8a717ccd70c8809eb78e6a9591c003e11c721fe0ccaf62fd592abda1a5593'],
 'ordinary_contracts_multiplier': [1557114,
                                   4,
                                   '__const',
                                   'fca31f1667a6aa1bba12fca4e4ea1becd503379d80da3213af07f6cc5702828d'],
 'ordinary_contracts_xz_offset': [1575126,
                                  4,
                                  '__const',
                                  'd87578fc2a1f2df1ec73a44e1f78593c5c7ab979f8b9f86960206c70798fe342'],
 'ordinary_contracts_y_offset': [1575142,
                                 4,
                                 '__const',
                                 'bb8ae8eac34cb5200e9958e6d9be0fd571c010b50d3e43d5d19015e8d02f2676']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'ordinary_contracts_reseed': [-31265,
                               31,
                               '__text',
                               '619ff2a0445cdeff77423ba3fc6a0cd3a2eea23952ed533d44579ed9cee2b070'],
 'ordinary_contracts_side_slot': [860132,
                                  22,
                                  '__text',
                                  '435cd70592cf3d5ae79358d3aafb4659f2960d066098e8e84cb68f9f4dc4685b'],
 'ordinary_contracts_count': [-31097,
                              103,
                              '__text',
                              'fd6536bae899b4b5b23d3d599175018b64aec0b7791768a30458f43d9eaa0456'],
 'ordinary_contracts_pirates': [-18932,
                                503,
                                '__text',
                                '9c6596d6210475164330d1a9aaeb940ed3531ebb91f7bac62713682e15c0db50'],
 'ordinary_contracts_dispatch': [-15605,
                                 124,
                                 '__text',
                                 '6a8e1b051fe3b1962846ee3b4317bfac087c23cb443cbec0ab70aa930abfb035'],
 'ordinary_contracts_empty_return': [-4930,
                                     38,
                                     '__text',
                                     'f2476efc0c075512fd0ff6325b5b023806e00ca3e2b1ce2e4b6daeb7d0e993dc'],
 'ordinary_contracts_divisor': [1532090,
                                4,
                                '__const',
                                '80c8a717ccd70c8809eb78e6a9591c003e11c721fe0ccaf62fd592abda1a5593'],
 'ordinary_contracts_multiplier': [1532114,
                                   4,
                                   '__const',
                                   'fca31f1667a6aa1bba12fca4e4ea1becd503379d80da3213af07f6cc5702828d'],
 'ordinary_contracts_xz_offset': [1550190,
                                  4,
                                  '__const',
                                  'd87578fc2a1f2df1ec73a44e1f78593c5c7ab979f8b9f86960206c70798fe342'],
 'ordinary_contracts_y_offset': [1550206,
                                 4,
                                 '__const',
                                 'bb8ae8eac34cb5200e9958e6d9be0fd571c010b50d3e43d5d19015e8d02f2676']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# Level::createMission: reseed, the freelance pirates and the courier's empty dispatch.
           'ordinary_contracts_reseed': ('_ZN5Level13createMissionEv', 534, 34, 'sha256:34f13d7fdf4c84783cee3ec86d0747574fe1f139f2afd4f03cae506d912d04c6'),
           'ordinary_contracts_side_slot': ('_ZN6Status19getFreelanceMissionEv', 0, 10, 'd0f89401406840687047'),
           'ordinary_contracts_count': ('_ZN5Level13createMissionEv', 670, 86, 'sha256:5b5964101f54b063031d3c7a5a2f82fd44c1250a65b17e8ed74461b4c3c1e855'),
           'ordinary_contracts_pirates': ('_ZN5Level13createMissionEv', 9912, 314, 'sha256:cadf5961ba6d66776f3c0613ee466528608ab189ef587d1fe4e3cbbbec275e59'),
           'ordinary_contracts_offsets': ('_ZN5Level13createMissionEv', 10520, 8, '00409cc7005043c7'),
           'ordinary_contracts_dispatch': ('_ZN5Level13createMissionEv', 756, 148, 'sha256:141203cd7eca2eca24558ff346f8deeeee83d576ee61073bf430d18efb05be0c'),
           'ordinary_contracts_other_kinds': ('_ZN5Level13createMissionEv', 4756, 12, 'b82803f0bd82b7287ff474a8'),
           'ordinary_contracts_empty_return': ('_ZN5Level13createMissionEv', 904, 32, 'sha256:97e50234ec590ab05e635ef4527311b5f874efae274e268b20854c99c9de11ae')}
