"""Original small traffic lifecycle declarations; imported executable bytes are discarded.

Android: Level::update runs Level::updateOrbit without a mission, whose
10-second check relaunches one parked travel ship and 45-second check the
parked patrols; PlayerFighter::revive (Player::reset, Route::reset) relaunches,
PlayerFighter::update parks, times and sends ships out (x1.1 up to 100);
KIPlayer::setDead, isDead and isJumper, PlayerFighter::setPosition, Level's
and KIPlayer's constructors (clocks, travel flag) complete it. Freighters keep
KIPlayer::revive (PlayerFixedObject's vtable slot 6), which does nothing.
Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants, vtable_proof
from .ambient_combat import VALUES as COMBAT_VALUES

def extract_ambient_lifecycle(mach,arrival,combat):
    if not isinstance(combat,dict) or any(combat.get(key)!=value for key,value in COMBAT_VALUES.items()):return {}
    if mach.architecture=='android-armv7':
        proof,slots=(recognize_symbols(mach,ANDROID),vtable_proof(mach,ANDROID_VTABLES)) if arrival else ({},None)
        if not proof or slots is None:return {}
        result=copy.deepcopy(VALUES);result['recycling']=copy.deepcopy(RECYCLING);result['provenance']={**proof,**slots}
        return result
    _variant,proof=hashed_variants(mach,arrival,[{**LAYOUTS,**RECYCLING_LAYOUTS},{**MAC_ALTERNATE,**MAC_RECYCLING_LAYOUTS}])
    if not proof:return {}
    result=copy.deepcopy(VALUES);result['recycling']=copy.deepcopy(RECYCLING);result['provenance']=proof
    return result

VALUES = {'scope': 'early_mido_small_traffic_lifecycle',
 'campaign_cursor': 11,
 'station_id': 79,
 'system_id': 15,
 'actor_kind': 3,
 'subtype': 0,
 'initial_mode': 4,
 'initial_active': False,
 'launch_check_after_ms': 10000,
 'launches_per_check': 1,
 'launch_mode': 1,
 'launch_origin': [0, 0, 0],
 'launch_preserves_axes': True,
 'launch_regenerates_cargo': True,
 'launch_resets_route': True,
 'launch_preserves_selection_boost_clocks': True,
 'departure_after_route_ms': 20000,
 'departure_mode': 6,
 'departure_speed_multiplier': 1.100000023841858,
 'park_above_speed': 100.0,
 'departure_updates_statistics_pose': False,
 'departure_updates_bank': False,
 'parked_clock_limit_ms': 60000}

LAYOUTS = {'park': [-77334, 26, '__text', '0a01e32bb57bf23a5a0175b5d1731c3b6ca6ec071b7769f9d7120f600bbace6e'],
 'parked_predicate': [-77838,
                      16,
                      '__text',
                      '2408009213c5e1377a02f9da45216448c38bf392c93abb7ff5cdc656da230d19'],
 'travel_predicate': [-79050,
                      14,
                      '__text',
                      'e5369924aff43e1f9f253a415fbf7974c29e1d850472350107a7ed2dd09b20d6'],
 'relaunch': [630620,
              488,
              '__text',
              '302774d9a49c0b2ed2f5e298d01de178df2ceefd2f3a94f3c0958b99393adb54'],
 'restore_statistics': [535818,
                        164,
                        '__text',
                        '43f9cd8ea7b7ed9534656284746856827c579d45f5ad361e3210b2a5db121509'],
 'reset_route': [722150,
                 60,
                 '__text',
                 'b6dd231e309f76b618d6725b5249d2d078acb58139f2714ac16cad6a6d3fa0e2'],
 'periodic_check': [112696,
                    186,
                    '__text',
                    'cd3d48d1e97f0b34d655f4d689fb3854bed3fda8539671db93b8f4959a4401e6'],
 'ordinary_timer_entry': [112550,
                          21,
                          '__text',
                          '51b181dad025ec70284b01c36551fc49aef836e6192d98fb65f95da8b06069ff'],
 'world_schedule': [117678,
                    71,
                    '__text',
                    'e4a3f4cd8a8c94e867a4e0d0e13faf0d8690bf27b2710c87f6f0fc60485bfcfa'],
 'actor_timers': [610806,
                  75,
                  '__text',
                  'f7e0f34f1e12fdb23b27d050be4f50d3459ed93f783954b2e914e0e8cc58a35a'],
 'route_clock': [616728,
                 87,
                 '__text',
                 '2d9411c9893c78a5d4c8e939311c2693989e29ae5b2cf213e145d9e0ff0ceec3'],
 'outbound': [619552,
              130,
              '__text',
              '30509cf4d30d079cb533f1bfccf3bb51a37c18e75e8ac662dde6953b3a74e1d0'],
 'mode_table': [627906,
                40,
                '__text',
                '03414b94bcae54c25b57a0fe3067f93f0284bda1ded55bdd145b21f6b1f37c76'],
 'multiplier': [1557770,
                4,
                '__const',
                'e7d9a957c3c942d3551b291f30acbb11064e373eb6adcf4dc54671f8a64f965f'],
 'speed_limit': [1556926,
                 4,
                 '__const',
                 '2238f30df488055daf5e8f362cf904e370011a172d20df193c1b7ae8e5db8e01']}

RECYCLING = {'patrol_check_after_ms': 45000,
 'patrol_launch_all_inactive': True,
 'killed_small_ships_recycle': True,
 'freighters_recycle': False,
 'initial_world_clocks_ms': 0,
 'launch_statistics_from_root': True}

RECYCLING_LAYOUTS = {'patrol_check': [112882,
                  327,
                  '__text',
                  'b289bf86715f0a43defa2012590bc1a95cd8a20e2eb096b3ae11231584182da1'],
 'patrol_iteration': [113730,
                      22,
                      '__text',
                      '3213af3110b3ea24f41e7c3c6a04ee6a10c06b4f4d9e8702b09b7b5bfa9eb823'],
 'initial_clocks': [-45856,
                    11,
                    '__text',
                    'b724e3f689db04f7ade3c8b6539dad7c0a562a8dc6b9adbff7503fa7d7d32868'],
 'initial_travel_flag': [-81071,
                         7,
                         '__text',
                         '146a8ca310e8a0199dfaf6dba19b55dfcb74ee0b074430df25c5315ed39112ab'],
 'freighter_reset_dispatch': [2399978,
                              8,
                              '__const',
                              '8888bd9e9a35a86cac4b420c8aa9c47ba712e2affa3ce0cc71a03f9eca52f44f'],
 'freighter_no_reset': [-76880,
                        6,
                        '__text',
                        '5a96d1fb661d55552184ea24023ae8190bd1523ae1f855a8d671b07143e8b1df'],
 'launch_position': [609228,
                     176,
                     '__text',
                     'f9f75567832a61860218b92636f68ab668e8cb6beb1f666598fc7c95a5397c25']}


MAC_ALTERNATE = {'park': [-77334, 26, '__text', 'a589ecbd9a495aac117c46401fa020983111bc89e441aaa4c85e8ab32ba8e219'],
 'parked_predicate': [-77838,
                      16,
                      '__text',
                      '2408009213c5e1377a02f9da45216448c38bf392c93abb7ff5cdc656da230d19'],
 'travel_predicate': [-79050,
                      14,
                      '__text',
                      'e5369924aff43e1f9f253a415fbf7974c29e1d850472350107a7ed2dd09b20d6'],
 'relaunch': [631168, 488, '__text', 'f270e9310027c3e20016b7928bb8b2d66519e2960379dc66ec60a3ea5c184f4e'],
 'restore_statistics': [536354,
                        164,
                        '__text',
                        '43f9cd8ea7b7ed9534656284746856827c579d45f5ad361e3210b2a5db121509'],
 'reset_route': [722774, 60, '__text', '98a1446d8ffbfa081cc64a140407a0963cf6d951aa2fa30633e6757744493278'],
 'periodic_check': [112696,
                    186,
                    '__text',
                    '0bb452ba827952b8a4799e715f544360101b2bd50c64cd34bb2e50fd65432b71'],
 'ordinary_timer_entry': [112550,
                          21,
                          '__text',
                          '51b181dad025ec70284b01c36551fc49aef836e6192d98fb65f95da8b06069ff'],
 'world_schedule': [117678, 71, '__text', '7dfc1cfdaf9260872a5258bffa52c0c97ada7e8473da917c3a7ded29ea841b56'],
 'actor_timers': [611354, 75, '__text', '4e13a6b9b4fe198a066e66a237d2acd1dcb3c50bc17e00bdadccef025da92967'],
 'route_clock': [617276, 87, '__text', '2d9411c9893c78a5d4c8e939311c2693989e29ae5b2cf213e145d9e0ff0ceec3'],
 'outbound': [620100, 130, '__text', '4ed9ceec36fedbed1f8595b2f90a0c773383d5e1147682454dc919e5f0382fad'],
 'mode_table': [628454, 40, '__text', '03414b94bcae54c25b57a0fe3067f93f0284bda1ded55bdd145b21f6b1f37c76'],
 'multiplier': [1532770, 4, '__const', 'e7d9a957c3c942d3551b291f30acbb11064e373eb6adcf4dc54671f8a64f965f'],
 'speed_limit': [1531926, 4, '__const', '2238f30df488055daf5e8f362cf904e370011a172d20df193c1b7ae8e5db8e01']}


MAC_RECYCLING_LAYOUTS = {'patrol_check': [112882, 327, '__text', 'b5c4ee2efc7fe4b696003a37385c60426a5825add9ff54548de51c8166c404e6'],
 'patrol_iteration': [113730,
                      22,
                      '__text',
                      '3213af3110b3ea24f41e7c3c6a04ee6a10c06b4f4d9e8702b09b7b5bfa9eb823'],
 'initial_clocks': [-45856, 11, '__text', 'b724e3f689db04f7ade3c8b6539dad7c0a562a8dc6b9adbff7503fa7d7d32868'],
 'initial_travel_flag': [-81071,
                         7,
                         '__text',
                         '146a8ca310e8a0199dfaf6dba19b55dfcb74ee0b074430df25c5315ed39112ab'],
 'freighter_reset_dispatch': [2377410,
                              8,
                              '__const',
                              '5de62da353d5ca355edae4d5dc20bbce8e6bf852f4bab4214781dc0e1ebdd199'],
 'freighter_no_reset': [-76880,
                        6,
                        '__text',
                        '5a96d1fb661d55552184ea24023ae8190bd1523ae1f855a8d671b07143e8b1df'],
 'launch_position': [609776,
                     176,
                     '__text',
                     'd7f595d98dfbf167120727344ec27bdcb00027b44c1345292f575de7c9197330']}

# Android spans inside named functions; the values are VALUES and RECYCLING.
ANDROID = {'ambient_lifecycle_park': ('_ZN8KIPlayer7setDeadEv', 0, 14, '0421c0f884100021406825f1e1be'),
           'ambient_lifecycle_parked_predicate': ('_ZN8KIPlayer6isDeadEv', 0, 14, 'd0f884100020042908bf01207047'),
           'ambient_lifecycle_travel_predicate': ('_ZN8KIPlayer8isJumperEv', 0, 6, '90f8e8007047'),
           # Mode 1, statistics, route, active, cargo regenerated.
           'ambient_lifecycle_relaunch': ('_ZN13PlayerFighter6reviveEv', 0, 316, 'sha256:ef14794e6764f20f4a8bb0000de97841d269f81c619b0045e157329dcb2e4ed7'),
           'ambient_lifecycle_restore_statistics': ('_ZN6Player5resetEv', 0, 104, 'sha256:2edd38904be2e74cd6c9ff220eca3babafbad4f0e5359dfa412ff0ec9acc5b51'),
           'ambient_lifecycle_reset_route': ('_ZN5Route5resetEv', 0, 40, 'sha256:22640bfc27f23394c2da5021b9de3b6e3746748530f127725eaecfedca0330f5'),
           # After 10000 ms one parked inactive travel ship; after 45000 ms every parked inactive patrol.
           'ambient_lifecycle_orbit_checks': ('_ZN5Level11updateOrbitEi', 0, 1052, 'sha256:edabc61e73ad8ff473372d6f66f756b66c759249da14d06dac4ac6496a41be38'),
           'ambient_lifecycle_world_schedule': ('_ZN5Level6updateExb', 150, 44, 'sha256:40c2e81e8712d3cccc5dd7e237ccbf6d0fee777b18644e4602bf14175c4d3238'),
           # Parked inactive after 60000 ms, out after 20000 ms on the route (mode 6), speed x1.1 until 100, parked.
           'ambient_lifecycle_actor_update': ('_ZN13PlayerFighter6updateEi', 0, 10528, 'sha256:fb79b3bde0fb27a45861c89450940e96ec313695cb5d4b4c290220c25ef78d9e'),
           'ambient_lifecycle_initial_clocks': ('_ZN5LevelC2Ei', 0, 368, 'sha256:674e05b63506a4f8a5d8427bbdd966a37e21eb72c8dc620d1fd5ba4b6b154eb4'),
           'ambient_lifecycle_initial_travel_flag': ('_ZN8KIPlayerC2EiiP6PlayerP10AEGeometryfffb', 0, 604, 'sha256:3a02b0c7ce6b25d113ff6b119a914a61a149997d03f3853b159537f02d2efee8'),
           'ambient_lifecycle_freighter_no_reset': ('_ZN8KIPlayer6reviveEv', 0, 2, '7047'),
           'ambient_lifecycle_launch_position': ('_ZN13PlayerFighter11setPositionEfff', 0, 120, 'sha256:84b11cc073cadac276caa21eb0eef09b9016bb682c15fad91054bd0e74a4dbe8')}

# The relaunch calls slot 6 (revive); freighters inherit KIPlayer's.
ANDROID_VTABLES = {'ambient_lifecycle_freighter_reset_dispatch': ('_ZTV17PlayerFixedObject', 6, ['_ZN8KIPlayer6reviveEv'])}
