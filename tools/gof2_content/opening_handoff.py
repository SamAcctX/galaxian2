"""Mac declarations for retained state at the supported Opening boundary.

Android: Status::gameWon is the cursor > 44 test, Status::checkForLevelUp
sums the scores against its 21 thresholds. Status::resetGame clears the
wingmen, makes an empty Station (index -1, compared by Station::equals) and a
fresh Standing (30, 0, no signature race). Standing::isEnemy(1) is hostile
above 70 or with signature race 0; Standing::applyKill passes pirate kills to
Standing::applyDelict as one point for the system race's table entry,
doubled by Status::hardCoreMode, clamped to +-100. Ship::refreshValue clears
the signature race and sets it from equipment sort 29 (item index - 189).
"""
import copy
from .declaration_layouts import recognize, recognize_symbols

def extract_opening_handoff(mach, arrival, actors, world):
    if mach.architecture == 'android-armv7':
        try:
            npc = actors['npc_initialization']
            hull = npc['hull']
            if not world or not npc['death_accounting'] or not actors['player_initialization']['flight_cache']: return {}
            if hull['rank'] != 0 or hull['base_hull'] != 20 or 'rank_calculation' not in hull['provenance']: return {}
            if arrival['campaign_cursor'] != 1 or arrival['actor_kind'] != 3: return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(VALUES), provenance=proof) if proof else {}
    if mach.architecture!='x86_64':return {}
    try:
        npc=actors['npc_initialization']
        hull=npc['hull']
        if not world or not npc['death_accounting'] or not actors['player_initialization']['flight_cache']:return {}
        if hull['rank']!=0 or hull['base_hull']!=20 or 'rank_calculation' not in hull['provenance']:return {}
        if arrival['campaign_cursor']!=1 or arrival['actor_kind']!=3:return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        proof=recognize(mach,origin['offset'],[LAYOUTS, MAC_ALTERNATE])
        if not proof:return {}
        result=copy.deepcopy(VALUES);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'fresh_opening_handoff',
 'opening_cursor': 0,
 'arrival_cursor': 1,
 'center_cursor_upper_inclusive': 44,
 'initial_other_score': 0,
 'player_kill_weight': 1,
 'pirate_kill_weight': 2,
 'cursor_weight': 1,
 'rank_thresholds': [0,
                     7,
                     21,
                     42,
                     70,
                     105,
                     147,
                     196,
                     252,
                     315,
                     385,
                     462,
                     546,
                     637,
                     735,
                     840,
                     952,
                     1071,
                     1197,
                     1330,
                     1650],
 'initial_companion_count': 0,
 'initial_location_wrapper_id': -1,
 'initial_reputation': [30, 0],
 'initial_reputation_override': -1,
 'pirate_reputation_change_maximum': 2,
 'rescue_reputation_axis': 1,
 'rescue_hostile_above': 70,
 'rescue_hostile_override': 2,
 'reputation_override_equipment_type': 29}

LAYOUTS = {'cursor_predicate': ['__text', 858140, 16, '554889e583bf780200002c0f9fc05dc3'],
 'rank_calculation': ['__text',
                      876028,
                      136,
                      '554889e58b8ff40000008b87340100004863c94869f11f85eb514863c04869c8565555554989c849c1e83f4889f248c1ea3f48c1ee20c1fe0431c001d648c1e9204401c1038f50020000448b8754020000488d15e6ea0a0001f1038ff8000000038f78020000428d0c41038f600200003b0a7c068987580200004883c204ffc083f81575eb5dc390'],
 'rank_thresholds': ['__const',
                     1591610,
                     84,
                     '0000000007000000150000002a000000460000006900000093000000c4000000fc0000003b01000081010000ce010000220200007d020000df02000048030000b80300002f040000ad0400003205000072060000'],
 'fresh_companions': ['__text', 881087, 16, '49c746380000000041c7464c00000000'],
 'fresh_location_wrapper': ['__text',
                            854382,
                            28,
                            'bf48000000e8b4780a004989c74c89ffe8b1f1ffff4c89bbb8000000'],
 'wrapper_defaults': ['__text', 850809, 14, 'c74310ffffffffc74314ffffffff'],
 'location_comparison': ['__text',
                         853288,
                         22,
                         '554889e530c04885f674098b47103b46100f94c05dc3'],
 'reputation_initial': ['__text',
                        806990,
                        50,
                        '554889e553504889fbbf08000000e8c5310b00488903c7001e000000c7400400000000c74308ffffffff4883c4085b5dc390'],
 'fresh_reputation': ['__text',
                      882961,
                      33,
                      '49c7461800000000bf10000000e809090a004889c34889dfe820d7feff49895e18'],
 'hostility': ['__text',
               807440,
               128,
               '554889e58b4f0885c9783483fe01750785c90f94c0eb6683fe03741383fe02741630c085f6755683f9010f94c0eb4e83f9020f94c0eb4683f9030f94c0eb3e83fe01750b488b078338460f9fc0eb2e83fe03741383fe02741a30c085f6751e488b078338baeb13488b07837804460f9fc0eb0a488b07837804ba0f9cc05dc390'],
 'pirate_reputation': ['__text',
                       807862,
                       168,
                       '554889e541565389f34989fe488d05b9e71800488b38e8f9c3000088c1b80900000084c97517488d059fe71800488b38e827fd00004889c7e8d5e1feffba0500000083fb08754e41837e08007955ba0100000083f803773d89c0488d0d47000000486304814801c8ffe0bb01000000ba01000000eb1fba0100000031dbeb16ba01000000bb03000000eb0aba01000000bb020000004c89f789de5b415e5de9150000005b415e5dc3'],
 'reputation_adjustment': ['__text',
                           808046,
                           168,
                           '554889e54157415653504189d64189f74889fb488d05fae61800488b38e802fe000088c141d3e64183ff0377704489f8488d0d71000000486304814801c8ffe0488b03440130488b038b0883f9657c08c70064000000eb4583f99b7f40c7009cffffffeb38488b03442930ebd9488b0344017004488b038b480483f9657c12c7400464000000eb15488b0344297004ebe383f99b7f07c740049cffffff4883c4085b415e415f5dc3'],
 'reputation_double_predicate': ['__text',
                                 873106,
                                 34,
                                 '554889e5488d0549e91700f30f10402cf30fc20537430a0000660f7ec083e0015dc3'],
 'reputation_mask_reset': ['__text',
                           727691,
                           54,
                           '41c74760ffffffff488b384885ff7426e8aa4402004885c0741c488d05d6201a00488b38e8964402004889c7beffffffffe8c3360100'],
 'equipment_dispatch': ['__text',
                        727786,
                        42,
                        '488b48084a8b3c314885ff0f84cd020000e8569af3ff83f81d0f87a602000089c0486304834801d8ffe0'],
 'equipment_table': ['__text',
                     728830,
                     120,
                     '16fcffff16fcffff16fcffff16fcffffb1feffffb1feffffb1feffffb1feffff16fcffff74fcffff5dfdffffb1feffffadfcffffb1feffffebfcffff7cfdffff3efdffffccfcffff9ffdffffb1feffffb3fdffffa9fdffffb1feffffb1feffffb1feffff16fcffffb1feffff68feffffd2fdffff6ffeffff'],
 'equipment_override': ['__text',
                        728429,
                        66,
                        '498b4770488b40084a8b3c30e8bc97f3ff0543ffffff41894760498b3c244885ff741fe8b54102004885c07415498b3c24e8a7410200418b77604889c7e8d5330100']}

# Independently verified alternate Mac compiler layout.
MAC_ALTERNATE = {'cursor_predicate': ['__text', 858772, 16, '554889e583bf780200002c0f9fc05dc3'],
 'rank_calculation': ['__text',
                      876660,
                      136,
                      '554889e58b8ff40000008b87340100004863c94869f11f85eb514863c04869c8565555554989c849c1e83f4889f248c1ea3f48c1ee20c1fe0431c001d648c1e9204401c1038f50020000448b8754020000488d1526870a0001f1038ff8000000038f78020000428d0c41038f600200003b0a7c068987580200004883c204ffc083f81575eb5dc390'],
 'rank_thresholds': ['__const',
                     1566706,
                     84,
                     '0000000007000000150000002a000000460000006900000093000000c4000000fc0000003b01000081010000ce010000220200007d020000df02000048030000b80300002f040000ad0400003205000072060000'],
 'fresh_companions': ['__text', 881719, 16, '49c746380000000041c7464c00000000'],
 'fresh_location_wrapper': ['__text', 855014, 28, 'bf48000000e888140a004989c74c89ffe8b1f1ffff4c89bbb8000000'],
 'wrapper_defaults': ['__text', 851441, 14, 'c74310ffffffffc74314ffffffff'],
 'location_comparison': ['__text', 853920, 22, '554889e530c04885f674098b47103b46100f94c05dc3'],
 'reputation_initial': ['__text',
                        807622,
                        50,
                        '554889e553504889fbbf08000000e899cd0a00488903c7001e000000c7400400000000c74308ffffffff4883c4085b5dc390'],
 'fresh_reputation': ['__text', 883593, 33, '49c7461800000000bf10000000e8dda409004889c34889dfe820d7feff49895e18'],
 'hostility': ['__text',
               808072,
               128,
               '554889e58b4f0885c9783483fe01750785c90f94c0eb6683fe03741383fe02741630c085f6755683f9010f94c0eb4e83f9020f94c0eb4683f9030f94c0eb3e83fe01750b488b078338460f9fc0eb2e83fe03741383fe02741a30c085f6751e488b078338baeb13488b07837804460f9fc0eb0a488b07837804ba0f9cc05dc390'],
 'pirate_reputation': ['__text',
                       808494,
                       168,
                       '554889e541565389f34989fe488d05198d1800488b38e8f9c3000088c1b80900000084c97517488d05ff8c1800488b38e827fd00004889c7e8d5e1feffba0500000083fb08754e41837e08007955ba0100000083f803773d89c0488d0d47000000486304814801c8ffe0bb01000000ba01000000eb1fba0100000031dbeb16ba01000000bb03000000eb0aba01000000bb020000004c89f789de5b415e5de9150000005b415e5dc3'],
 'reputation_adjustment': ['__text',
                           808678,
                           168,
                           '554889e54157415653504189d64189f74889fb488d055a8c1800488b38e802fe000088c141d3e64183ff0377704489f8488d0d71000000486304814801c8ffe0488b03440130488b038b0883f9657c08c70064000000eb4583f99b7f40c7009cffffffeb38488b03442930ebd9488b0344017004488b038b480483f9657c12c7400464000000eb15488b0344297004ebe383f99b7f07c740049cffffff4883c4085b415e415f5dc3'],
 'reputation_double_predicate': ['__text',
                                 873738,
                                 34,
                                 '554889e5488d05a98e1700f30f10402cf30fc20507df090000660f7ec083e0015dc3'],
 'reputation_mask_reset': ['__text',
                           728315,
                           54,
                           '41c74760ffffffff488b384885ff7426e8b24402004885c0741c488d053ec61900488b38e89e4402004889c7beffffffffe8cb360100'],
 'equipment_dispatch': ['__text',
                        728410,
                        42,
                        '488b48084a8b3c314885ff0f84cd020000e8e697f3ff83f81d0f87a602000089c0486304834801d8ffe0'],
 'equipment_table': ['__text',
                     729454,
                     120,
                     '16fcffff16fcffff16fcffff16fcffffb1feffffb1feffffb1feffffb1feffff16fcffff74fcffff5dfdffffb1feffffadfcffffb1feffffebfcffff7cfdffff3efdffffccfcffff9ffdffffb1feffffb3fdffffa9fdffffb1feffffb1feffffb1feffff16fcffffb1feffff68feffffd2fdffff6ffeffff'],
 'equipment_override': ['__text',
                        729053,
                        66,
                        '498b4770488b40084a8b3c30e84c95f3ff0543ffffff41894760498b3c244885ff741fe8bd4102004885c07415498b3c24e8af410200418b77604889c7e8dd330100']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {'cursor_predicate': ('_ZN6Status7gameWonEv', 0, 14, 'd0f8e81100202c29c8bf01207047'),
           'rank_calculation': ('_ZN6Status15checkForLevelUpEv', 0, 104, 'sha256:382c341367d31244fa6f3d6c10b0e220fff6ae8b8311556375980d889900974b'),
           'rank_thresholds': ('_ZN6Status15checkForLevelUpEv', 58, 84, 'sha256:3e64308cda1ff8cd1c97e1ab8e2b9edff4c81ef5f170f92f7c4224bc3a67fe54', 'literal', 0),
           'fresh_companions': ('_ZN6Status9resetGameEv', 224, 10, '0020c8f82400c8f83000'),
           'fresh_location_wrapper': ('_ZN6Status9resetGameEv', 162, 16, '3020adf7f0ea0546b1f776ebc8f84c51'),
           'wrapper_defaults': ('_ZN7StationC2Ev', 50, 8, '4ff0ff30c4e90200'),
           'location_comparison': ('_ZN7Station6equalsEPS_', 0, 18, '0246002021b1896892688a4208bf01207047'),
           'reputation_initial': ('_ZN8StandingC2Ev', 0, 32, 'sha256:234ed549d81f96bae6f8f18a42d7e95af0281e25bd19933f40903e1c8fae4876'),
           'fresh_reputation': ('_ZN6Status9resetGameEv', 1334, 22, '0820adf7a6e80546b1f790eb4ff0ff317748c8f81450'),
           'hostility': ('_ZN8Standing7isEnemyEi', 0, 118, 'sha256:e48dc557d39a1d28df8cd83c0ffd928da627c0a2e569b8c51369bd5c27b71ce0'),
           'pirate_reputation': ('_ZN8Standing9applyKillEi', 0, 104, 'sha256:8bd296216f97e43401c7b59304cac316144c2c3836301212bcd504103a57542a'),
           # Reputation axis per system race 0..3 for a pirate kill.
           'pirate_races': ('_ZN8Standing9applyKillEi', 60, 16, '01000000000000000300000002000000', 'literal', 0),
           'reputation_adjustment': ('_ZN8Standing11applyDelictEii', 0, 124, 'sha256:262f35c31d0749a01acbf4ae6061d65741bc024e6bdf6ddd6c94ca65ed6fec89'),
           'reputation_double_predicate': ('_ZN6Status12hardCoreModeEv', 0, 36, 'sha256:d129eedb895b5a8cc5da84fbd316ee5effaae7d16ec57c3ef53f54ee21bd7b12'),
           'reputation_mask_reset': ('_ZN4Ship12refreshValueEv', 70, 40, 'sha256:d46059f7211861fa8b7815e4942e208dcf083f8ba50f9f9a393ea6a216b8567a'),
           # Equipment sorts 0..29 with the whole tbb table; sort 29 sets the signature race.
           'equipment_dispatch': ('_ZN4Ship12refreshValueEv', 230, 46, 'sha256:26158f6f646baf8b0acac590bd33b36509adeacd2b4e920fb025e031ef74333e'),
           'equipment_override': ('_ZN4Ship12refreshValueEv', 170, 50, 'sha256:6cafc36fd4bce9d5d3c1864981bc5eec72a7cef0b9ef1dd5efdcdb2116a13e46')}
