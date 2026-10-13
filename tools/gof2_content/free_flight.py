"""Static ordinary-entry declarations; native owners supply the implementation.

Android: LevelScript::process ends the convoy (next mission, departure from
station 98, flags cleared), clears the launch scene after 7000 ms and lets
cursor 18 fall to the ordinary default; LevelScript's constructor clears the
arrival-from-alien-world scene; ModStation::OnTouchEnd launches (cursor 48
departs from station 58). Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_free_flight(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'augmenta_ordinary_entry',
 'campaign_cursor': 18,
 'initial_station_id': 98,
 'system_id': 19,
 'departure_flags': {'special_arrival': False, 'void_encounter': False},
 'special_confirmation_cursor': 48,
 'launch_clear_after_ms': 7000,
 'launch_clear_strict': True}

LAYOUTS = {'free_flight_convoy_clear': [155626,
                              87,
                              '__text',
                              '5ccf57b90171b3d1d0cdfe576225e6277f0efcc000a6abd7432a3e1eb7bdc9fb'],
 'free_flight_scene_clear': [134971,
                             325,
                             '__text',
                             '678d44de94a695c4df67086eebff6a7bcbe69a33f16408d72f0aec169a3ac839'],
 'free_flight_confirmation': [431803,
                              192,
                              '__text',
                              'd407d883511072a7ba2e782a90fb2841d647c7d3347502ffedf9a292f2382789'],
 'free_flight_launch_clear': [151066,
                              205,
                              '__text',
                              '92ca533c64ea68b6bff6b630f02a7c9d7ee8f87bf60f192e20e2a0b0325e1ea4'],
 'free_flight_ordinary_dispatch': [152236,
                                   50,
                                   '__text',
                                   'af22ec2ec52120661d0ffef3d141992d7b35f64e7308f256c821185cb785abed']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'free_flight_convoy_clear': [155626, 87, '__text', 'e84f2428b2ab8847821a24b56900a9043a8dbeaa770f4bd3e671b43e71d4ed01'],
 'free_flight_scene_clear': [134971, 325, '__text', 'ef7f1f500c4cb5f4fd1dc13a682ba3d60b7e2194ecbe1587ceb6471448c34f91'],
 'free_flight_confirmation': [432231,
                              192,
                              '__text',
                              '997c660d0feb870c51d477943f8afa63087cb5321ec5d721eea1e37cf90aff6c'],
 'free_flight_launch_clear': [151066,
                              205,
                              '__text',
                              '6752221780dc46c0708db9d6cff1f81cc49767fabd5d8807e218bd1a1b868579'],
 'free_flight_ordinary_dispatch': [152236,
                                   50,
                                   '__text',
                                   '7ded36b69d2387b406f26b359d55f04fa5593a921ab697e19b062a10a25f43ae']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# LevelScript::process: next mission, departure from station 98, flags cleared.
           'free_flight_convoy_clear': ('_ZN11LevelScript7processEi', 50882, 82, 'sha256:7929e85c96133bf09f6d522fe7731235c907b66e611f4ad1711526f713c6f735'),
           # LevelScript's constructor: the wormhole behind the player, the alien-world flag cleared.
           'free_flight_scene_clear': ('_ZN11LevelScriptC2EP5LevelP3HudP5RadarP18TargetFollowCamera', 7888, 206, 'sha256:957083c3850714e3a086e14c39a244cfc9ad86c1b5e904c22640797c44558bfd'),
           # ModStation::OnTouchEnd: launch (cursor 48 departs from station 58).
           'free_flight_confirmation': ('_ZN10ModStation10OnTouchEndEiiPv', 1982, 60, 'sha256:541dddffa5fcde9b38a23b46e21b70bae0b7abc96e406344c4a61f8ccfd0c6f0'),
           'free_flight_confirmation_tail': ('_ZN10ModStation10OnTouchEndEiiPv', 2532, 84, 'sha256:0617b3f4542623e94b12edfb7d5c49d9a0a8d22dd1e10929cef4c416c59bdd41'),
           # Launch control returns after 7000 ms; cursor 18 has no story case.
           'free_flight_launch_clear': ('_ZN11LevelScript7processEi', 826, 166, 'sha256:d8a891157c19010b3e950e41de774706d6cffc37f24e1cabce7c73b392a08362'),
           'free_flight_ordinary_dispatch': ('_ZN11LevelScript7processEi', 2902, 34, 'sha256:5ab1b261b629a0a0ecbcee42c141df0ffcbe90acf7dbacec0ff2fb597e972055')}
