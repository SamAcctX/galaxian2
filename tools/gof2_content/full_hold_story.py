"""Optional Mac second-trip story data. No executable runtime is emitted.

Android: DialogueWindow's tables hold cursor 4's briefing line (2, 1727) and
completion lines (0, 1728), (2, 1729), Globals::getDialogueSoundId their
voices (188, 431, 432); Status::nextCampaignMission creates mission 154 at
78 with status value 25 for cursor 4 and mission 11 at 78 for cursor 5;
Status::missionCompleted completes it at that load; MGame::OnTouchEnd's last
page advances the campaign. The values are MAC_VALUES.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes

def extract_full_hold_story(mach,arrival,flight,briefing,objective):
    if mach.architecture == 'android-armv7':
        try:
            if flight['scope'] != 'full_hold_mining_flight_construction': return {}
            if briefing['scope'] != 'first_mining_briefing' or objective['scope'] != 'first_mining_cargo_objective': return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(MAC_VALUES), provenance=proof) if proof else {}
    if mach.architecture!='x86_64':return {}
    try:
        if flight['scope']!='full_hold_mining_flight_construction':return {}
        if briefing['scope']!='first_mining_briefing' or objective['scope']!='first_mining_cargo_objective':return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts,reader=declaration_bytes)
        if not proof:return {}
        values=MAC_VALUES if proof['mode0_counts']['offset']==origin['offset']+MAC_ALTERNATE['mode0_counts'][0] else VALUES
        result=copy.deepcopy(values);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'full_hold_mining_story',
 'campaign_cursor': 4,
 'mission_kind': 154,
 'station_id': 78,
 'required_cargo': 25,
 'cursor_after_acknowledgement': 5,
 'next_kind': 11,
 'briefing_events': [{'speaker_id': 2, 'text_id': 1716, 'voice_event_id': 188}],
 'completion_events': [{'speaker_id': 0,
                        'text_id': 1717,
                        'voice_event_id': 431},
                       {'speaker_id': 2,
                        'text_id': 1718,
                        'voice_event_id': 432}]}

LAYOUTS = {'mode0_counts': [1554602, 20, '__const', '02000000000000000a0000000000000002000000'],
 'mode0_events': [1555962, 8, '__const', '02000000b4060000'],
 'mode1_counts': [1555258, 20, '__const', '0000000026000000060000000a00000004000000'],
 'mode1_events': [1546578, 16, '__const', '00000000b506000002000000b6060000'],
 'briefing_voice': [1560354, 8, '__const', 'b4060000bc000000'],
 'completion_voices': [1562298, 16, '__const', 'b5060000af010000b6060000b0010000'],
 'next_dispatch': [871422, 4, '__text', '04d6ffff'],
 'next_mission': [860658,
                  43,
                  '__text',
                  'bf98000000e830600a004889c34889dfbe0b00000031d2b94e000000e885f5f8ffe969ffffffe9a7290000'],
 'acknowledgement_cleanup': [352080,
                             4033,
                             '__text',
                             'sha256:e9c87f5f46995d42c94089562d1be9af2636e5e87116dd2e78558ad2753e1125'],
 'entry_controller': [150932,
                      435,
                      '__text',
                      '41f6452c010f84a8010000498b4520488b38be1e00000031d2e8d2990100488d05c9ed2200488b38e859120b004885c07438498b7d20e81950ffff4989c641833e00742631db498b46084c8b3cd84c89ffe82882fcff84c0740841c6877d0100000148ffc3413b1e72dc8b85c0d0ffff41014530498b7d20e8c94fffff4885c00f842d010000488d0561ed2200488b38e803ca0a0083f8020f8c1501000041817d30591b00000f8c0701000041c745300000000041c6452c0041c6452d01498b7d1831f6e803940b00498b7d20e8744fffff488b38be01000000e8a7e5050041c6451100498b7d20e8594fffff4889c7be01000000e87c3b0600488d0575f42200488b184885db7440488d05deec2200488b38e838c90a004889df4889c6e871b60a0084c07522498b7d20498b9d08010000e80f4fffff4889dfbe050000004889c231c9e803e8fbff488d05eef32200c60000488d0524f42200f6000175084c89efe867cbffff488d0580ec2200488b38e810110b004885c07438498b7d20e8d04effff4989c641833e00742631db498b46084c8b3cd84c89ffe8df80fcff84c0740841c6877d0100000048ffc3413b1e72dc']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'mode0_counts': [1529586, 20, '__const', '04000000000000000a0000000000000002000000'],
 'mode0_events': [1530954, 8, '__const', '02000000bf060000'],
 'mode1_counts': [1530242, 20, '__const', '0000000026000000060000000a00000004000000'],
 'mode1_events': [1521562, 16, '__const', '00000000c006000002000000c1060000'],
 'briefing_voice': [1535418, 8, '__const', 'bf060000bc000000'],
 'completion_voices': [1537362, 16, '__const', 'c0060000af010000c1060000b0010000'],
 'next_dispatch': [872054, 4, '__text', '04d6ffff'],
 'next_mission': [861290,
                  43,
                  '__text',
                  'bf98000000e804fc09004889c34889dfbe0b00000031d2b94e000000e811f5f8ffe969ffffffe9a7290000'],
 'acknowledgement_cleanup': [351794,
                             4033,
                             '__text',
                             'sha256:0eb982bef5a9a776cbf7ebe71bde77c4fe7e513a3310c088f0b00699a423f8a3'],
 'entry_controller': [150932,
                      435,
                      '__text',
                      '41f6452c010f84a8010000498b4520488b38be1e00000031d2e8de990100488d05a1952200488b38e8d1140b004885c07438498b7d20e81950ffff4989c641833e00742631db498b46084c8b3cd84c89ffe82882fcff84c0740841c6877d0100000148ffc3413b1e72dc8b85c0d0ffff41014530498b7d20e8c94fffff4885c00f842d010000488d0539952200488b38e87bcc0a0083f8020f8c1501000041817d30591b00000f8c0701000041c745300000000041c6452c0041c6452d01498b7d1831f6e87b960b00498b7d20e8744fffff488b38be01000000e8bfe7050041c6451100498b7d20e8594fffff4889c7be01000000e8943d0600488d05659c2200488b184885db7440488d05b6942200488b38e8b0cb0a004889df4889c6e8e9b80a0084c07522498b7d20498b9d08010000e80f4fffff4889dfbe050000004889c231c9e85fe6fbff488d05de9b2200c60000488d05149c2200f6000175084c89efe867cbffff488d0558942200488b38e888130b004885c07438498b7d20e8d04effff4989c641833e00742631db498b46084c8b3cd84c89ffe8df80fcff84c0740841c6877d0100000048ffc3413b1e72dc']}
MAC_VALUES = {'scope': 'full_hold_mining_story',
 'campaign_cursor': 4,
 'mission_kind': 154,
 'station_id': 78,
 'required_cargo': 25,
 'cursor_after_acknowledgement': 5,
 'next_kind': 11,
 'briefing_events': [{'speaker_id': 2, 'text_id': 1727, 'voice_event_id': 188}],
 'completion_events': [{'speaker_id': 0, 'text_id': 1728, 'voice_event_id': 431},
                       {'speaker_id': 2, 'text_id': 1729, 'voice_event_id': 432}]}

# Android spans inside named functions and tables; the values are MAC_VALUES.
ANDROID = {# DialogueWindow's tables: cursor 4's briefing line (mode 0, entries 14-15) and two completion lines
           # (mode 1, entries 54-57), with their voices.
           'mode0_counts': ('_ZN14DialogueWindow19hasBriefingDialogueEi', 10, 20, '04000000000000000a0000000000000002000000', 'literal', 0),
           'mode0_events': ('_ZN14DialogueWindow11loadContentEv', 128, 8, '02000000ca060000', 'literal', 56),
           'mode1_counts': ('_ZN14DialogueWindow18hasSuccessDialogueEi', 10, 20, '0000000026000000060000000a00000004000000', 'literal', 0),
           'mode1_events': ('_ZN14DialogueWindow11loadContentEv', 208, 16, '00000000cb06000002000000cc060000', 'literal', 216),
           'briefing_voice': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 8, 8, 'ca060000bc000000', 'literal', 200),
           'completion_voices': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 186, 16, 'cb060000af010000cc060000b0010000', 'literal', 2144),
           # Status::nextCampaignMission: cursor 4 (tbh entry 3) clears the cargo and creates mission 154 at 78
           # with status value 25; cursor 5 (entry 4) creates mission 11 at 78. Status::missionCompleted completes
           # kind 154 at that load.
           'mission_dispatch': ('_ZN6Status19nextCampaignMissionEb', 74, 4, 'ac0c1e0d'),
           'mission_factory': ('_ZN6Status19nextCampaignMissionEb', 6556, 52, 
                               'c4f8e8310021c9e900ced4f88c01b3f7cced6420aff7e4eb05469a2100224e23b3f77aed20462946b3f782edd4f89401192129e3'),
           'mission_parameter': ('_ZN6Status19nextCampaignMissionEb', 8228, 14, '4068006801b0bde8f04320f17fb9'),
           'next_mission': ('_ZN6Status19nextCampaignMissionEb', 6784, 30, '6420c4f8e831c9e900ceaff778eb05460b2100224e23b3f70eedfef786bb'),
           'campaign_mission_tail': ('_ZN6Status19nextCampaignMissionEb', 426, 14, '2046294601b0bde8f04322f19cb8'),
           'cargo_entry': ('_ZN6Status16missionCompletedEbbx', 216, 2, 'd300'),
           'cargo_check': ('_ZN6Status16missionCompletedEbbx', 630, 30, 'sha256:59a7dc13441541ab0332c6069ea4a72973d0a856f29960550948e0ed6a3446ef'),
           # MGame::OnTouchEnd's last completion page advances the won mission; LevelScript::process releases
           # the entry controller.
           'acknowledgement': ('_ZN5MGame10OnTouchEndEiiPv', 972, 76, 'sha256:3cf5791f50b694969248783ea1269bc9c5ca6b669f688fe8fbfea0549b01383c'),
           'acknowledgement_advance': ('_ZN5MGame10OnTouchEndEiiPv', 3520, 116, 'sha256:c89a74908121919a930ab10c977e6f8ca75a311b8d315f798c9be33af9e953aa'),
           'acknowledgement_reward': ('_ZN5MGame10OnTouchEndEiiPv', 4176, 40, 'sha256:d90ffc2cb1e45cd28f6cad603147f0063db6c3442a7cdca526d335983b64b04f'),
           'entry_controller': ('_ZN11LevelScript7processEi', 804, 110, 'sha256:439279abfdf0fb69e4738726f3a2be4c418a0ac18dd52d0b83432e35525b395a')}
