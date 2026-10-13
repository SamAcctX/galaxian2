"""Mac declarations connecting the rescue's scene clock and constructed targets.

Android: the LevelScript constructor zeroes the scene clock, MGame::OnUpdate
adds each frame's milliseconds to it, and MGame::OnRender2D hands it to
Radio::draw, which passes it on to Radio::update and each
RadioMessage::triggered (condition 5: elapsed >= value). Player's
constructor leaves the player targetable without a target list;
Level::createCampaignMission excludes the player only at cursor 0;
Level::connectPlayers fills the target lists (Player::addEnemy), and
PlayerFighter::update falls back to target 0 (Player::getEnemy).
"""
import copy
from .declaration_layouts import recognize, recognize_symbols

def extract_arrival_session(mach, arrival, motion, world, handoff):
    if mach.architecture == 'android-armv7':
        try:
            if not motion or not world or not handoff: return {}
            if arrival['campaign_cursor'] != 1 or arrival['actor_kind'] != 3 or arrival['player_update_enabled'] is not False: return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(VALUES), provenance=proof) if proof else {}
    if mach.architecture!='x86_64':return {}
    try:
        if not motion or not world or not handoff:return {}
        if arrival['campaign_cursor']!=1 or arrival['actor_kind']!=3 or arrival['player_update_enabled']:return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        proof=recognize(mach,origin['offset'],[LAYOUTS, MAC_ALTERNATE])
        if not proof:return {}
        result=copy.deepcopy(VALUES);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'opening_rescue_session',
 'campaign_cursor': 1,
 'initial_elapsed_ms': 0,
 'clock_owner': 'scene_controller',
 'clock_before_controller': True,
 'player_target_excluded': False,
 'actor_target_ids': ['player'],
 'target_index': 0,
 'quest_kind': 11,
 'actor_count': 1,
 'player_update_enabled': False}

LAYOUTS = {'clock_initial': [121689, 8, '49c7470800000000'],
 'clock_advance': [365042, 21, '4863c0498b9598000000488b4a084801c848894208'],
 'radio_clock': [390701,
                 27,
                 '488bbba8000000488b5360488b8b98000000488b7108e842760400'],
 'radio_condition_input': [682207,
                           26,
                           '4c63e3488b40084a8b3ce0488b75b04c89f24c89f9e887080000'],
 'elapsed_condition': [685337, 15, '4963471c4c39e00f9ec3e990030000'],
 'elapsed_condition_slot': [686326, 4, '37fcffff'],
 'target_initial': [534407, 4, 'c6436200'],
 'target_list_initial': [535007, 8, '48c7437800000000'],
 'population_cursor': [-33,
                       33,
                       'e848180d003d990000000f8f7d0a000083f8030f8f4301000085c00f848e0a0000'],
 'opening_only_exclusion': [3106, 9, 'c6406201e919b90000'],
 'target_population': [59632,
                       954,
                       '4883bb78010000000f847f0500004c8d2d7d522400498b7d00e81e2f0c008945cc31c9e9dc0000004183ff08750741837e4408745341f6465c0174274c89f7e822d7080083f803751a498b7d00e8a22e0c004889c7be01000000e8df1a0c0084c07525498b842478010000488b40084a8b04f8488b4008488b4db8488b49084863db488904d9ffc3498b84247801000049ffc7443b380f820d0300004983c6084d89f74c89e34c8b75b8498b3f4c89f6e8a94507004d85f67416498b7e084885ff7405e8629816004c89f7e860981600498b7d00e8832e0c004889c7e8633205003c017518837dc80a7512498b3f488b8368010000488b30e8b7440700488b4dd048ffc1488b83780100003b080f837a040000488b40084c8b34c848894dd0418b46448945c84c89f7e8f4e5fdff8845c0488b83780100004531e48338000f84de000000488b4dd085c90f94c1837dcc24410f94c74120cf4531e431db488b4008488b3cd84c39f70f849e0000008b45c83947440f95c00a45c03c010f858a0000004180ff017509e895e5fdff84c0757b8b45cc3d9a000000742783f840753b85db74684d85f67463488b45d085c0752aeb594989c64c89ffe9e4030000ebf3ebf1498b7d00e80f2d0c0084c0740c83fb08750741837e4408743141f6465c0174274c89f7e87cd5080083f803751a498b7d00e8fc2c0c004889c7be01000000e839190c0084c0750341ffc4488b45b0488b807801000048ffc33b180f823bffffffbf18000000e8109716004889c3bf08000000e8fd96160048894308c743100100000048c70000000000c703000000004c8b7db04983bf68010000014183dcff4489e74889de48895db8e835ee0000498b7d00e8e32c0c004989c44c89e7e85631050083f80c7519488b4dd089c8c1e81f01c883e0fe29c183f9010f84790100004c89e7e83031050083f8020f84680100004c89e7e81f31050083f8090f84570100004c89e7e81c3205003c017519498b7d00e8632c0c0083f810750b41837e44090f84320100004c89e7e8f73105003c017519498b7d00e83e2c0c0083f818750b41837e44090f840d0100004c89e7e8d23105003c017519498b7d00e8192c0c0083f81c750b41837e44090f84e80000004c89e7e8ad3105003c017509498b7d00e8f42b0c004c89e7e8983105003c017509498b7d00e8df2b0c00498b876801000031db4885c07413488b4db8488b4908488b00488901bb01000000498b87780100004d89fc8338000f840bfdffff488b4dd085c90f94c1837dcc240f94c220ca8855a84531ff488b40084a8b3cf84c39f70f84cefcffff'],
 'target_append_gate': [536398,
                        31,
                        '554889e5415741564155415453504989f74989fe49837e78000f8415010000'],
 'target_append_empty': [536706,
                         25,
                         '4c89f74c89fe4883c4085b415c415d415e415f5de913fdffff'],
 'target_fallback': [616370,
                     26,
                     '41c7465400000000498b7e0831f6e8d1c9feff498986a0010000'],
 'target_getter': [536982, 22, '554889e54863c6488b4f78488b4908488b04c15dc390']}

# Independently verified alternate Mac compiler layout.
MAC_ALTERNATE = {'clock_initial': [121689, 8, '49c7470800000000'],
 'clock_advance': [364765, 21, '4863c0498b9598000000488b4a084801c848894208'],
 'radio_clock': [391217, 27, '488bbba8000000488b5360488b8b98000000488b7108e862760400'],
 'radio_condition_input': [682755, 26, '4c63e3488b40084a8b3ce0488b75b04c89f24c89f9e887080000'],
 'elapsed_condition': [685885, 15, '4963471c4c39e00f9ec3e990030000'],
 'elapsed_condition_slot': [686874, 4, '37fcffff'],
 'target_initial': [534943, 4, 'c6436200'],
 'target_list_initial': [535543, 8, '48c7437800000000'],
 'population_cursor': [-33, 33, 'e8c01a0d003d990000000f8f7d0a000083f8030f8f4301000085c00f848e0a0000'],
 'opening_only_exclusion': [3106, 9, 'c6406201e919b90000'],
 'target_population': [59632,
                       954,
                       '4883bb78010000000f847f0500004c8d2d55fa2300498b7d00e896310c008945cc31c9e9dc0000004183ff08750741837e4408745341f6465c0174274c89f7e846d9080083f803751a498b7d00e81a310c004889c7be01000000e8571d0c0084c07525498b842478010000488b40084a8b04f8488b4008488b4db8488b49084863db488904d9ffc3498b84247801000049ffc7443b380f820d0300004983c6084d89f74c89e34c8b75b8498b3f4c89f6e8c14707004d85f67416498b7e084885ff7405e8ae3616004c89f7e8ac361600498b7d00e8fb300c004889c7e8673405003c017518837dc80a7512498b3f488b8368010000488b30e8cf460700488b4dd048ffc1488b83780100003b080f837a040000488b40084c8b34c848894dd0418b46448945c84c89f7e8f4e5fdff8845c0488b83780100004531e48338000f84de000000488b4dd085c90f94c1837dcc24410f94c74120cf4531e431db488b4008488b3cd84c39f70f849e0000008b45c83947440f95c00a45c03c010f858a0000004180ff017509e895e5fdff84c0757b8b45cc3d9a000000742783f840753b85db74684d85f67463488b45d085c0752aeb594989c64c89ffe9e4030000ebf3ebf1498b7d00e8872f0c0084c0740c83fb08750741837e4408743141f6465c0174274c89f7e8a0d7080083f803751a498b7d00e8742f0c004889c7be01000000e8b11b0c0084c0750341ffc4488b45b0488b807801000048ffc33b180f823bffffffbf18000000e85c3516004889c3bf08000000e84935160048894308c743100100000048c70000000000c703000000004c8b7db04983bf68010000014183dcff4489e74889de48895db8e835ee0000498b7d00e85b2f0c004989c44c89e7e85a33050083f80c7519488b4dd089c8c1e81f01c883e0fe29c183f9010f84790100004c89e7e83433050083f8020f84680100004c89e7e82333050083f8090f84570100004c89e7e8203405003c017519498b7d00e8db2e0c0083f810750b41837e44090f84320100004c89e7e8fb3305003c017519498b7d00e8b62e0c0083f818750b41837e44090f840d0100004c89e7e8d63305003c017519498b7d00e8912e0c0083f81c750b41837e44090f84e80000004c89e7e8b13305003c017509498b7d00e86c2e0c004c89e7e89c3305003c017509498b7d00e8572e0c00498b876801000031db4885c07413488b4db8488b4908488b00488901bb01000000498b87780100004d89fc8338000f840bfdffff488b4dd085c90f94c1837dcc240f94c220ca8855a84531ff488b40084a8b3cf84c39f70f84cefcffff'],
 'target_append_gate': [536934, 31, '554889e5415741564155415453504989f74989fe49837e78000f8415010000'],
 'target_append_empty': [537242, 25, '4c89f74c89fe4883c4085b415c415d415e415f5de913fdffff'],
 'target_fallback': [616918, 26, '41c7465400000000498b7e0831f6e8c5c9feff498986a0010000'],
 'target_getter': [537518, 22, '554889e54863c6488b4f78488b4908488b04c15dc390']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {'clock_initial': ('_ZN11LevelScriptC2EP5LevelP3HudP5RadarP18TargetFollowCamera', 44, 120, 'sha256:e37c5f60a0b740d41a30fcf5d659181c95b708ec35ea8accfd8da8f0df18a4b7'),
           'clock_advance': ('_ZN5MGame8OnUpdateEv', 1298, 24, 'dbf84000dbf87820d2e90236c1184feae0707041c2e90210'),
           'radio_clock': ('_ZN5MGame10OnRender2DEv', 236, 20, 'a66fd4f88000d6e90223a16dcde90016bcf67aee'),
           # Without a message on screen, Radio::draw tail-calls Radio::update with the clock.
           'radio_update': ('_ZN5Radio4drawExP9PlayerEgoP11LevelScript', 244, 30, 'sha256:b16dd435c292b5cb8604ade360b4ab36c05b9a7bc9a1d8d6d0157dc0b4c4d2a7'),
           'radio_condition_input': ('_ZN5Radio6updateElP9PlayerEgoP11LevelScript', 44, 26, 'sha256:c9d588d76c09ab273357950d27a6eb50eb99c6feac21c9aca93542c17eeb8709'),
           # Conditions 0..31 with the whole tbh table.
           'elapsed_dispatch': ('_ZN12RadioMessage9triggeredExP9PlayerEgoP11LevelScript', 36, 82, 'sha256:da759d9775a9c5f709e1f0b9a7e4f0f8764a8e8b2f0a523db8453f7d5e916d18'),
           'elapsed_condition': ('_ZN12RadioMessage9triggeredExP9PlayerEgoP11LevelScript', 250, 32, 'sha256:7a30d93df318559ced0b155d8128895ebc97f56007e22b7296df57a6dd796d9f'),
           'target_initial': ('_ZN6PlayerC2Eiiiii', 32, 112, 'sha256:15feda8e4274fb67e9e1ebea9a5b71428bb8addaf346e0fbde28ee3dddb86bea'),
           'target_list_initial': ('_ZN6PlayerC2Eiiiii', 396, 72, 'sha256:2ac888e5b2412d3c956ce76e52b6b829cefdb30a6f73cca87b51f3488105fa13'),
           'population_cursor': ('_ZN5Level21createCampaignMissionEv', 50, 76, 'sha256:729e5ebbc06567d4c413d6d28c18e4d68d5c16736559138e77206bb93f09ce25'),
           'exclusion_flag': ('_ZN5Level21createCampaignMissionEv', 24978, 4, '4ff00108'),
           'opening_only_exclusion': ('_ZN5Level21createCampaignMissionEv', 25204, 12, 'd6f8f000006880f85e80c7e3'),
           'target_population': ('_ZN5Level14connectPlayersEv', 0, 1520, 'sha256:4e316991fbb2c7b755197137dad56b58a22cc3a495b4c038877551bc16a7e0ef'),
           'target_append': ('_ZN6Player8addEnemyEPS_', 0, 162, 'sha256:bd070251dbf6a45fa8ce800cff5f0b4b4ba8f99b6e9a1ec2526a8fa143171fb5'),
           'target_fallback': ('_ZN13PlayerFighter6updateEi', 2728, 24, '00200021606360687cf75cec01460029c4f8441132d146e0'),
           'target_getter': ('_ZN6Player8getEnemyEi', 0, 10, '406f406850f821007047')}
