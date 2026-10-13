"""Optional Mac full-hold station return and cargo-lifetime declarations.

Android: PlayerEgo::calcCollision and MGame::dockEvent dock the cursor-5
return (kind 11; kind 154 refused with notice 21); DialogueWindow's mode-1
tables hold its six lines and Globals::getDialogueSoundId five voices;
ModStation::OnUpdate opens and ModStation::OnTouchEnd acknowledges them;
Status::nextCampaignMission's cursor-6 case empties the cargo
(Ship::removeAllCargo) and creates mission 158 at station 78. The values are
MAC_VALUES.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes

def extract_full_hold_return(mach,arrival,first,story):
    if mach.architecture == 'android-armv7':
        try:
            if first['scope'] != 'first_mining_station_return' or story['scope'] != 'full_hold_mining_story': return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(MAC_VALUES), provenance=proof) if proof else {}
    if mach.architecture!='x86_64':return {}
    try:
        if first['scope']!='first_mining_station_return' or story['scope']!='full_hold_mining_story':return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts,reader=declaration_bytes)
        if not proof:return {}
        values=MAC_VALUES if proof['mode1_counts']['offset']==origin['offset']+MAC_ALTERNATE['mode1_counts'][0] else VALUES
        result=copy.deepcopy(values);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'full_hold_station_return',
 'station_id': 78,
 'system_id': 15,
 'departing_cursor': 4,
 'campaign_cursor': 5,
 'source_state': 5,
 'contact_radius': 16000.0,
 'contact_before_motion': True,
 'volume_after_motion': True,
 'requires_station_target': True,
 'mission_kind': 11,
 'restricted_mission_kind': 154,
 'restricted_notice': 21,
 'minimum_delivered_cargo': 25,
 'cache_pools': ['hull', 'armor', 'shield', 'gamma'],
 'cache_truncates': ['shield', 'gamma'],
 'cargo_preserved_on_arrival': True,
 'clear_cargo_after_acknowledgement': True,
 'mode': 1,
 'next_text_id': 179,
 'final_text_id': 180,
 'cursor_after_acknowledgement': 6,
 'next_mission_kind': 158,
 'next_mission_parameter': 0,
 'reward_credits': 0,
 'bonus_credits': 0,
 'events': [{'speaker_id': 2, 'text_id': 1719, 'voice_event_id': 433},
            {'speaker_id': 0, 'text_id': 1720, 'voice_event_id': 434},
            {'speaker_id': 2, 'text_id': 1721, 'voice_event_id': 435},
            {'speaker_id': 0, 'text_id': 1722, 'voice_event_id': 436},
            {'speaker_id': 2, 'text_id': 1723, 'voice_event_id': 437},
            {'speaker_id': 16, 'text_id': 1724, 'voice_event_id': -1}],
 'refresh_cargo_after_acknowledgement': False}

LAYOUTS = {'mode1_counts': [1555258, 24, '__const', '0000000026000000060000000a000000040000000c000000'],
 'mode1_return_events': [1546594,
                         48,
                         '__const',
                         '02000000b706000000000000b806000002000000b906000000000000ba06000002000000bb06000010000000bc060000'],
 'voice_table': [1560154,
                 12032,
                 '__const',
                 'sha256:9d6c95a1f5be7db67e20b62e913d94d275f8f743dc943cd685af361d96684be7'],
 'cursor6_dispatch': [871426, 4, '__text', '2fd6ffff'],
 'cursor6_factory': [860701,
                     50,
                     '__text',
                     '498bbe00020000e8bf04feffbf98000000e8f95f0a004889c34889dfbe9e00000031d2b94e000000e84ef5f8ffe932ffffff'],
 'factory_install': [860545, 16, '__text', '4c89f74889dee80cfcffffe9242a0000'],
 'cargo_list_dispose': [730856,
                        54,
                        '__text',
                        '554889e54156534989fe498b5e784885db7416488b7b084885ff7405e8115b0c004889dfe80f5b0c0049c74678000000005b415e5dc3'],
 'mission_constructor': [399266,
                         448,
                         '__text',
                         '554889e54157415641554154534883ec384189ce4189d74189f44889fb488d7b1848897da8e8beba0e00488d7b2848897da0e8b1ba0e00488d7b5848897db0e8a4ba0e004c8d6b684c89efe898ba0e004489631044897b444489735048c743380000000048c74308000000004585f67826488d0560231f00488b384489f6e863daefff488d7dc84889c6e84de5060041b6014530ffeb18488d7dc8488d35c29c150031d2e8dfbc0e004530f641b701488d75c8488b7db0e8bcc30e004180ff017509488d7dc8e8fdb90e004180fe017509488d7dc8e8eeb90e00488d7db8488d357f9c150031d2e89cbc0e00488d75b84c89efe880c30e00488d7db8e8c7b90e00c7838400000001000000c6839400000001c60300c6430100c6437c00c7839000000000000000c7434c000000004883c4385b415c415d415e415f5dc34889c3eb624889c3eb544889c3eb464889c3eb394889c34584f6751aeb2f4889c34180ff017509488d7dc8e85bb90e004180fe017517488d7dc8e84cb90e00eb0c4889c3488d7db8e83eb90e004c89efe836b90e00488b7db0e82db90e00488b7da0e824b90e00488b7da8e81bb90e004889dfe805691100e8b86811004889c3ebcb90'],
 'station_acknowledgement': [429803,
                             1908,
                             '__text',
                             'sha256:3ac1adb5069204f99145694aab530df1110ea076aa33b21cb049e6e18e2850a4'],
 'station_dialogue_selection': [447318,
                                69,
                                '__text',
                                '488b9de0feffff4885db0f848400000049899d00010000bfb0000000e8b5ae10004989c64c89f74889de31d2b901000000e8ee92eeff4d89b5d800000041c685a500000001'],
 'dialogue_mission_binding': [-693644,
                              28,
                              '__text',
                              '554889e5415741564154534189ce4989f44989ff4d89677041895768'],
 'mission_voice_actor': [401310, 10, '__text', '554889e5488b47085dc3'],
 'silent_voice_lookup': [-215216,
                         68,
                         '__text',
                         '554889e5415741564154534989d689f331c0488d0df1161b00eb044883c0023dbf0b00007f15391c8175f0488d0dd8161b008b448104e9d50800004d85f60f84c7080000'],
 'silent_voice_return': [-212901, 14, '__text', 'b8ffffffff5b415c415e415f5dc3'],
 'next_mission_equipment': [874532,
                            126,
                            '__text',
                            '498bbd00020000e88acbfdff4989c641833e000f845201000030db4531e44530ed498b46084a8b3ce04885ff742be8eb5cf1ff85c0750541b501eb1d498b46084a8b3ce04885ff7410e8e45cf1ffb10183f80a740288d988cb49ffc4453b2672c041f6c5014c8b6db00f84fc000000f6c301e9eb000000418b9d64020000']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'mode1_counts': [1530242, 24, '__const', '0000000026000000060000000a000000040000000c000000'],
 'mode1_return_events': [1521578,
                         48,
                         '__const',
                         '02000000c206000000000000c306000002000000c406000000000000c506000002000000c606000010000000c7060000'],
 'voice_table': [1535218, 12032, '__const', 'sha256:71d7f260f073a866f0c2c15cbb1de4360add0790bba948ac33ff006cea251e5d'],
 'cursor6_dispatch': [872058, 4, '__text', '2fd6ffff'],
 'cursor6_factory': [861333,
                     50,
                     '__text',
                     '498bbe00020000e8bf04feffbf98000000e8cdfb09004889c34889dfbe9e00000031d2b94e000000e8daf4f8ffe932ffffff'],
 'factory_install': [861177, 16, '__text', '4c89f74889dee80cfcffffe9242a0000'],
 'cargo_list_dispose': [731488,
                        54,
                        '__text',
                        '554889e54156534989fe498b5e784885db7416488b7b084885ff7405e8e5f60b004889dfe8e3f60b0049c74678000000005b415e5dc3'],
 'mission_constructor': [399782,
                         448,
                         '__text',
                         '554889e54157415641554154534883ec384189ce4189d74189f44889fb488d7b1848897da8e8d2970e00488d7b2848897da0e8c5970e00488d7b5848897db0e8b8970e004c8d6b684c89efe8ac970e004489631044897b444489735048c743380000000048c74308000000004585f67826488d0534c91e00488b384489f6e85fc1efff488d7dc84889c6e8c1e5060041b6014530ffeb18488d7dc8488d35863e150031d2e8f3990e004530f641b701488d75c8488b7db0e8d0a00e004180ff017509488d7dc8e811970e004180fe017509488d7dc8e802970e00488d7db8488d35433e150031d2e8b0990e00488d75b84c89efe894a00e00488d7db8e8db960e00c7838400000001000000c6839400000001c60300c6430100c6437c00c7839000000000000000c7434c000000004883c4385b415c415d415e415f5dc34889c3eb624889c3eb544889c3eb464889c3eb394889c34584f6751aeb2f4889c34180ff017509488d7dc8e86f960e004180fe017517488d7dc8e860960e00eb0c4889c3488d7db8e852960e004c89efe84a960e00488b7db0e841960e00488b7da0e838960e00488b7da8e82f960e004889dfe84d051100e8000511004889c3ebcb90'],
 'station_acknowledgement': [430231,
                             1908,
                             '__text',
                             'sha256:32b8a28aa5620d75f849b0ce6e464cf3ab23adf56835b7f67d042ec8f2347892'],
 'station_dialogue_selection': [447844,
                                69,
                                '__text',
                                '488b9de0feffff4885db0f848400000049899d08010000bfb0000000e8f34a10004989c64c89f74889de31d2b901000000e8d879eeff4d89b5d800000041c685a500000001'],
 'dialogue_mission_binding': [-699540, 28, '__text', '554889e5415741564154534189ce4989f44989ff4d89677041895768'],
 'mission_voice_actor': [401826, 10, '__text', '554889e5488b47085dc3'],
 'silent_voice_lookup': [-216172,
                         68,
                         '__text',
                         '554889e5415741564154534989d689f331c0488d0d45b91a00eb044883c0023dbf0b00007f15391c8175f0488d0d2cb91a008b448104e9d50800004d85f60f84c7080000'],
 'silent_voice_return': [-213857, 14, '__text', 'b8ffffffff5b415c415e415f5dc3'],
 'next_mission_equipment': [875164,
                            126,
                            '__text',
                            '498bbd00020000e882cbfdff4989c641833e000f845201000030db4531e44530ed498b46084a8b3ce04885ff742be8735af1ff85c0750541b501eb1d498b46084a8b3ce04885ff7410e86c5af1ffb10183f80a740288d988cb49ffc4453b2672c041f6c5014c8b6db00f84fc000000f6c301e9eb000000418b9d64020000']}
MAC_VALUES = {'scope': 'full_hold_station_return',
 'station_id': 78,
 'system_id': 15,
 'departing_cursor': 4,
 'campaign_cursor': 5,
 'source_state': 5,
 'contact_radius': 16000.0,
 'contact_before_motion': True,
 'volume_after_motion': True,
 'requires_station_target': True,
 'mission_kind': 11,
 'restricted_mission_kind': 154,
 'restricted_notice': 21,
 'minimum_delivered_cargo': 25,
 'cache_pools': ['hull', 'armor', 'shield', 'gamma'],
 'cache_truncates': ['shield', 'gamma'],
 'cargo_preserved_on_arrival': True,
 'clear_cargo_after_acknowledgement': True,
 'mode': 1,
 'next_text_id': 179,
 'final_text_id': 180,
 'cursor_after_acknowledgement': 6,
 'next_mission_kind': 158,
 'next_mission_parameter': 0,
 'reward_credits': 0,
 'bonus_credits': 0,
 'events': [{'speaker_id': 2, 'text_id': 1730, 'voice_event_id': 433},
            {'speaker_id': 0, 'text_id': 1731, 'voice_event_id': 434},
            {'speaker_id': 2, 'text_id': 1732, 'voice_event_id': 435},
            {'speaker_id': 0, 'text_id': 1733, 'voice_event_id': 436},
            {'speaker_id': 2, 'text_id': 1734, 'voice_event_id': 437},
            {'speaker_id': 16, 'text_id': 1735, 'voice_event_id': -1}],
 'refresh_cargo_after_acknowledgement': False}

# Android spans inside named functions and tables; the values are MAC_VALUES.
ANDROID = {# PlayerEgo::calcCollision: station contact within 16000; MGame::dockEvent docks the return (kind 11)
           # and refuses kind 154 with notice 21.
           'contact_constant_load': ('_ZN9PlayerEgo13calcCollisionEP5ArrayIP8KIPlayerE', 82, 4, '9fedbc8a'),
           'contact_radius_constant': ('_ZN9PlayerEgo13calcCollisionEP5ArrayIP8KIPlayerE', 836, 4, '00007a46'),
           'station_contact_radius': ('_ZN9PlayerEgo13calcCollisionEP5ArrayIP8KIPlayerE', 174, 48, 'sha256:e8eb3fe75a1368b659ea64f6e1df18dec0f4685ff3eef9dc339e55629b5a2f9b'),
           'dock_event': ('_ZN5MGame9dockEventEii', 0, 1500, 'sha256:c509b37791ee035ac28c716b3765e52ba5705d02fa07f400333fcb885a2b9ee0'),
           # Mode 1, cursor 5: six lines (entries 58..69 after counts 0, 38, 6, 10, 4) and five voices (433-437);
           # the sixth line has none (Globals::getDialogueSoundId returns -1).
           'mode1_counts': ('_ZN14DialogueWindow18hasSuccessDialogueEi', 10, 24, '0000000026000000060000000a000000040000000c000000', 'literal', 0),
           'mode1_return_events': ('_ZN14DialogueWindow11loadContentEv', 208, 48, 
                                   '02000000cd06000000000000ce06000002000000cf06000000000000d006000002000000d106000010000000d2060000', 'literal', 232),
           'voices': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 186, 40,
                      'cd060000b1010000ce060000b2010000cf060000b3010000d0060000b4010000d1060000b5010000', 'literal', 2160),
           'voice_table': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 8, 12032, 'sha256:24201ffc5c374c33aeec4660c20bd8af5788878246a0e6f0b1cae22c09895b52', 'literal', 0),
           'voice_lookup': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 0, 40, 'sha256:5500de04daa6b2f72d8bacb0b201d9474f16a450072a26e598a3bb0cee15ad3a'),
           'silent_voice_return': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 1054, 6, '4ff0ff30bde8'),
           # Status::nextCampaignMission: cursor 6 (tbh entry 5) empties the cargo (Ship::removeAllCargo) and
           # creates mission 158 at 78; cursor 4 asked for 25 tons, which Status::missionCompleted checks.
           'story_increment': ('_ZN6Status19nextCampaignMissionEb', 392, 6, '1846431c0021'),
           'cursor6_dispatch': ('_ZN6Status19nextCampaignMissionEb', 78, 2, 'f10d'),
           'cursor6_factory': ('_ZN6Status19nextCampaignMissionEb', 7206, 38,
                               'c4f8e831c9e900ced4f88c01b3f794ec6420aff7a0ea05469e2100224e23b3f736ecfef7afba'),
           'campaign_mission_tail': ('_ZN6Status19nextCampaignMissionEb', 426, 14, '2046294601b0bde8f04322f19cb8'),
           'full_hold_factory': ('_ZN6Status19nextCampaignMissionEb', 6556, 52, 'sha256:527dfb0a6e2e57cb2aa14bf0186078d818662c76e64c0c3153ec56ec8434b767'),
           'full_hold_parameter': ('_ZN6Status19nextCampaignMissionEb', 8228, 14, '4068006801b0bde8f04320f17fb9'),
           'cargo_check': ('_ZN6Status16missionCompletedEbbx', 630, 30, 'sha256:59a7dc13441541ab0332c6069ea4a72973d0a856f29960550948e0ed6a3446ef'),
           'next_mission_equipment': ('_ZN6Status16missionCompletedEbbx', 766, 96, 'sha256:6e42914da575652e18bf19441745b961c594964e6c9e7ed404bd358776fce41b'),
           # Ship::removeAllCargo, Mission::Mission, ModStation::OnTouchEnd (acknowledgement) and ModStation::OnUpdate
           # (the completed mission at its station opens its dialogue).
           'cargo_list_dispose': ('_ZN4Ship14removeAllCargoEv', 0, 30, 'sha256:dbedce2fd4730279c220a4f280902db03f6c62e606b862614ba6ad01a4dad258'),
           'mission_constructor': ('_ZN7MissionC2Eiii', 0, 288, 'sha256:e034656d66c8e5c671a0fba356c49d2af308495b7a3dcda2601e9fb9457c9306'),
           'station_acknowledgement': ('_ZN10ModStation10OnTouchEndEiiPv', 0, 6536, 'sha256:5b29b2bf44b1e0a442eb14b5646a1aad12932fedee58112b028e31589316b50e'),
           'station_check': ('_ZN10ModStation8OnUpdateEv', 2044, 38, 'sha256:1351c42350b2f95362acddf47f855b8f32db676fe7f736cca3c62f937b14ac2c'),
           'station_dialogue_selection': ('_ZN10ModStation8OnUpdateEv', 2684, 36, 'sha256:7cd5e714affb30a40ebc9497668f1c32ec97fdf9da32b5ff6f03b1b5d4eeb30c')}
