"""Guarded ordinary Vossk freighter declarations.

Android: Globals::getShipGroup builds the Vossk freighter (group 13: body
17013, children 18713 and 17038, LOD meshes 17139 and 17140 at 35000 and
45000, LOD children 17040 and 17041); Level::createMission spawns race-1
freighters as hull 13; Level::createShip gives race 1 five collision boxes
(immediate extents) and wreck 18303; PlayerFixedObject::setWreckedMeshId
(hull 13: layout 4) and PlayerFixedObject::update (layout 4: material
33355). Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_vossk_traffic(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    _, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'ordinary_vossk_freighter',
 'actor_kind': 1,
 'hull_catalogue_id': 13,
 'assembly': {'body_resource_ids': [17013, 17139, 17140],
              'child_resource_ids': [[18713, 17038], [17040], [17041]],
              'lod_distances': [35000, 45000],
              'maximum_distance': 0,
              'model_scale': 1.0},
 'boxes': [{'offset': [0, 351.0, 5827.0],
            'half_extents': [1965.0, 795.0, 1035.0]},
           {'offset': [0, 616.0, 4573.0],
            'half_extents': [2220.0, 1060.0, 517.5]},
           {'offset': [0, 780.0, 3303.0],
            'half_extents': [2485.0, 1310.0, 947.5]},
           {'offset': [0, 456.0, -309.0],
            'half_extents': [1347.5, 1765.0, 3300.0]},
           {'offset': [0, 248.0, -5587.0],
            'half_extents': [1662.5, 1510.0, 2102.5]}],
 'death': {'hull_catalogue_id': 13,
           'model_id': 18303,
           'model_resource': 'resources/data/assets/main/3d/meshes/ships/cargo_004_vossk_explosion_anim.aem',
           'model_scale': 1.0,
           'initial_material_id': 34712,
           'wreck_layout_id': 4,
           'wreck_material_id': 33355}}

LAYOUTS = {'vossk_traffic_assembly_entry': [-219294,
                                  66,
                                  '__text',
                                  'f7b104893dbab2fc04dcadc9d0c0ec535eb4a31a600ec00c1a02d81ba73e0769'],
 'vossk_traffic_spawn_hull': [-22069,
                              138,
                              '__text',
                              'e8a9cfed20c909deacb1e0dd57a1ca531c4246b5895cec4f2458d9f75c367fd1'],
 'vossk_traffic_assembly': [-219228,
                            203,
                            '__text',
                            '74a9a6ceed8736ef9cb4712d42db97b49b59eb66ebd9575727606eb12b57b074'],
 'vossk_traffic_collision_dispatch': [78680,
                                      33,
                                      '__text',
                                      '8eff07574ef3edb080b8deb83e572afad0f8caed5f2f746f063daadaa8329828'],
 'vossk_traffic_collision_table': [81406,
                                   16,
                                   '__text',
                                   '9cb897531f83260a938fb53a50d3374d97de6b0e6205b13f2e9eb0c70390edbf'],
 'vossk_traffic_collision_boxes': [80798,
                                   450,
                                   '__text',
                                   'b5c1f042ee1ad95562d2970c7b0715ee4c14fb05aae6b676af083b32cc03880d'],
 'vossk_traffic_collision_values': [1575402,
                                    80,
                                    '__const',
                                    'a4b50d15b049a55246b46f25bfbf748b56283f2c1fcdc546d168aba41acc0dd3'],
 'vossk_traffic_death_layout': [633685,
                                160,
                                '__text',
                                'bfa024f784bc8e20d5213ea6bfc827dba1d95eb85d2d18408d05e7879664e38f'],
 'vossk_traffic_wreck_table': [638178,
                               20,
                               '__text',
                               'de6e6debcec626d191654edde387c465fcd9775a9e266ee12caebb9ab3827d1c'],
 'vossk_traffic_wreck_material': [637821,
                                  17,
                                  '__text',
                                  '86066642558823bebba2cfe81d710ecc6184b0a8b9cd4b5adc191e61af733416']}

MAC_ALTERNATE = {'vossk_traffic_assembly_entry': [-220250,
                                  66,
                                  '__text',
                                  'f7b104893dbab2fc04dcadc9d0c0ec535eb4a31a600ec00c1a02d81ba73e0769'],
 'vossk_traffic_spawn_hull': [-22069,
                              138,
                              '__text',
                              'e0f9d3407f5c3a0030137c3cc5d17fd209c80265957219f8fb31649defece0c8'],
 'vossk_traffic_assembly': [-220184,
                            203,
                            '__text',
                            '5f1542bf992f0edc90fb59cac2c1f13afc5ac84bf0fa2b234f05324c9c97ebfe'],
 'vossk_traffic_collision_dispatch': [78680,
                                      33,
                                      '__text',
                                      '8eff07574ef3edb080b8deb83e572afad0f8caed5f2f746f063daadaa8329828'],
 'vossk_traffic_collision_table': [81406,
                                   16,
                                   '__text',
                                   '9cb897531f83260a938fb53a50d3374d97de6b0e6205b13f2e9eb0c70390edbf'],
 'vossk_traffic_collision_boxes': [80798,
                                   450,
                                   '__text',
                                   'e3058d617a110b70b4f7a4eac6a710455df6f9a998a8111d6a0b657a1a1458c1'],
 'vossk_traffic_collision_values': [1550466,
                                    80,
                                    '__const',
                                    'a4b50d15b049a55246b46f25bfbf748b56283f2c1fcdc546d168aba41acc0dd3'],
 'vossk_traffic_death_layout': [634233,
                                160,
                                '__text',
                                '0f2b91c853f76e8442e9932cf1e1676645f36c21877aa6cc90a3d5a172ac2610'],
 'vossk_traffic_wreck_table': [638726,
                               20,
                               '__text',
                               'de6e6debcec626d191654edde387c465fcd9775a9e266ee12caebb9ab3827d1c'],
 'vossk_traffic_wreck_material': [638369,
                                  17,
                                  '__text',
                                  '86066642558823bebba2cfe81d710ecc6184b0a8b9cd4b5adc191e61af733416']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# Globals::getShipGroup: group 13.
           'vossk_traffic_assembly_entry': ('_ZN7Globals12getShipGroupEiib', 0, 66, 'sha256:1989d04285bc3ef66dcfc301025b512a55dcb0ce5fbbe2c261eef439720f68d6'),
           'vossk_traffic_assembly': ('_ZN7Globals12getShipGroupEiib', 66, 146, 'sha256:498db4c9310eb2b4a939860da45e9ad084d59d9fb7fe5f6e594eb261028f2465'),
           'vossk_traffic_assembly_children': ('_ZN7Globals12getShipGroupEiib', 1544, 8, '584672f7d0edb7e0'),
           # Level::createMission: race-1 freighters are hull 13.
           'vossk_traffic_spawn_hull': ('_ZN5Level13createMissionEv', 8208, 92, 'sha256:f8a5eb3f4144a97df55a3d582ab7c35cc622e0e77a61e2fbdde431958548a2a4'),
           # Level::createShip: race 1 gets five boxes (offset, full extents) and wreck 18303.
           'vossk_traffic_collision_dispatch': ('_ZN5Level10createShipEiiiP8Waypointbb', 652, 32, 'sha256:2f5b2177c1520112fb18bcddd7658d00f46523c52a42cdbdd5a7ec5dcf74497f'),
           'vossk_traffic_collision_boxes': ('_ZN5Level10createShipEiiiP8Waypointbb', 1774, 426, 'sha256:3ffd43212a4d65d150ec4fd4dadcf46e4e62a9312f010f9382cf388e5c7d5193'),
           # Hull 13 uses wreck layout 4 and material 33355.
           'vossk_traffic_death_layout': ('_ZN17PlayerFixedObject16setWreckedMeshIdEi', 0, 192, 'sha256:0eddfaaefee7aa0a7ffe17609b092f742042a0adf689940f1cea6f89c4a5f57c'),
           'vossk_traffic_wreck_table': ('_ZN17PlayerFixedObject6updateEi', 1988, 28, 'sha256:392270e4c7abca63b24efc6bbe501ce2aba95cc302b1b884c71b30a1b111f839'),
           'vossk_traffic_wreck_material': ('_ZN17PlayerFixedObject6updateEi', 2562, 10, '48f24b200331c4f89c01')}
