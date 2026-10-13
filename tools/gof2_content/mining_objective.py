"""Bounded cargo/return declarations; executable bytes are never runtime data.

Android: Status::nextCampaignMission creates mission 154 at station 78 with
status value 10 for cursor 2 and mission 11 for cursor 3;
Status::missionCompleted completes it once Ship::getCurrentLoad reaches that
value. MGame::successCheck polls after 5001 ms and opens DialogueWindow's
mode-1 lines (texts 1717-1719, voices from Globals::getDialogueSoundId);
MGame::OnUpdate and gameOverCheck run the poll clock; MGame::OnTouchEnd's last
page advances the campaign and pays the mission. Android never substitutes
desktop text: the return instruction stays text 1719, without desktop pair or
key tokens.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols

def extract_mining_objective(mach, arrival, flight, presentation, desktop, briefing):
    if mach.architecture == 'android-armv7':
        try:
            if (flight['scope'] != 'first_mining_flight_construction' or presentation['scope'] != 'first_station_presentation'
                    or briefing['scope'] != 'first_mining_briefing'): return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(ANDROID_VALUES), provenance=proof) if proof else {}
    if mach.architecture!='x86_64' or flight.get('scope')!='first_mining_flight_construction':return {}
    if presentation.get('scope')!='first_station_presentation' or briefing.get('scope')!='first_mining_briefing':return {}
    try:
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts)
        if not proof:return {}
        values=MAC_VALUES if proof['mode1_events']['offset']==origin['offset']+MAC_ALTERNATE['mode1_events'][0] else VALUES
        if values['desktop_instruction'] not in desktop.get('pairs',[]):return {}
        result=copy.deepcopy(values);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'first_mining_cargo_objective',
 'campaign_cursor': 2,
 'mission_kind': 154,
 'station_id': 78,
 'required_cargo': 10,
 'cargo_metric': 'total_used',
 'poll_minimum_ms': 5001,
 'max_frame_ms': 150,
 'initial_clock_held': False,
 'entry_controller_holds_clock': True,
 'idle_poll_discards_overshoot': True,
 'completion_opening_holds_camera': True,
 'mode': 1,
 'cursor_after_acknowledgement': 3,
 'next_kind': 11,
 'reward_credits': 0,
 'bonus_credits': 0,
 'station_return_required': True,
 'next_text_id': 179,
 'final_text_id': 180,
 'events': [{'speaker_id': 2, 'text_id': 1706, 'voice_event_id': 327},
            {'speaker_id': 0, 'text_id': 1707, 'voice_event_id': 328},
            {'speaker_id': 16, 'text_id': 1708, 'voice_event_id': -1}],
 'desktop_instruction': [1708, 1709],
 'key_tokens': ['#KEY_AUTOPILOT', '#KEY_DOCK']}

LAYOUTS = {'mode1_counts': [1555258, 12, '__const', '000000002600000006000000'],
 'mode1_events': [1546514, 24, '__const', '02000000aa06000000000000ab06000010000000ac060000'],
 'voice_events': [1561466, 16, '__const', 'aa06000047010000ab06000048010000'],
 'cargo_getter': [729972, 10, '__text', '554889e58b47105dc390'],
 'parameter_getter': [400574, 12, '__text', '554889e58b87900000005dc3'],
 'shown_getter': [400508, 10, '__text', '554889e58a470124015d'],
 'shown_setter': [400498, 10, '__text', '554889e5408877015dc3'],
 'cargo_dispatch': [875250, 4, '__text', '5dfaffff'],
 'cargo_predicate': [873791, 24, '__text', '498bbd00020000e829cefdff89c3e9500300008b45d43c01'],
 'cargo_compare': [874658, 22, '__text', '4c89ffe814c4f8ff39c30f8cdd000000e9f50100004c'],
 'cargo_success': [875180, 18, '__text', '4c89ffbe01000000e8b9c1f8ff4c89f8ebdf'],
 'poll_gate': [385853,
               89,
               '__text',
               '49817f50891300007c0a41f68720010000017427488d052a581f00488b38e8d83407004889c7e86239000089c130c081f9aa0000000f8520090000488d0503581f00488b38498b8798000000488b480831f631d2e84e700700'],
 'poll_reset': [388744, 22, '__text', '48817b50891300000f8cf400000048c7435000000000'],
 'completion_order': [377531,
                      73,
                      '__text',
                      '41f6456c017542498b7d60e8a3c8020084c0752b488d05ac781f00488b38e86e5507004889c7e88259000084c075104c89efe8de1f000084c00f85ed0800004c89efe8c0290000eb12'],
 'completion_dialogue_test': [387006,
                              61,
                              '__text',
                              '488d05bd531f00488b38e87f3007004889c7e8033600003c010f8532040000488d059e531f00488b38e84030070089c7e8fb86efff3c010f8514040000'],
 'completion_dialogue_start': [387235,
                               69,
                               '__text',
                               '498b9fb80000004d85f67512488d05cc521f00488b38e88e2f07004989c64889df4c89f6ba01000000b9ffffffffe89e81efff41c6476a0141c64769014c89ffe8584bffff'],
 'dialogue_mode': [-693532,
                   52,
                   '__text',
                   '41c7476c000000004183feff7512488d0589d02f00488b38e82bad17004189c6458977204c89ff5b415c415e415f5de9f8030000'],
 'mission_next': [859851, 23, '__text', 'ffc041898678020000498b8e4802000049898e60010000'],
 'next_dispatch': [871414, 4, '__text', '72d5ffff'],
 'next_mission': [860512,
                  49,
                  '__text',
                  'bf98000000e8c2600a004889c34889dfbe0b00000031d2b94e000000e817f6f8ff4c89f74889dee80cfcffffe9242a0000'],
 'final_advance': [352276,
                   37,
                   '__text',
                   '4d89e54c89f7e8b9bd0000488d0d5cdb1f00488b3984c0740cbe01000000e863be0700eb38'],
 'final_reward': [352369,
                  64,
                  '__text',
                  '488d050adb1f004c8b204c89f7e803bd000089c34c89f7e821bd00008d34184c89e7e8deed07004d89ec498b842498000000c700000000004c89f7e827bd0000'],
 'final_cleanup': [352952,
                   122,
                   '__text',
                   '4584ff7565498bbc2490000000e8806cfcff488d0549e01f00488b30488d05a7d81f00488b38e81db50700498b7c246031f6e811280300498b7c2460e87b3303003c01750c498b7c246031f6e8ff310300498b7c2460e809280300498bbc249000000031f6e802dcfbff4c89f7e8aeba000084c00f85c40b0000'],
 'final_reset': [356086, 27, '__text', '49c744243800000000498bbc2488000000e8de28f9ffe9afe5ffff'],
 'clock_initial': [338262,
                   51,
                   '__text',
                   'c6436900c6436b0048c7435000000000c6830c01000000c6830901000000c6830801000000c6830a01000000c6830d01000000'],
 'clock_modal_gate': [364625, 11, '__text', '41f64569010f85410b0000'],
 'clock_increment': [365124, 19, '__text', '41f6456b010f85140400004963454849014550'],
 'controller_initial_hold': [121658, 5, '__text', '41c6471101'],
 'controller_initial_override': [121716, 5, '__text', '41c6471200'],
 'controller_release': [151090,
                        87,
                        '__text',
                        '41817d30591b00000f8c0701000041c745300000000041c6452c0041c6452d01498b7d1831f6e803940b00498b7d20e8744fffff488b38be01000000e8a7e5050041c6451100498b7d20e8594fffff4889c7be01000000'],
 'controller_return': [230741, 7, '__text', '418a4424112401'],
 'controller_clock_order': [377622, 24, '__text', '418a5d6b418b7548498bbd98000000e8965afcff4188456b'],
 'controller_override_clock': [378039, 14, '__text', 'f6401201740849c7455089130000'],
 'initial_briefing_dispatch': [375756,
                               113,
                               '__text',
                               '49817d50891300007c4541f6456a01753e488d059e7f1f00488b38e8605c07004889c7e87460000084c07523488d05837f1f00488b38e8455c07004889c7e86d60000084c075084c89efe89d240000498b7d60e82ecc02003c010f858f060000498b7d60e86137030084c00f857e060000'],
 'initial_player_mode': [550660, 7, '__text', 'c6838c01000000'],
 'player_mode_getter': [559186, 14, '__text', '554889e58a878c01000024015dc3']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'mode1_counts': [1530242, 12, '__const', '000000002600000006000000'],
 'mode1_events': [1521498, 24, '__const', '02000000b506000000000000b606000010000000b7060000'],
 'voice_events': [1536530, 16, '__const', 'b506000047010000b606000048010000'],
 'cargo_getter': [730596, 10, '__text', '554889e58b47105dc390'],
 'parameter_getter': [401090, 12, '__text', '554889e58b87900000005dc3'],
 'shown_getter': [401024, 10, '__text', '554889e58a470124015d'],
 'shown_setter': [401014, 10, '__text', '554889e5408877015dc3'],
 'cargo_dispatch': [875882, 4, '__text', '5dfaffff'],
 'cargo_predicate': [874423, 24, '__text', '498bbd00020000e821cefdff89c3e9500300008b45d43c01'],
 'cargo_compare': [875290, 22, '__text', '4c89ffe8a0c3f8ff39c30f8cdd000000e9f50100004c'],
 'cargo_success': [875812, 18, '__text', '4c89ffbe01000000e845c1f8ff4c89f8ebdf'],
 'poll_gate': [386369,
               89,
               '__text',
               '49817f50891300007c0a41f68720010000017427488d05fefd1e00488b38e84c3507004889c7e86239000089c130c081f9aa0000000f8520090000488d05d7fd1e00488b38498b8798000000488b480831f631d2e8c2700700'],
 'poll_reset': [389260, 22, '__text', '48817b50891300000f8cf400000048c7435000000000'],
 'completion_order': [378043,
                      73,
                      '__text',
                      '41f6456c017542498b7d60e8bbc8020084c0752b488d05841e1f00488b38e8e65507004889c7e88659000084c075104c89efe8e21f000084c00f85ed0800004c89efe8c4290000eb12'],
 'completion_dialogue_test': [387522,
                              61,
                              '__text',
                              '488d0591f91e00488b38e8f33007004889c7e8033600003c010f8532040000488d0572f91e00488b38e8b430070089c7e8ef6defff3c010f8514040000'],
 'completion_dialogue_start': [387751,
                               69,
                               '__text',
                               '498b9fb80000004d85f67512488d05a0f81e00488b38e8023007004989c64889df4c89f6ba01000000b9ffffffffe89268efff41c6476a0141c64769014c89ffe83648ffff'],
 'dialogue_mode': [-699428,
                   52,
                   '__text',
                   '41c7476c000000004183feff7512488d05698f2f00488b38e8abc617004189c6458977204c89ff5b415c415e415f5de9f8030000'],
 'mission_next': [860483, 23, '__text', 'ffc041898678020000498b8e4802000049898e60010000'],
 'next_dispatch': [872046, 4, '__text', '72d5ffff'],
 'next_mission': [861144,
                  49,
                  '__text',
                  'bf98000000e896fc09004889c34889dfbe0b00000031d2b94e000000e8a3f5f8ff4c89f74889dee80cfcffffe9242a0000'],
 'final_advance': [351990, 37, '__text', '4d89e54c89f7e8dbc00000488d0d52841f00488b3984c0740cbe01000000e8f9c10700eb38'],
 'final_reward': [352083,
                  64,
                  '__text',
                  '488d0500841f004c8b204c89f7e825c0000089c34c89f7e843c000008d34184c89e7e874f107004d89ec498b842498000000c700000000004c89f7e849c00000'],
 'final_cleanup': [352666,
                   122,
                   '__text',
                   '4584ff7565498bbc2490000000e89e6dfcff488d0557891f00488b30488d059d811f00488b38e8b3b80700498b7c246031f6e8472b0300498b7c2460e8b13603003c01750c498b7c246031f6e835350300498b7c2460e83f2b0300498bbc249000000031f6e820ddfbff4c89f7e8d0bd000084c00f85c40b0000'],
 'final_reset': [355800, 27, '__text', '49c744243800000000498bbc2488000000e8fc29f9ffe9afe5ffff'],
 'clock_initial': [337962,
                   51,
                   '__text',
                   'c6436900c6436b0048c7435000000000c6830c01000000c6830901000000c6830801000000c6830a01000000c6830d01000000'],
 'clock_modal_gate': [364348, 11, '__text', '41f64569010f85480b0000'],
 'clock_increment': [364847, 19, '__text', '41f6456b010f85140400004963454849014550'],
 'controller_initial_hold': [121658, 5, '__text', '41c6471101'],
 'controller_initial_override': [121716, 5, '__text', '41c6471200'],
 'controller_release': [151090,
                        87,
                        '__text',
                        '41817d30591b00000f8c0701000041c745300000000041c6452c0041c6452d01498b7d1831f6e87b960b00498b7d20e8744fffff488b38be01000000e8bfe7050041c6451100498b7d20e8594fffff4889c7be01000000'],
 'controller_return': [230755, 7, '__text', '418a4424112401'],
 'controller_clock_order': [378134, 24, '__text', '418a5d6b418b7548498bbd98000000e89658fcff4188456b'],
 'controller_override_clock': [378551, 14, '__text', 'f6401201740849c7455089130000'],
 'initial_briefing_dispatch': [376268,
                               113,
                               '__text',
                               '49817d50891300007c4541f6456a01753e488d0576251f00488b38e8d85c07004889c7e87860000084c07523488d055b251f00488b38e8bd5c07004889c7e87160000084c075084c89efe8a1240000498b7d60e846cc02003c010f858f060000498b7d60e87937030084c00f857e060000'],
 'initial_player_mode': [551196, 7, '__text', 'c6838c01000000'],
 'player_mode_getter': [559722, 14, '__text', '554889e58a878c01000024015dc3']}
MAC_VALUES = {'scope': 'first_mining_cargo_objective',
 'campaign_cursor': 2,
 'mission_kind': 154,
 'station_id': 78,
 'required_cargo': 10,
 'cargo_metric': 'total_used',
 'poll_minimum_ms': 5001,
 'max_frame_ms': 150,
 'initial_clock_held': False,
 'entry_controller_holds_clock': True,
 'idle_poll_discards_overshoot': True,
 'completion_opening_holds_camera': True,
 'mode': 1,
 'cursor_after_acknowledgement': 3,
 'next_kind': 11,
 'reward_credits': 0,
 'bonus_credits': 0,
 'station_return_required': True,
 'next_text_id': 179,
 'final_text_id': 180,
 'events': [{'speaker_id': 2, 'text_id': 1717, 'voice_event_id': 327},
            {'speaker_id': 0, 'text_id': 1718, 'voice_event_id': 328},
            {'speaker_id': 16, 'text_id': 1719, 'voice_event_id': -1}],
 'desktop_instruction': [1719, 1720],
 'key_tokens': ['#KEY_AUTOPILOT', '#KEY_DOCK']}

# Android: the Mac 1.0.7 values without the desktop pair and key tokens (Android shows text 1719 as written).
ANDROID_VALUES = dict(copy.deepcopy(MAC_VALUES), desktop_instruction=[], key_tokens=[])

# Android spans inside named functions and tables.
ANDROID = {# Mode 1 (success) tables: entries per cursor (0, 38, 6), cursor 2's three lines and their voices.
           'mode1_counts': ('_ZN14DialogueWindow18hasSuccessDialogueEi', 10, 12, '000000002600000006000000', 'literal', 0),
           'mode1_events': ('_ZN14DialogueWindow11loadContentEv', 208, 24, '02000000c006000000000000c106000010000000c2060000', 'literal', 152),
           'voice_events': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 8, 16, 'c006000047010000c106000048010000', 'literal', 1312),
           # Status::nextCampaignMission: cursor 2 creates mission 154 at station 78 with status value 10
           # (Mission::setStatusValue through the veneer); cursor 3 creates mission 11 at station 78.
           'story_dispatch': ('_ZN6Status19nextCampaignMissionEb', 58, 10, 'a12800f21b82dfe810f0'),
           'dispatch_entries': ('_ZN6Status19nextCampaignMissionEb', 68, 6, 'ad029804ae04'),
           'story_increment': ('_ZN6Status19nextCampaignMissionEb', 392, 6, '1846431c0021'),
           'mission_creation': ('_ZN6Status19nextCampaignMissionEb', 2420, 44, 
                          '6420c4f8e831c9e900ceb0f7feeb05469a2100224e23b4f794ed20462946b4f79cedd4f894010a2101f042bb'),
           'mission_parameter': ('_ZN6Status19nextCampaignMissionEb', 8228, 14, '4068006801b0bde8f04320f17fb9'),
           'return_mission': ('_ZN6Status19nextCampaignMissionEb', 2464, 30, 'sha256:1c7d17e109303b1b338dfc8f13c8fe529e6dc319fddac3bbeb17ba31b9aad86e'),
           'campaign_mission_tail': ('_ZN6Status19nextCampaignMissionEb', 426, 14, '2046294601b0bde8f04322f19cb8'),
           # Status::missionCompleted: kind 154 completes once Ship::getCurrentLoad reaches the status value.
           'cargo_dispatch': ('_ZN6Status16missionCompletedEbbx', 190, 18, '2046b2f70ae8a0f19601272931d8dfe811f0'),
           'cargo_entry': ('_ZN6Status16missionCompletedEbbx', 216, 2, 'd300'),
           'cargo_check': ('_ZN6Status16missionCompletedEbbx', 630, 30, 'daf88c01b2f7dee8054601e0daf8d4512046b1f732ef8542c0f23b8189e1'),
           'cargo_getter': ('_ZN4Ship14getCurrentLoadEv', 0, 4, '00697047'),
           'parameter_getter': ('_ZN7Mission14getStatusValueEv', 0, 4, 'c06d7047'),
           # MGame: the poll clock grows while LevelScript does not hold it, polls after 5001 ms, opens the
           # mode-1 dialogue (paused), restarts after 5001 ms (gameOverCheck) and is set to 5001 on override.
           'poll_gate': ('_ZN5MGame12successCheckEv', 26, 94, 'sha256:5dd71d2ec1bfa64dc6073b47c25d48197de55b1fc2b13288120c5eba452a8534'),
           'completion_dialogue': ('_ZN5MGame12successCheckEv', 758, 254, 'sha256:cc9e1612d8b35e14983c76cffa992b0ae0a77b0700029d53f7eafa309283ce14'),
           'poll_clock': ('_ZN5MGame8OnUpdateEv', 1370, 28, 'sha256:2251705a785979a53386dfb063f6ea18c5cdd47effeac8f14e428d728696fd85'),
           'poll_order': ('_ZN5MGame8OnUpdateEv', 10610, 68, 'sha256:5cead00995c8f5d9fa7f35a7764170927f18222589b0d8d0a03946ba561d441c'),
           'poll_override': ('_ZN5MGame8OnUpdateEv', 10962, 26, 'sha256:a3093c771c243e790e1e79e688e5dce670bef11c68c62cd0df491c80d7fd272e'),
           'poll_reset': ('_ZN5MGame13gameOverCheckEv', 412, 26, 'sha256:49d3b863751918f023b1566c6e9ff0c0d571c271033948e5971438ffc1072452'),
           'dialogue_mode': ('_ZN14DialogueWindow11loadContentEv', 112, 120, 'sha256:44637e351fc8ea38250e77202efd5afc767c7bfb83378394e28f9d254cb95ce9'),
           # MGame::OnTouchEnd: the last page advances the won campaign mission (nextCampaignMission) and pays it.
           'final_acknowledgement': ('_ZN5MGame10OnTouchEndEiiPv', 972, 76, 'sha256:3cf5791f50b694969248783ea1269bc9c5ca6b669f688fe8fbfea0549b01383c'),
           'final_advance': ('_ZN5MGame10OnTouchEndEiiPv', 3520, 116, 'sha256:c89a74908121919a930ab10c977e6f8ca75a311b8d315f798c9be33af9e953aa'),
           'final_reward': ('_ZN5MGame10OnTouchEndEiiPv', 4176, 40, 'sha256:d90ffc2cb1e45cd28f6cad603147f0063db6c3442a7cdca526d335983b64b04f')}
