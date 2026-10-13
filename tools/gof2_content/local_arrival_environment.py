"""Original ordinary planet-size and arrival-pose declarations only.

Android: StarSystem's constructor sizes the planet (random(20000) + 20000,
halved at cursor 0; 26000 in a ring orbit (Status::inPlanetRingOrbit);
types 6, 11, 12, 17 random(15000) + 35000, types 9, 16 random(13000) +
32500; x 1/65536 from its literal pool; Station::getTextureIndex);
Level::init places the arrival at object 2 or four times the previous
station's planet facing the origin (Status::getStationStack, SolarSystem's
station list, constructor and FileRead::loadSystemsBinary,
AEGeometry::setDirection). The distance factor 4.0 is an immediate.
Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_local_arrival_environment(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'augmenta_local_arrival_environment',
 'planet_sizes': {'initial_bound': 20000,
                  'initial_add': 20000,
                  'scale': 1.52587890625e-05,
                  'replacement_groups': [{'types': [6, 11, 12, 17], 'bound': 15000, 'add': 35000},
                                         {'types': [9, 16], 'bound': 13000, 'add': 32500}]},
 'arrival': {'cache_index': 1,
             'system_station_array': 1,
             'planet_index_offset': 1,
             'planet_multiplier': 4.0,
             'fallback_planet_position': [0.0, 0.0, 25000.0],
             'face_origin': True,
             'up': [0.0, 1.0, 0.0],
             'gate_keeps_initial_heading': True,
             'gate_object_index': 2}}

LAYOUTS = {'local_arrival_planet_initial': [843293,
                                  157,
                                  '__text',
                                  'ad83842a22a529f0b626d31993b8d6957172c74e6a942744bcf1c972be55ffeb'],
 'local_arrival_planet_sizes': [842473,
                                103,
                                '__text',
                                'b4177fbad90a934d61f716fb73af015baf28fe32dcce0031442f7041d28f8538'],
 'local_arrival_special_planet': [872426,
                                  80,
                                  '__text',
                                  '1a698012e1d64fe9f8b90dc3981140a3db6c10f9d9e30979020a9bcf1aa84051'],
 'local_arrival_planet_type': [851424,
                               10,
                               '__text',
                               '7420c657eada7977f7682c2322a9a2430a8fb5883aecc5ada569ff27177d6816'],
 'local_arrival_pose_selection': [-43078,
                                  586,
                                  '__text',
                                  '4c93566a9e23713332c65506ee45b89889b63945317ca5421ccfa1748a23be51'],
 'local_arrival_cache_getter': [855368,
                                14,
                                '__text',
                                '9d38ab6ec9fd45c1aa30b667c89657b2dfaba4064a62e754e896d3acc49b9eea'],
 'local_arrival_station_list': [735294,
                                10,
                                '__text',
                                '3b843a5e0a33d0bd1fcd684b3a6a912724066ca70083334901d245bf633a91bf'],
 'local_arrival_list_constructor': [734132,
                                    236,
                                    '__text',
                                    '122ea148ea9bda7284bafe51b2f76f49a9095eedc741c9976d7ddc2b0170437c'],
 'local_arrival_list_loader': [-673478,
                               1100,
                               '__text',
                               'a2598d45aa10d793fc6cb88f29f9d5df59d1afd01417a39d465f6f269ad11c6e'],
 'local_arrival_face_origin': [-723998,
                               480,
                               '__text',
                               'cb4567d48118f3b2e47133c82b46ba19f6753c56721fe100fc75f655f79d598b'],
 'local_arrival_planet_scale': [1575014,
                                4,
                                '__const',
                                '54e347282ecf0fd46f002970fa012534725e0bf3b2ad2f4ca0efc0134d7e1d28'],
 'local_arrival_distance_scale': [1575050,
                                  4,
                                  '__const',
                                  '4f4b9b7d8b86633e2824e2f439819357b0cd010ab410ea1a691b12c5f94e91e0']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'local_arrival_planet_initial': [843925,
                                  157,
                                  '__text',
                                  '740ddc85a1b3a49303db996249abbeb30d86879773325da8b76ebb3f5ce27f60'],
 'local_arrival_planet_sizes': [843105,
                                103,
                                '__text',
                                '0c69a25686b48c43a1813a5f353307e6cd3b0a43712fc18ff0f036ac1a0c577d'],
 'local_arrival_special_planet': [873058,
                                  80,
                                  '__text',
                                  '1a698012e1d64fe9f8b90dc3981140a3db6c10f9d9e30979020a9bcf1aa84051'],
 'local_arrival_planet_type': [852056,
                               10,
                               '__text',
                               '7420c657eada7977f7682c2322a9a2430a8fb5883aecc5ada569ff27177d6816'],
 'local_arrival_pose_selection': [-43078,
                                  586,
                                  '__text',
                                  '9984bcc095d7f7c55b1c0cc7117b539511c18de69f073e5950959984c310476c'],
 'local_arrival_cache_getter': [856000,
                                14,
                                '__text',
                                '9d38ab6ec9fd45c1aa30b667c89657b2dfaba4064a62e754e896d3acc49b9eea'],
 'local_arrival_station_list': [735926,
                                10,
                                '__text',
                                '3b843a5e0a33d0bd1fcd684b3a6a912724066ca70083334901d245bf633a91bf'],
 'local_arrival_list_constructor': [734764,
                                    236,
                                    '__text',
                                    '56690428c5f202baadd8567bab29de3f0e3bfe37f40c3fbf3102a3acdaee2a31'],
 'local_arrival_list_loader': [-679366,
                               1100,
                               '__text',
                               'ed1307f3b2249adbc99fa87dc54bce34c7de097c2f229dcf0e922fe9303416cd'],
 'local_arrival_face_origin': [-729894,
                               480,
                               '__text',
                               'e71b22aec69731e5833cc31144dfc31d7e67bc30aebaf4a3adbf01f44635349c'],
 'local_arrival_planet_scale': [1550078,
                                4,
                                '__const',
                                '54e347282ecf0fd46f002970fa012534725e0bf3b2ad2f4ca0efc0134d7e1d28'],
 'local_arrival_distance_scale': [1550114,
                                  4,
                                  '__const',
                                  '4f4b9b7d8b86633e2824e2f439819357b0cd010ab410ea1a691b12c5f94e91e0']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# StarSystem::StarSystem: planet sizes and their 1/65536 scale.
           'local_arrival_planet_initial': ('_ZN10StarSystemC2Ei', 2186, 84, 'sha256:57429178f69659ab603c56f2056a95d6b6071b4b4f369dc45fd95f28237f03cf'),
           'local_arrival_planet_sizes': ('_ZN10StarSystemC2Ei', 2484, 60, 'sha256:c2e6d13f289a2dc0d3ceaf115ca25325f142fa514d0048fab2d2021bbe641886'),
           'local_arrival_planet_group': ('_ZN10StarSystemC2Ei', 1952, 32, 'sha256:6c4e9ed8e2f19a4ab335c442e6dc4785d304b7c56c67d25246cc91e752f3d207'),
           'local_arrival_planet_scale_setup': ('_ZN10StarSystemC2Ei', 1690, 22, 'b6ee00aadff8201700257844dff81c2779441fed5c8a'),
           'local_arrival_planet_scale': ('_ZN10StarSystemC2Ei', 1344, 4, '00008037'),
           # Ring orbits (stations 120, 126, 130, 132) and the planet type.
           'local_arrival_special_planet': ('_ZN6Status17inPlanetRingOrbitEv', 0, 54, 'sha256:0dec681b5d687ad340455f894940761ffca4a60990eaf22703e9902ffe0a415f'),
           'local_arrival_planet_type': ('_ZN7Station15getTextureIndexEv', 0, 4, '40697047'),
           # Level::init: object 2, or four times the previous station's planet, facing the origin.
           'local_arrival_pose_selection': ('_ZN5Level4initEv', 662, 138, 'sha256:045ec6507de574389d91d7cb3fff0ac921d7ec786d7fe6db4f6bd90e599110df'),
           'local_arrival_pose_planet': ('_ZN5Level4initEv', 1416, 222, 'sha256:c8030454ae0c1dedad9c589a8abbd1cc60155b430cbe11bed20835d589b437ff'),
           # The station stack and the systems' station lists.
           'local_arrival_cache_getter': ('_ZN6Status15getStationStackEv', 0, 6, 'd0f89c017047'),
           'local_arrival_station_list': ('_ZN11SolarSystem11getStationsEv', 0, 4, '406b7047'),
           'local_arrival_list_constructor': ('_ZN11SolarSystemC2EiN11AbyssEngine6StringEibiiiiiiPiP5ArrayIiES5_S5_', 0, 184, 'sha256:639c7c82d968338fcc85b4f1ebdd98184f3dd075af953f6438614dd93078f7f7'),
           'local_arrival_list_loader': ('_ZN8FileRead17loadSystemsBinaryEv', 0, 772, 'sha256:d094cf702411949da76f9a406c4336c6c0bd2b4342531312c38009e2976e0100'),
           'local_arrival_face_origin': ('_ZN10AEGeometry12setDirectionERKN11AbyssEngine6AEMath6VectorES4_', 0, 264, 'sha256:aba5871395d99b37b935794ffc342a4b51be1be876b151a4f4bc4042b074098e')}
