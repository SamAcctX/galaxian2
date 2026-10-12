"""Read flight-cache declarations for the fresh opening-to-rescue lifecycle.

Android: Status::resetGame caches the ship's hull, shield and armor
(Ship::getMaxHP/ShieldHP/ArmorHP) and full gamma; cursor 0 of
Level::createCampaignMission caches the 9999999 player hull;
Status::nextCampaignMission case 0 advances to cursor 1 with the kind 11
mission to station 78; MGame::OnInitialize restores every cached value
>= 0 through the Player setters, refreshes the cache unless the cursor is
95 and resets gamma where Status::getGammaRayDamagePerSecond is zero
(outside stations 109-113). Android has no special-quest gamma: its gamma
depends on the station and cursor only (gamma_special_quest -1).
"""
import copy
from .declaration_layouts import recognize, recognize_symbols

def extract_flight_player_cache(mach, opening, actors, arrival):
    if mach.architecture == 'android-armv7':
        try:
            if arrival['campaign_cursor'] != 1 or not actors['player_initialization']['repair']:
                return {}
            if VALUES['hazard_station_min'] <= opening['station_id'] <= VALUES['hazard_station_max']:
                return {}
        except (KeyError, TypeError):
            return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(ANDROID_VALUES), provenance=proof) if proof else {}
    arch=mach.architecture
    if arch not in LAYOUTS:return {}
    try:
        if arrival['campaign_cursor']!=1 or not actors['player_initialization']['repair']:return {}
        if VALUES['hazard_station_min']<=opening['station_id']<=VALUES['hazard_station_max']:return {}
        origin=opening['provenance']['declaration']
        if origin['bytes']!=(376 if arch=='x86_64' else 284):return {}
        layouts=[LAYOUTS[arch]]+([MAC_ALTERNATE] if arch=='x86_64' else [])
        proof=recognize(mach,origin['offset'],layouts)
        if not proof:return {}
        result=copy.deepcopy(VALUES);result['provenance']=proof
        return result
    except (KeyError,TypeError,IndexError,ValueError,OverflowError):return {}

VALUES = {'scope': 'fresh_opening_to_rescue',
 'arrival_cursor': 1,
 'cache_minimum': 0,
 'gamma_full': 100,
 'gamma_sentinel': 9999999,
 'skip_cache_refresh_cursor': 95,
 'quest_kind': 11,
 'quest_target_station': 78,
 'gamma_special_quest': 183,
 'hazard_station_min': 109,
 'hazard_station_max': 113,
 'hull_cache_raises_max': True,
 'armor_clamped': True,
 'shield_clamped': True,
 'refresh_cache_after_enter': True}

LAYOUTS = {'x86_64': {'new_game_cache': ['__text',
                               401,
                               68,
                               '498bbe00020000e81ba6fdff418986a8000000498bbe00020000e844a6fdff418986a0000000498bbe00020000e8eba5fdff418986a400000041c786ac00000064000000'],
            'opening_hull_cache': ['__text',
                                   -880104,
                                   54,
                                   '498b8768010000488b38be7f969800e8b2250800488d05772f2500488b00c780a80000007f969800498b8768010000488b00c6406201'],
            'restore': ['__text',
                        -547863,
                        128,
                        '488d05ba1d2000488b008bb0a800000085f67816498b4660488b38e8d5130300488d059a1d2000488b008bb0a000000085f67816498b4660488b38e8d3130300488d057a1d2000488b008bb0a400000085f67816498b4660488b38e8df130300488d055a1d2000488b008bb0ac00000085f6780c498b4660488b38e8df130300'],
            'cache_refresh': ['__text',
                              -547726,
                              126,
                              '488d05311d2000488b38e8d3f9070083f85f0f84ae0000004c8d25191d2000498b3c24e89cf907004889c7e816030600498b0c248981a8000000498b3c24e881f907004889c7e837030600498b0c248981a0000000498b3c24e866f907004889c7e8d6020600498b0c248981a4000000498b0424c780ac00000064000000'],
            'gamma_reset': ['__text',
                            -547600,
                            72,
                            '498b1c244889dfe810f907004889c7e8bcde07004189c7498b3c24e844f907004889df4489fe89c2e8394908000f57c90f2ec175137a11498b4660488b38be64000000e810130300'],
            'hull_setter': ['__text',
                            -346146,
                            30,
                            '554889e589b78000000039b78c0000007d0689b78c0000005de994f8ffff'],
            'shield_setter': ['__text',
                              -346116,
                              44,
                              '554889e5f30f2acef30f118f90000000f30f2a879c0000000f2ec87608f30f1187900000005de969f8ffff90'],
            'armor_setter': ['__text',
                             -346072,
                             32,
                             '554889e589b7940000008b879800000039f07d068987940000005de948f8ffff'],
            'gamma_setter': ['__text',
                             -346040,
                             52,
                             '554889e5f30f2ac6f30f100d8e8f0f000f2ec10f96c081fe7f9698000f94c108c175030f28c1f30f1187c00000005de914f8ffff'],
            'constant_a47e6': ['__const', 673766, 4, '0000c842'],
            'ship_hull': ['__text',
                          -153672,
                          60,
                          '554889e5488b978800000031c04885d27424448b0231c04585c0741a488b520831c031f68d4828833cb2000f44c148ffc64439c672ee0347045dc390'],
            'ship_shield': ['__text', -153612, 10, '554889e58b471c5dc390'],
            'ship_armor': ['__text', -153682, 10, '554889e58b47205dc390'],
            'rescue_quest': ['__text',
                             -22796,
                             70,
                             'bf98000000e856610a004889c34889dfbe0b00000031d2b94e000000e8abf6f8ff4c89f74889dee8a0fcffff498b8610020000488b4008488b0049898608020000e9a32a0000'],
            'gamma_context': ['__text',
                              -4522,
                              80,
                              '554889e54157415653504189d789f34989fe488d053bd31700488b00488bb8080200004885ff7419e86fb4f8ff3db7000000750df30f1005b4e00a00e9b60000008d43930f57c083f8040f87a7000000'],
            'constant_acf46': ['__const', 708422, 4, 'cdccac3f'],
            'gamma_return': ['__text', -4275, 11, '4883c4085b415e415f5dc3'],
            'quest_type': ['__text', -482574, 9, '554889e58b47105dc3']},
 'armv7': {'new_game_cache': ['__text',
                              302,
                              40,
                              'd6f87c011894d7f7baf97066d6f87c011894d7f7cef9f065d6f87c011894d7f7acf930666420b066'],
           'opening_hull_cache': ['__text',
                                  -825564,
                                  52,
                                  'd5f8f00049f27f640df50e624ff0ff31c0f298041a950068c2f86815214678f0f3fe1498012100684466d5f8f000006880f85e10'],
           'restore': ['__text',
                       -479324,
                       104,
                       'dbf80000416e002909dbd8f854004ff0ff3200680c9224f0b7fadbf80000c16d002909dbd8f854004ff0ff3200680c9224f0b4fadbf80000016e002909dbd8f854004ff0ff3200680c9224f0bdfadbf80000816e002907dbd8f854004ff0ff3200680c9224f0bafa'],
           'cache_refresh': ['__text',
                             -479206,
                             80,
                             'dbf800000c966ef0a0fe5f2843d0dbf800000c966ef08dfe0c964cf03afadbf80010486608460c966ef083fe0c964cf04afadbf80010c86508460c966ef079fe0c964cf024fadbf8004020666420a066'],
           'gamma_reset': ['__text',
                           -479126,
                           70,
                           '20460c966ef061fe0c966df036f90546dbf800000c966ef070fe0246204629460c9674f052f840ec100bb5eec00af1ee10fa08d1d8f854004ff0ff3100680c91642124f068fa'],
           'hull_setter': ['__text',
                           -330452,
                           20,
                           '8167d0f884208a42b8bfc0f88410fff727bc00bf'],
           'shield_setter': ['__text',
                             -330432,
                             44,
                             '41ec301bbbff201680ed221a90ed250abbff0006b4eec01af1ee10fa20ef1001c8bf80ed220afff711bc00bf'],
           'armor_setter': ['__text',
                            -330388,
                            20,
                            'd0f890208a42b8bf1146c0f88c10fff707bc00bf'],
           'gamma_setter': ['__text',
                            -330368,
                            64,
                            '41ec301b9fed0e0abbff201649f27f62c0f2980291424ff000014ff0000318bf0121b4eec01af1ee10fac8bf01230b4218bfb0ee401a80ed2e1afff7e7bb00bf'],
           'ship_hull': ['__text',
                         -166740,
                         52,
                         '816f00291cbfd1f80090b9f1000f01d100210be0d1f804c0002200215cf822300132002b08bf28314a45f7d340680844704700bf'],
           'ship_shield': ['__text', -166688, 4, 'c0697047'],
           'ship_armor': ['__text', -166744, 4, '006a7047'],
           'rescue_quest': ['__text',
                            -22686,
                            66,
                            '4ff0ff30cdf810a0ac9064204ef15eee0f210f900f98ac910b2100224e23a0f78efa4ff0ff300f99ac90049c2046fff7acfdd4f8840140680068c4f8800102f0b3bb'],
           'gamma_context': ['__text',
                             -3788,
                             52,
                             'f0b5054645f2ea50c0f21d00164678440c4603af00680068d0f8800130b19bf729ffb72802d19fed140a22e0a4f16d00042809d8'],
           'gamma_zero': ['__text', -3716, 6, '80ef100011e0'],
           'gamma_return': ['__text', -3674, 6, '10ee100af0bd'],
           'quest_type': ['__text', -413784, 4, '80687047'],
           'gamma_limit': ['__text', -330304, 4, '0000c842']}}


# Complete alternate Mac layout; cache arithmetic and lifecycle are unchanged.
MAC_ALTERNATE = {'new_game_cache': ['__text',
                    401,
                    68,
                    '498bbe00020000e813a6fdff418986a8000000498bbe00020000e83ca6fdff418986a0000000498bbe00020000e8e3a5fdff418986a400000041c786ac00000064000000'],
 'opening_hull_cache': ['__text',
                        -880736,
                        54,
                        '498b8768010000488b38be7f969800e8ca270800488d054fd72400488b00c780a80000007f969800498b8768010000488b00c6406201'],
 'restore': ['__text',
             -548795,
             128,
             '488d05bec61f00488b008bb0a800000085f67816498b4660488b38e819170300488d059ec61f00488b008bb0a000000085f67816498b4660488b38e817170300488d057ec61f00488b008bb0a400000085f67816498b4660488b38e823170300488d055ec61f00488b008bb0ac00000085f6780c498b4660488b38e823170300'],
 'cache_refresh': ['__text',
                   -548658,
                   126,
                   '488d0535c61f00488b38e877fd070083f85f0f84ae0000004c8d251dc61f00498b3c24e840fd07004889c7e8b2060600498b0c248981a8000000498b3c24e825fd07004889c7e8d3060600498b0c248981a0000000498b3c24e80afd07004889c7e872060600498b0c248981a4000000498b0424c780ac00000064000000'],
 'gamma_reset': ['__text',
                 -548532,
                 72,
                 '498b1c244889dfe8b4fc07004889c7e860e207004189c7498b3c24e8e8fc07004889df4489fe89c2e8dd4c08000f57c90f2ec175137a11498b4660488b38be64000000e854160300'],
 'hull_setter': ['__text',
                 -346242,
                 30,
                 '554889e589b78000000039b78c0000007d0689b78c0000005de994f8ffff'],
 'shield_setter': ['__text',
                   -346212,
                   44,
                   '554889e5f30f2acef30f118f90000000f30f2a879c0000000f2ec87608f30f1187900000005de969f8ffff90'],
 'armor_setter': ['__text',
                  -346168,
                  32,
                  '554889e589b7940000008b879800000039f07d068987940000005de948f8ffff'],
 'gamma_setter': ['__text',
                  -346136,
                  52,
                  '554889e5f30f2ac6f30f100dce2b0f000f2ec10f96c081fe7f9698000f94c108c175030f28c1f30f1187c00000005de914f8ffff'],
 'constant_a47e6': ['__const', 648134, 4, '0000c842'],
 'ship_hull': ['__text',
               -153680,
               60,
               '554889e5488b978800000031c04885d27424448b0231c04585c0741a488b520831c031f68d4828833cb2000f44c148ffc64439c672ee0347045dc390'],
 'ship_shield': ['__text', -153620, 10, '554889e58b471c5dc390'],
 'ship_armor': ['__text', -153690, 10, '554889e58b47205dc390'],
 'rescue_quest': ['__text',
                  -22796,
                  70,
                  'bf98000000e82afd09004889c34889dfbe0b00000031d2b94e000000e837f6f8ff4c89f74889dee8a0fcffff498b8610020000488b4008488b0049898608020000e9a32a0000'],
 'gamma_context': ['__text',
                   -4522,
                   80,
                   '554889e54157415653504189d789f34989fe488d059b781700488b00488bb8080200004885ff7419e8fbb3f8ff3db7000000750df30f1005f47c0a00e9b60000008d43930f57c083f8040f87a7000000'],
 'constant_acf46': ['__const', 682886, 4, 'cdccac3f'],
 'gamma_return': ['__text', -4275, 11, '4883c4085b415e415f5dc3'],
 'quest_type': ['__text', -482690, 9, '554889e58b47105dc3']}

ANDROID = {'new_game_cache': ('_ZN6Status9resetGameEv', 1696, 42, 'sha256:4018e29b876f192a7abb411b4f9337061aef8111fee8660a21ca5bdf85e42729'),
           # The 9999999 hull in ip among the prologue constants, copied in case 0, then cached.
           'opening_hull_constant': ('_ZN5Level21createCampaignMissionEv', 58, 32, 'sha256:5bccd4a6ce09b982ea3f9228df2c384cec63fd46ce45274abbf60304db3fa9bc'),
           'opening_hull_copy': ('_ZN5Level21createCampaignMissionEv', 24956, 2, 'e346'),
           'opening_hull_cache': ('_ZN5Level21createCampaignMissionEv', 25178, 36, 'sha256:4b42ef167a1bc93da1955509f7f7a4604438d780808a64ee07f0a823a099a671'),
           'restore': ('_ZN5MGame12OnInitializeEv', 680, 94, 'sha256:f26e7c61568267e300fca0c2aa22e027b722de79cda9603ac5327a72c2edfad3'),
           'cache_refresh': ('_ZN5MGame12OnInitializeEv', 782, 72, 'sha256:a073a00bc9412e0e279cfac0029b1c3e90701f1c1a3c2466f47bca42dbc05585'),
           'gamma_reset': ('_ZN5MGame12OnInitializeEv', 854, 54, 'sha256:83b412d481d119b6c2b210111b8cec41c9da84bd635fd1b72dad656b9e4687ae'),
           'hull_setter': ('_ZN6Player12setHitpointsEi', 0, 18, '8167d0f884208a42b8bfc0f8841029f115bc'),
           'shield_setter': ('_ZN6Player11setShieldHPEi', 0, 38, 'sha256:9ab87676f4d2011a8fe13935bae9233e4351c8df1ef5295cf50982184ac7fc84'),
           'armor_setter': ('_ZN6Player10setArmorHPEi', 0, 18, 'd0f890208a42b8bf1146c0f88c1029f1f9bb'),
           'gamma_setter': ('_ZN6Player10setGammaHPEi', 0, 48, 'sha256:7eb49e97e914ee937fc6c7f9de2151de86d2a242beafec89b5ac10d1df9e6bee'),
           'gamma_limit': ('_ZN6Player10setGammaHPEi', 48, 4, '0000c842'),
           'ship_hull': ('_ZN4Ship8getMaxHPEv', 0, 50, 'sha256:989d04cbf873958847b311cf99b9d3e975496c62ce32708d470329ad33a26b4d'),
           'ship_shield': ('_ZN4Ship14getMaxShieldHPEv', 0, 4, 'c0697047'),
           'ship_armor': ('_ZN4Ship13getMaxArmorHPEv', 0, 4, '006a7047'),
           # The old cursor + 1 is stored; case 0 of the cursor's tbh table builds the rescue mission.
           'cursor_advance': ('_ZN6Status19nextCampaignMissionEb', 392, 8, '1846431c00214be7'),
           'rescue_dispatch': ('_ZN6Status19nextCampaignMissionEb', 40, 28, 'sha256:7864ea79e7595ae4922b4f10cddbe5005a5d6134a87a363fa40ff3fe0d7fa174'),
           'rescue_case': ('_ZN6Status19nextCampaignMissionEb', 68, 2, 'ad02'),
           'rescue_quest': ('_ZN6Status19nextCampaignMissionEb', 1438, 50, 'sha256:4370fdc5f05138ea26007bd36d5b0934d3f753057103e7798ff3df17180cd52b'),
           'gamma_context': ('_ZN6Status26getGammaRayDamagePerSecondEii', 0, 68, 'sha256:4cb3abd5212880ec9f10da030f81ec7acb502189cd49a275ac34e9efa6e89d71')}

# No mission kind changes Android's gamma rate.
ANDROID_VALUES = dict(VALUES, gamma_special_quest=-1)
