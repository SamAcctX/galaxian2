"""Original early Mido population content, recovered only while importing.

This capability supplies construction rules. It does not unlock travel or claim
that all associated actor behavior has been implemented.

Android: Level::createMission holds the Mido counts, the empty fallback, the
group order, the travel ships and the freighter choice; KIPlayer::setRoute,
setDead and setJumper the travel ships' route, mode and flag; Level::createShip
and PlayerFixedObject's constructor the freighter and its cargo;
Globals::getShipGroup its assembly. Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants
from .mido_travel import VALUES as TRAVEL_VALUES, MAC_VALUES as TRAVEL_MAC_VALUES, ANDROID_VALUES as TRAVEL_ANDROID_VALUES

def extract_ambient_population(mach, arrival, travel):
    if not isinstance(travel,dict):return {}
    if mach.architecture=='android-armv7':
        proof=recognize_symbols(mach,ANDROID) if arrival else {}
        if not proof or any(travel.get(key)!=value for key,value in TRAVEL_ANDROID_VALUES.items()):return {}
        result=copy.deepcopy(VALUES);result['provenance']=proof
        return result
    variant,proof=hashed_variants(mach,arrival,[LAYOUTS,MAC_ALTERNATE])
    if not proof:return {}
    if any(travel.get(key)!=value for key,value in (TRAVEL_VALUES,TRAVEL_MAC_VALUES)[variant].items()):return {}
    result=copy.deepcopy(VALUES);result['provenance']=proof
    return result

VALUES = {'scope': 'early_mido_ordinary_population',
 'system_id': 15,
 'actor_kind': 3,
 'supported_difficulties': [0.5, 1.0],
 'contexts': [{'station_id': 78, 'campaign_cursor': 10, 'mixed': False},
              {'station_id': 79, 'campaign_cursor': 11, 'mixed': True}],
 'requires_default_completed_mission': True,
 'mission_kind': -1,
 'mission_story': False,
 'requires_empty_companions': True,
 'station_response': False,
 'group_order': ['patrol', 'travel', 'freighter'],
 'travel_count_bound': 2,
 'freighter_count_bound': 5,
 'extra_patrol_count_bound': 2,
 'freighters_per_patrol': 4,
 'travel_ship': {'subtype': 0,
                 'factory_origin': [0, 0, 0],
                 'route_bounds': [400000, 200000, 100000],
                 'route_offsets': [-200000, -100000, 50000],
                 'route_loop': False,
                 'flight_mode': 4,
                 'travel_flag': True},
 'freighter': {'subtype': 1,
               'hull_catalogue_id': 15,
               'faction_draw_bound': 100,
               'position_x_bound': 60000,
               'position_x_offset': -80000,
               'position_sign_bound': 2,
               'position_y_bound': 40000,
               'position_y_offset': -20000,
               'position_z_bound': 160000,
               'position_z_offset': -80000,
               'cargo_multiplier_bound': 4,
               'cargo_multiplier_offset': 2,
               'cargo_floor_bound': 5,
               'cargo_floor_offset': 8,
               'has_generated_patrol_route': False,
               'world_flag': True,
               'assembly': {'root_model_id': 17049,
                            'light_model_id': 17055,
                            'engine_model_id': 17054,
                            'container_model_id': 17052,
                            'container_lod_model_id': 17053,
                            'container_count_bound': 4,
                            'container_positions_z': [-2150.0, 2150.0, 4300.0],
                            'lod_model_id': 17050,
                            'lod_distance': 35000}}}

LAYOUTS = {'population_counts': [-30330,
                       215,
                       '__text',
                       'fd0ec82caafc36e381f5f8f254850cf6a643bfe232a060205860f3de7e51fee3'],
 'empty_fallback': [-29088,
                    121,
                    '__text',
                    '65a472faa3c39e1c2e41296d54ccf6e313ee55ead2ec31ed8f5ccd7e52facdac'],
 'group_order': [-24575,
                 244,
                 '__text',
                 '0175299aaae958165f76c31ea78fb75d5cbc642dbb2815705dcd8e807d44392e'],
 'travel_ship': [-23123,
                 248,
                 '__text',
                 'd945a1996c2528a4fd221b72e9f9b1e6a306a15d6d1a8c3d6208062739f603e5'],
 'travel_route': [-77698,
                  104,
                  '__text',
                  '9319ae262fb3fa97527e836a13e5db719393ac480dc9070bca8e0fc9b8abc66a'],
 'travel_mode': [-77334,
                 26,
                 '__text',
                 '0a01e32bb57bf23a5a0175b5d1731c3b6ca6ec071b7769f9d7120f600bbace6e'],
 'travel_flag': [-79064,
                 14,
                 '__text',
                 '3290bff84bf17ae4fb65f02db29f01af503d7ab9b5bb467c378245fbd907a7e4'],
 'freighter_choice_and_spawn': [-22069,
                                300,
                                '__text',
                                'b4bbf93b54150aa272e1e89b2b1b9b978edd643b718f2f420f0968ec3911cecd'],
 'freighter_constructor': [78543,
                           170,
                           '__text',
                           '2023ee3c9e94a09465667ded62b56ba4428fe55c8e1ca152277b120fcd86e7c1'],
 'freighter_cargo': [631998,
                     210,
                     '__text',
                     'c0efdff509e82cb8c9bece2639e2e95341de1531af50360423ed00806cb64c50'],
 'freighter_assembly': [-218774,
                        635,
                        '__text',
                        '735f98c0a3801456e84cd920cbc76caeb81f7956a27bd2bfe3aac83d180c1f50'],
 'first_container_position': [1557778,
                              4,
                              '__const',
                              'ae7f1c600658137578e6e5495e92bf830791e1b6754eccd0d4acb13076390856'],
 'remaining_container_positions': [1557866,
                                   8,
                                   '__const',
                                   '0bba1a14920c7c3b8accd3c7de6b1c9b5f0ceaa1a8d909f9805d1f1151295081']}


MAC_ALTERNATE = {'population_counts': [-30330,
                       215,
                       '__text',
                       '635f8a15bf71befe5b93c5a7cf9968535a9951c8c797f9d9b48174351b2b3458'],
 'empty_fallback': [-29088,
                    121,
                    '__text',
                    '6c685a026a476ffbd940d1b6ffe1d117b2948caec81bd144845837fb10bcf7cb'],
 'group_order': [-24575, 244, '__text', '4be57f51aef2e05bcf4c16e3253877efc0091c035082e54dd0b50639efd214a2'],
 'travel_ship': [-23123, 248, '__text', '568e1881ff375f9c367bae4f5b6ab0a4657f607747c3b529df2eba7c7b1131c8'],
 'travel_route': [-77698, 104, '__text', '7cbfdc0c5acc3bd38d42bf2085e6f9af2d686e827bfeaaafcabb869810df8cb8'],
 'travel_mode': [-77334, 26, '__text', 'a589ecbd9a495aac117c46401fa020983111bc89e441aaa4c85e8ab32ba8e219'],
 'travel_flag': [-79064, 14, '__text', '3290bff84bf17ae4fb65f02db29f01af503d7ab9b5bb467c378245fbd907a7e4'],
 'freighter_choice_and_spawn': [-22069,
                                300,
                                '__text',
                                '0c9846533f04482d2f425d06fce28c927d0427bacd9b744cfa33093570b838b1'],
 'freighter_constructor': [78543,
                           170,
                           '__text',
                           'b507c7c5a5b5d0a34ae84625e656330a1ce31fddfd97e5c8edbc298e1c2fe24a'],
 'freighter_cargo': [632546,
                     210,
                     '__text',
                     'a105c3590785f2e6c7f863e47e04222c995b89ba02e81ae39e9a33c67755435c'],
 'freighter_assembly': [-219730,
                        635,
                        '__text',
                        '01176ea35b1f4a8b75b466458f0d04760fdb82cae7e6e2be41ed9cb5f810df3a'],
 'first_container_position': [1532778,
                              4,
                              '__const',
                              'ae7f1c600658137578e6e5495e92bf830791e1b6754eccd0d4acb13076390856'],
 'remaining_container_positions': [1532866,
                                   8,
                                   '__const',
                                   '0bba1a14920c7c3b8accd3c7de6b1c9b5f0ceaa1a8d909f9805d1f1151295081']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# Level::createMission: an empty mission, Mido before cursor 16 (mixed traffic), the station.
           'ambient_population_entry': ('_ZN5Level13createMissionEv', 532, 144, 'sha256:dbda03d0d2e7fb93b6a96fec4969e169412a43f79d46b086cf59deecdb84a0a8'),
           # None at station 78, else travel random(2), freighters random(5), patrols random(2) (+ random(2) mixed) + freighters / 4.
           'ambient_population_counts': ('_ZN5Level13createMissionEv', 1754, 116, 'sha256:27e70adbd48af7df4050087b63b740552c0a76e52452c1082bc5c603945e4071'),
           # Attacked friends: at least 7 patrols; an empty population: 4 patrols.
           'ambient_population_empty_fallback': ('_ZN5Level13createMissionEv', 2590, 60, 'sha256:07a2162952e23ae0bd48fd9fadef12d4a067479e5d5a7b3b9f9360d4200da94b'),
           # Patrols first, then travel ships (subtype 0, no waypoint, setDead, a random route, setJumper), then freighters.
           'ambient_population_patrol_first': ('_ZN5Level13createMissionEv', 6244, 10, 'daf860010128c0f28481'),
           'ambient_population_travel_ships': ('_ZN5Level13createMissionEv', 7008, 280, 'sha256:8d05a1f551d701c20b4462ec9dd50e13fc8461e7938da2c4e6312cda7d287a94'),
           # Freighter race (alternate below 30), hull 15 (13 for race 1), moving, random position.
           'ambient_population_freighter': ('_ZN5Level13createMissionEv', 8208, 258, 'sha256:9b1d5647f78e140f9de543f0a6564cb39d0a6fbf3e91b783c61251940f5aff30'),
           'ambient_population_travel_route': ('_ZN8KIPlayer8setRouteEP5Route', 0, 36, 'sha256:2f00603c48d28f9708289d12f63227139eebaa3ce45e155ddc64e7ddf20197b5'),
           'ambient_population_travel_mode': ('_ZN8KIPlayer7setDeadEv', 0, 14, '0421c0f884100021406825f1e1be'),
           'ambient_population_travel_flag': ('_ZN8KIPlayer9setJumperEb', 0, 6, '80f8e8107047'),
           # Subtype 1 builds a PlayerFixedObject; its constructor multiplies the cargo (random(4) + 2, at least random(5) + 8).
           'ambient_population_factory': ('_ZN5Level10createShipEiiiP8Waypointbb', 0, 3112, 'sha256:678eef9996991343994b4360f4e6ce25dc05eb2aab54b3b5f09e665f7f83d91c'),
           'ambient_population_cargo': ('_ZN17PlayerFixedObjectC2EiiP6PlayerP10AEGeometryfff', 0, 804, 'sha256:8e92f8e152d9f1a0c3d99ecc26346df1f048501ee0014047ed2c3a1d67aaec75'),
           # Race 3 freighter: root, light, random(4) containers at -2150, 2150, 4300, engine, LOD 17050 at 35000.
           'ambient_population_assembly': ('_ZN7Globals12getShipGroupEiib', 0, 2116, 'sha256:82d79c62239613267037732bb0cfc994cbdfe697c1466fe5e5ece399a14b7109')}
