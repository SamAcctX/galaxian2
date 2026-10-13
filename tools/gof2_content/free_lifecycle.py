"""Source-bound ordinary combat lifecycle parameters.

Android: Standing::isEnemy and isFriend (axes 0, 0, 1, 1, threshold 70),
SolarSystem::getAttackRace and its table, Level::updateOrbit (patrol and
travel recycling, hostile relaunch in security 0 or 1 or for faction 9),
Level::createShip's Nivelian wreck 18301, PlayerFixedObject::setWreckedMeshId
(race-2 freighters use wreck layout 2) and PlayerFixedObject::update (layout 2
uses material 33353). Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_free_lifecycle(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'augmenta_ordinary_lifecycle',
 'campaign_cursor': 18,
 'system_id': 19,
 'standing': {'axes': [0, 0, 1, 1],
              'hostile_signs': [-1, 1, -1, 1],
              'threshold': 70,
              'unconditional_hostiles': [8]},
 'reactions': {'primary_faction': 0,
               'eligible_factions': [0, 1],
               'radio_requires_empty_mission': True,
               'empty_mission_kind': -1,
               'force_matching_faction_only': True},
 'recycling_groups': ['patrol', 'travel'],
 'hostile_relaunch_security': [0, 1],
 'unrestricted_relaunch_faction': 9,
 'nivelian_death': {'model_id': 18301,
                    'model_resource': 'resources/data/assets/main/3d/meshes/ships/cargo_002_nivelian_explosion_anim.aem',
                    'model_scale': 1.0,
                    'initial_material_id': 34704,
                    'wreck_layout_id': 2,
                    'wreck_material_id': 33353}}

LAYOUTS = {'free_lifecycle_hostile': [807440,
                            128,
                            '__text',
                            '209daf40d4ec5e88c1313c37445ee4a0ef33d73404653b3a058a617a037fae4d'],
 'free_lifecycle_friendly': [807568,
                             128,
                             '__text',
                             'a32c7ef7f73abed32663bdf810d8affba26b4f3c3dccb168afc7abfaa939f8ed'],
 'free_lifecycle_secondary': [734674,
                              76,
                              '__text',
                              '433abfe7fa1b346202bfe1cb54dae5907afbb6497173385ce1b574fe8cfdde65'],
 'free_lifecycle_hostile_relaunch': [113209,
                                     238,
                                     '__text',
                                     '51107402d028bf94a2f9e23a9697b9176a8e57832d49ee24b4c7304311f618a8'],
 'free_lifecycle_nivelian_death': [80766,
                                   17,
                                   '__text',
                                   '5eef5b6741b3d7c71f5ac05c0b0097e4a595c3c862a7cbbeb88a4dd0a23395be'],
 'free_lifecycle_wreck_kind': [633786,
                               41,
                               '__text',
                               '8894666878ea18b59b5fa5e3ed9cdc8848525836630ce74a6568f68227cc7e35'],
 'free_lifecycle_wreck_material': [637724,
                                   129,
                                   '__text',
                                   'c2c94f74f621ab82c7e3f52d5591f4be3f85c6de1c51a1837dcfe64034278a11'],
 'free_lifecycle_wreck_table': [638178,
                                20,
                                '__text',
                                'de6e6debcec626d191654edde387c465fcd9775a9e266ee12caebb9ab3827d1c']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'free_lifecycle_hostile': [808072, 128, '__text', '209daf40d4ec5e88c1313c37445ee4a0ef33d73404653b3a058a617a037fae4d'],
 'free_lifecycle_friendly': [808200, 128, '__text', 'a32c7ef7f73abed32663bdf810d8affba26b4f3c3dccb168afc7abfaa939f8ed'],
 'free_lifecycle_secondary': [735306, 76, '__text', '433abfe7fa1b346202bfe1cb54dae5907afbb6497173385ce1b574fe8cfdde65'],
 'free_lifecycle_hostile_relaunch': [113209,
                                     238,
                                     '__text',
                                     'b3a8e922f30a98bd6330df941a2e933975948f2222febc8c66c1e16b5d550f9c'],
 'free_lifecycle_nivelian_death': [80766,
                                   17,
                                   '__text',
                                   '5eef5b6741b3d7c71f5ac05c0b0097e4a595c3c862a7cbbeb88a4dd0a23395be'],
 'free_lifecycle_wreck_kind': [634334,
                               41,
                               '__text',
                               '8894666878ea18b59b5fa5e3ed9cdc8848525836630ce74a6568f68227cc7e35'],
 'free_lifecycle_wreck_material': [638272,
                                   129,
                                   '__text',
                                   'c2c94f74f621ab82c7e3f52d5591f4be3f85c6de1c51a1837dcfe64034278a11'],
 'free_lifecycle_wreck_table': [638726,
                                20,
                                '__text',
                                'de6e6debcec626d191654edde387c465fcd9775a9e266ee12caebb9ab3827d1c']}

# Android spans inside named functions and their tables; the values are VALUES.
ANDROID = {# Standing: races 0 and 1 share axis 0, races 2 and 3 axis 1; threshold 70.
           'free_lifecycle_hostile': ('_ZN8Standing7isEnemyEi', 0, 118, 'sha256:e48dc557d39a1d28df8cd83c0ffd928da627c0a2e569b8c51369bd5c27b71ce0'),
           'free_lifecycle_friendly': ('_ZN8Standing8isFriendEi', 0, 120, 'sha256:3e77281a49c10603f4c6dc5ce9fa3a5eda0e86c1610935ddc7c30ffcc65d92c4'),
           # The system's attack race: 1, 0, 3, 2.
           'free_lifecycle_secondary': ('_ZN11SolarSystem13getAttackRaceEv', 0, 24, 'c069032884bf082070470249794451f82000704784150d00'),
           'free_lifecycle_secondary_table': ('_ZN11SolarSystem13getAttackRaceEv', 10, 16, '01000000000000000300000002000000', 'literal', 0),
           # Level::updateOrbit: recycling and the hostile relaunch.
           'free_lifecycle_hostile_relaunch': ('_ZN5Level11updateOrbitEi', 0, 1052, 'sha256:edabc61e73ad8ff473372d6f66f756b66c759249da14d06dac4ac6496a41be38'),
           # The Nivelian's wreck model, layout and material.
           'free_lifecycle_nivelian_death': ('_ZN5Level10createShipEiiiP8Waypointbb', 2440, 10, 'd8f8040044f27d71d7e0'),
           'free_lifecycle_nivelian_wreck': ('_ZN5Level10createShipEiiiP8Waypointbb', 2882, 8, '856058469cf748ec'),
           'free_lifecycle_wreck_kind': ('_ZN17PlayerFixedObject16setWreckedMeshIdEi', 0, 192, 'sha256:0eddfaaefee7aa0a7ffe17609b092f742042a0adf689940f1cea6f89c4a5f57c'),
           'free_lifecycle_wreck_material': ('_ZN17PlayerFixedObject6updateEi', 1988, 28, 'sha256:392270e4c7abca63b24efc6bbe501ce2aba95cc302b1b884c71b30a1b111f839'),
           'free_lifecycle_wreck_table': ('_ZN17PlayerFixedObject6updateEi', 2532, 40, 'sha256:b0f0d6f06adef6922fa9d70d59b5292a973b1cb49a182e6135820628d2265ce4')}
