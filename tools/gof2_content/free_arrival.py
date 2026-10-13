"""Static ordinary local-arrival declarations, without executable payloads.

Android: MGame::updateJumpScene marks the arrival at the programmed station
(stream-out and alien-world flags); Level::createMission places a pirate
ambush (chance 20, 40 in hard mode (Status::hardCoreMode: difficulty 1.5),
plus the rank (Status::getLevel), at a third of the player's position via
PlayerEgo::getPosition, AEGeometry::getPosition and MatrixGetPosition);
Status::inPirateLootOrbit excludes systems 32 and 33. Values equal the Mac
ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_free_arrival(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'augmenta_ordinary_arrival',
 'campaign_cursor': 18,
 'system_id': 19,
 'arrival_flags': {'special_arrival': True, 'void_encounter': False},
 'pirate_faction': 8,
 'chance_bound': 100,
 'normal_chance': 20,
 'hard_chance': 40,
 'hard_difficulty': 1.5,
 'rank_added_to_chance': True,
 'chance_strict': True,
 'position_multiplier': 3.0,
 'selection_after_shared_hull': True,
 'selection_before_count_test': True,
 'excluded_special_systems': [32, 33]}

LAYOUTS = {'free_arrival_marker': [382634,
                         133,
                         '__text',
                         'ad178991c15d578414cd9d3fd1946b9f7bacecd15aa39755bca9529880231ff4'],
 'free_arrival_ambush': [-19839,
                         241,
                         '__text',
                         '53dd79083407e14e1f1e850b2cab5ec429526bed5abe165efda4d95f4fdee8f2'],
 'free_arrival_rank': [876350,
                       12,
                       '__text',
                       '1847659543b75281d1875a91cb669f7023d2e352208c89e5c69e2cc33a63d323'],
 'free_arrival_player_position': [562384,
                                  14,
                                  '__text',
                                  'f9d5ad8d7b443442cf0d5727030f98436a9d2267070ae8756b094e9fdb2e1009'],
 'free_arrival_entity_position': [-724356,
                                  26,
                                  '__text',
                                  'a32a7c0670a86e479209a49a083875787681b21ed0914e9502639a43d2f14b1a'],
 'free_arrival_matrix_position': [1241402,
                                  96,
                                  '__text',
                                  'c295638c90864edb169972d0ef2209e46964b25da3309b92ef6effc0e808b3fc'],
 'free_arrival_position_scale': [1556910,
                                 4,
                                 '__const',
                                 'ea2845900b5856c9bf354b1aa9761b5aa6888e5ed61738fe9579ca42bc0f6054'],
 'free_arrival_hard_mode': [873106,
                            34,
                            '__text',
                            '772e4253a1151693501f93bb93c4d6abfc10747fa7bfc0634c3dcf6b746d6eb0'],
 'free_arrival_other_systems': [873024,
                                82,
                                '__text',
                                '0f9a27951abc4649ee11912bd405691eeabe646f5e30faa689d964ba79547f03'],
 'free_arrival_hard_constant': [1545698,
                                4,
                                '__const',
                                'c0e336a5f371ef22cd534e094269f2c1a9635cd080b71ffa671086832d3b60b7']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'free_arrival_marker': [383150, 133, '__text', '496b468c5b0b689ab4ae06e9be9c42c24ea62d4a9a5c9b02cf5a361a698402f5'],
 'free_arrival_ambush': [-19839, 241, '__text', 'cbd3789ad2e57cdd6591d0b136697b1b04b1e66201fb8ab76e96435d7f66d0ab'],
 'free_arrival_rank': [876982, 12, '__text', '1847659543b75281d1875a91cb669f7023d2e352208c89e5c69e2cc33a63d323'],
 'free_arrival_player_position': [562920,
                                  14,
                                  '__text',
                                  '6b974b73bfd965f5b86686bff7eb833b826897ff281fc77648780734f535f38a'],
 'free_arrival_entity_position': [-730252,
                                  26,
                                  '__text',
                                  'cdfdc367ae782b1b2c866a6baf2c66d3aef870696cfdeef3554f84dbc75f2600'],
 'free_arrival_matrix_position': [1234194,
                                  96,
                                  '__text',
                                  '75a2032bb9fc753fff283f0ba674c5947d97ca4e3687d53eeb473f94c9105cca'],
 'free_arrival_position_scale': [1531910,
                                 4,
                                 '__const',
                                 'ea2845900b5856c9bf354b1aa9761b5aa6888e5ed61738fe9579ca42bc0f6054'],
 'free_arrival_hard_mode': [873738, 34, '__text', '076648f688f537e222fb0b777cb3bce1534326a36c5b5004940cbeb4f3b451c3'],
 'free_arrival_other_systems': [873656,
                                82,
                                '__text',
                                '0f9a27951abc4649ee11912bd405691eeabe646f5e30faa689d964ba79547f03'],
 'free_arrival_hard_constant': [1520682,
                                4,
                                '__const',
                                'c0e336a5f371ef22cd534e094269f2c1a9635cd080b71ffa671086832d3b60b7']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# MGame::updateJumpScene: arrival at the programmed station sets both flags.
           'free_arrival_marker': ('_ZN5MGame15updateJumpSceneEv', 692, 100, 'sha256:aed0e3c77e1e07358a8549b4a0d67d5f1b96d102153239a38e2e80bfcee64c94'),
           # Level::createMission: pirates closer by a third with chance 20 (hard 40) plus the rank.
           'free_arrival_ambush': ('_ZN5Level13createMissionEv', 9312, 122, 'sha256:931ee15600e589bda4648fbb4eed667300a3b4239cf64c9d58d86a06b35d8892'),
           # The rank, the positions, hard mode and the excluded systems 32 and 33.
           'free_arrival_rank': ('_ZN6Status8getLevelEv', 0, 6, 'd0f8c8017047'),
           'free_arrival_player_position': ('_ZN9PlayerEgo11getPositionEv', 0, 12, '80b56f468968c3f752ea80bd'),
           'free_arrival_entity_position': ('_ZN10AEGeometry11getPositionEv', 0, 26, 'sha256:b9c206761276e9c203fbee1b2dbbde7151babe54fc1343e0edc216c8b9c0e609'),
           'free_arrival_matrix_position': ('_ZN11AbyssEngine6AEMath17MatrixGetPositionERKNS0_6MatrixE', 0, 14, 'cb69ca68c96ac0e9002381607047'),
           'free_arrival_hard_mode': ('_ZN6Status12hardCoreModeEv', 0, 36, 'sha256:d129eedb895b5a8cc5da84fbd316ee5effaae7d16ec57c3ef53f54ee21bd7b12'),
           'free_arrival_other_systems': ('_ZN6Status17inPirateLootOrbitEv', 0, 58, 'sha256:989574c3e2542fc7a66fe791589c68bc24eef4922a33520edfbed7f4252c7ee1')}
