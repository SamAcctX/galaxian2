"""Alioth-specific composition of ordinary NPC lifecycle declarations.

Android: PlayerFighter::update sets Terrans and Voids against each other and
lets NPCs boost (PlayerFighter's constructor); Level::createShip and
PlayerFixedObject (update, setWreckedMeshId) give the hull-15 freighters
explosion model 18302, materials 34708 and 33354 and wreck layout 3;
KIPlayer::createCrate drops Void container 16916; Player::setAlwaysFriend,
Player::damage, Standing::applyKill and applyDelict leave Void kills without
reputation change; SolarSystem::getAttackRace (table 1, 0, 3, 2) makes the
Terran system react for factions 0 and 1; Level::enemyDied counts no pirate
kills for Voids. Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_alioth_lifecycle(mach,arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'alioth_attack_lifecycle',
 'campaign_cursor': 16,
 'system_id': 19,
 'actor_kinds': [0, 0, 0, 9, 9, 9, 9, 0, 0, 0],
 'boost_enabled': True,
 'retains_factory_previous_hull': True,
 'forced_friendly_kind': 0,
 'reaction_factions': [0, 1],
 'primary_faction': 0,
 'void_reputation_change': 0,
 'void_pirate_kills_delta': 0,
 'void_cargo': {'actor_kind': 9,
                'cargo_model_id': 16916,
                'cargo_model_resource': 'resources/data/assets/main/3d/meshes/misc/container_005_void.aem'},
 'freighter_death': {'model_id': 18302,
                     'model_resource': 'resources/data/assets/main/3d/meshes/ships/cargo_003_terran_explosion_anim.aem',
                     'initial_material_id': 34708,
                     'wreck_material_id': 33354,
                     'wreck_layout_id': 3,
                     'model_scale': 1.0}}

LAYOUTS = {'alioth_lifecycle_target_opposition': [614204,
                                        102,
                                        '__text',
                                        '62b39b30851db0c25b74f07c5aee28274bf4cf016e532e6005cbd3c3b39f30a0'],
 'alioth_lifecycle_freighter_factory': [80265,
                                        13,
                                        '__text',
                                        'a1264f8686983324a5c263bc9109bd8311afcc9f7eee946b5ceb496a68fc7d35'],
 'alioth_lifecycle_small_constructor': [605172,
                                        2562,
                                        '__text',
                                        '9872cce6e7b565f4b3dbeb762598ade1997e62a1d03100f33cfc538edab0800b'],
 'alioth_lifecycle_freighter_update': [634134,
                                       4064,
                                       '__text',
                                       '1e9e3720758477dd246383e87b80ea89bc8a9cdba7cd5e597538605c9f146449'],
 'alioth_lifecycle_death_model': [633586,
                                  336,
                                  '__text',
                                  '60031382ce306285da9f4ea5978465bf1295001c511d16e7ae77f2e8c9d07fe7'],
 'alioth_lifecycle_cargo_model': [-77266,
                                  246,
                                  '__text',
                                  '7e06da506e8f222743f1d6b0e003224d24166cedb9039edd7dff476ca1c29979'],
 'alioth_lifecycle_friendship': [535652,
                                 28,
                                 '__text',
                                 '29f61672e56345b7cd33246f9865630c51342b38086156ed5ac59e432e6804c6'],
 'alioth_lifecycle_normal_hit': [538936,
                                 1846,
                                 '__text',
                                 'bf43e8c8d5ea3461a0c97d0794cf51c69df8f95220efcaf59786d0042e357778'],
 'alioth_lifecycle_reputation': [807862,
                                 184,
                                 '__text',
                                 '7f4797053bcd62cc21e8568344868725c355870e45bdac82077f91e504727df1'],
 'alioth_lifecycle_reputation_axis': [808046,
                                      184,
                                      '__text',
                                      '5b9d90ef0f05f3b46532790b83fa6c7a34021c65c17cd8457dd2381ba4a90c31'],
 'alioth_lifecycle_secondary_faction': [734674,
                                        76,
                                        '__text',
                                        '433abfe7fa1b346202bfe1cb54dae5907afbb6497173385ce1b574fe8cfdde65'],
 'alioth_lifecycle_world_death': [106510,
                                  1044,
                                  '__text',
                                  'fd0da3d850f75ea9a1bff6c2779caf478f3180a7fbe79bef18f0b8d76739bc78'],
 'alioth_lifecycle_freighter_wreck_table': [638178,
                                            20,
                                            '__text',
                                            'de6e6debcec626d191654edde387c465fcd9775a9e266ee12caebb9ab3827d1c']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'alioth_lifecycle_target_opposition': [614752,
                                        102,
                                        '__text',
                                        '62b39b30851db0c25b74f07c5aee28274bf4cf016e532e6005cbd3c3b39f30a0'],
 'alioth_lifecycle_freighter_factory': [80265,
                                        13,
                                        '__text',
                                        'a1264f8686983324a5c263bc9109bd8311afcc9f7eee946b5ceb496a68fc7d35'],
 'alioth_lifecycle_small_constructor': [605720,
                                        2562,
                                        '__text',
                                        '69ffded45ed01c0720d4524c45cb78a5be444af55b84ea7c93f85df3bf003325'],
 'alioth_lifecycle_freighter_update': [634682,
                                       4064,
                                       '__text',
                                       '1fcae1e52a8e660198a8848c7aaf10a4d899c62314132da2eb1fcbd6462569f7'],
 'alioth_lifecycle_death_model': [634134,
                                  336,
                                  '__text',
                                  '749376daa2364b02e990cdfdb75449de79c1aa5e426db70ca83dba025b77155c'],
 'alioth_lifecycle_cargo_model': [-77266,
                                  246,
                                  '__text',
                                  '19766516b9a3016a5f6ee02277c456563061ba01343c3edf5abc260c5bc9e1f3'],
 'alioth_lifecycle_friendship': [536188,
                                 28,
                                 '__text',
                                 '29f61672e56345b7cd33246f9865630c51342b38086156ed5ac59e432e6804c6'],
 'alioth_lifecycle_normal_hit': [539472,
                                 1846,
                                 '__text',
                                 '407b208cd78b7b7e70b5bc505bc9509f70781ad9d1af9c2b9a9f80104cd54242'],
 'alioth_lifecycle_reputation': [808494,
                                 184,
                                 '__text',
                                 '4776f5a1b8fe49b57a997912089fc31e318347df429100480034401ee0ced2aa'],
 'alioth_lifecycle_reputation_axis': [808678,
                                      184,
                                      '__text',
                                      '48b146881bbcd041e6fa4b24bc767946e1499bffd52f1a9994b56153fea7ecd4'],
 'alioth_lifecycle_secondary_faction': [735306,
                                        76,
                                        '__text',
                                        '433abfe7fa1b346202bfe1cb54dae5907afbb6497173385ce1b574fe8cfdde65'],
 'alioth_lifecycle_world_death': [106510,
                                  1044,
                                  '__text',
                                  'b2b3dd33cbc5f7ce937530800f3e23c5fa9b2e6630f92dd194b7cff902d9baab'],
 'alioth_lifecycle_freighter_wreck_table': [638726,
                                            20,
                                            '__text',
                                            'de6e6debcec626d191654edde387c465fcd9775a9e266ee12caebb9ab3827d1c']}

# Android spans inside named functions and their tables; the values are VALUES.
ANDROID = {# PlayerFighter::update: Terrans and Voids oppose each other; NPCs boost.
           'alioth_lifecycle_target_opposition': ('_ZN13PlayerFighter6updateEi', 0, 10528, 'sha256:fb79b3bde0fb27a45861c89450940e96ec313695cb5d4b4c290220c25ef78d9e'),
           # Level::createShip: hull 15 gets the freighter explosion model 18302.
           'alioth_lifecycle_freighter_factory': ('_ZN5Level10createShipEiiiP8Waypointbb', 0, 3112, 'sha256:678eef9996991343994b4360f4e6ce25dc05eb2aab54b3b5f09e665f7f83d91c'),
           'alioth_lifecycle_small_constructor': ('_ZN13PlayerFighterC2EiiP6PlayerP10AEGeometryfffb', 0, 1668, 'sha256:9722fa1dff717e74e4f5d93a1ee0e2af195659b26021723e8d5632f5ba9eaf91'),
           # PlayerFixedObject::update / setWreckedMeshId: materials 34708 and 33354, Terran wreck layout 3.
           'alioth_lifecycle_freighter_update': ('_ZN17PlayerFixedObject6updateEi', 0, 2888, 'sha256:f84fa1d1be257b92fd04b8e98c2c500190c596804150929bb95ecb8d0da7a252'),
           'alioth_lifecycle_death_model': ('_ZN17PlayerFixedObject16setWreckedMeshIdEi', 0, 192, 'sha256:0eddfaaefee7aa0a7ffe17609b092f742042a0adf689940f1cea6f89c4a5f57c'),
           # KIPlayer::createCrate: Void cargo is container 16916.
           'alioth_lifecycle_cargo_model': ('_ZN8KIPlayer11createCrateEi', 0, 212, 'sha256:91deeb454ba06465975eb469efc565a2639580023fba721f6c059569ad9060a2'),
           'alioth_lifecycle_friendship': ('_ZN6Player15setAlwaysFriendEb', 0, 20, '80f8ed104ff48071a0f85c10002180f8e0107047'),
           'alioth_lifecycle_normal_hit': ('_ZN6Player6damageEibi', 0, 1376, 'sha256:577391dd7b7a6d8ee3273ce37004ea80f21a4f1a173666529c7b926f4449f3d5'),
           # Standing: Void kills leave the reputation unchanged.
           'alioth_lifecycle_reputation': ('_ZN8Standing9applyKillEi', 0, 104, 'sha256:8bd296216f97e43401c7b59304cac316144c2c3836301212bcd504103a57542a'),
           'alioth_lifecycle_reputation_axis': ('_ZN8Standing11applyDelictEii', 0, 124, 'sha256:262f35c31d0749a01acbf4ae6061d65741bc024e6bdf6ddd6c94ca65ed6fec89'),
           # SolarSystem::getAttackRace: races 0-3 -> 1, 0, 3, 2 (the Terran system reacts for factions 0 and 1).
           'alioth_lifecycle_secondary_faction': ('_ZN11SolarSystem13getAttackRaceEv', 0, 24, 'c069032884bf082070470249794451f82000704784150d00'),
           'alioth_lifecycle_secondary_table': ('_ZN11SolarSystem13getAttackRaceEv', 10, 16, '01000000000000000300000002000000', 'literal', 0),
           # Level::enemyDied: Void deaths count no pirate kills.
           'alioth_lifecycle_world_death': ('_ZN5Level9enemyDiedEib', 0, 636, 'sha256:1d244b76f7d5e2deedc549f316d5bd128ac0dc74646f082c294b69202f2e3b19')}
