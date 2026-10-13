"""Guarded Mac declarations for the ordinary Dima91 return at cursor30.

Only bounded source constants and verified visit rules are emitted. Void29's
return portal and mission30's initial kind/target tuple remain owned by
void_probe; this reader does not execute or emit original code.

Android: MGame::OnUpdate returns through the portal to the course station and
Status::departStation and Level::init select the story; cursor 30 has no
case in Level::createCampaignMission, createRadioMessages or
LevelScript::process; Status::missionCompleted ends the kind-156 visit after
more than 10000 ms in flight and MGame::successCheck opens its five result
lines (Android text ids 1955-1959) after 5001 ms; MGame::OnTouchEnd advances
and Status::nextCampaignMission case 30 creates Mission(11, 30000, 98).
Values are the Mac 1.0.7 ones (this module's VALUES).
"""

import copy

from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants


def extract_dima_return(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy((VALUES, MAC_VALUES)[variant]), proof) if proof else ({}, {})


VALUES = {
    "scope": "dima_return_mission30",
    "mission30_ref": "void_probe.mission30_declaration",
    "world30": {
        "arrival_ref": "void_probe.world29.portal.return_after_final_next_ref",
        "selected_story_on_target_return": True,
        "story_cast_dispatch": "common_world_default",
        "authored_story_cast": [],
        "authored_story_radio_events": [],
        "mission_specific_stage": False,
        "completion": {
            "predicate": "selected_kind156_visit",
            "requires_in_flight": True,
            "target_station_ref": "void_probe.mission30_declaration.station_id",
            "world_elapsed_strictly_greater_than_ms": 10000,
            "hud_elapsed_at_least_ms": 5001,
            "controller_hold_clear": True,
            "result_opens_in": "flight",
        },
    },
    "result30": {
        "result_mode": 1,
        "briefing_events": [],
        "result_events": [
            {"speaker_id": 0, "text_id": 1944, "voice_event_id": 329},
            {"speaker_id": 6, "text_id": 1945, "voice_event_id": 330},
            {"speaker_id": 0, "text_id": 1946, "voice_event_id": 331},
            {"speaker_id": 6, "text_id": 1947, "voice_event_id": 332},
            {"speaker_id": 0, "text_id": 1948, "voice_event_id": 333},
        ],
        "completed_on_result_open": True,
        "final_next": {
            "requires_all_modal_acknowledgements": True,
            "advances_to_cursor": 31,
            "selected_story_mission_after": "kind_minus_one_sentinel",
            "reward_credits": 0,
            "bonus_credits": 0,
            "cargo_or_equipment_change": False,
            "location_change": False,
            "remains_in_flight_at_station_id": 91,
            "ordinary_docking_available_after": True,
        },
    },
    "next_mission_factory": {
        "campaign_cursor": 31,
        "kind": 11,
        "station_id": 98,
        "system_id": 19,
        "story": True,
        "reward_credits": 30000,
        "bonus_credits": 0,
    },
}

MAC_VALUES = copy.deepcopy(VALUES)
for _row, _text_id in zip(MAC_VALUES["result30"]["result_events"], range(1930, 1935)):
    _row["text_id"] = _text_id


# Complete variant guards relative to the established 315-byte actor anchor.
# The importer discards all source bytes after hashing these bounded windows.
LAYOUTS = {'portal_return_story_selection_call': [380163,
                                        53,
                                        '__text',
                                        '70f3c7bfd499217d75e60ecc10d1f7fbbec07517aaa046a7eeb89a20d523d70d'],
 'story_target_selection': [858108,
                            134,
                            '__text',
                            '375a8cf1336a30a89e17ef44fbfbd5fafb92646f428af2f7f139c621ce4bbd9b'],
 'story_selected_pointer_write': [857871,
                                  28,
                                  '__text',
                                  '33b02c7f69b1474b32d342e74296a0325bbc984e73f1cd11a87d9fae39dbaddf'],
 'world_selected_story': [-42091,
                          75,
                          '__text',
                          '8aa994a83d3a2502bb316093fec9666ebd07d869459b7566021e436a2bf02126'],
 'kind156_cast_dispatch': [2668, 33, '__text', '472a4fc75d775afe3c92f5d375d9ad655990d53ec6d958eca96fdfd523fcc8f9'],
 'kind156_cast_table_entry': [51414,
                              4,
                              '__text',
                              '4b4de3fd780c1598fee81a6ffff1cb79e610d1f2833aff86ee37897d45f6b823'],
 'common_world_default': [50503, 96, '__text', '70cc612edc5e22638f2136e759b00b1704a54a099f6e769ed6a521139b959ee1'],
 'radio30_dispatch_entry': [104606,
                            4,
                            '__text',
                            '252213ec6e7c761917a66a526c67bfe75b5eedfbc077d8a3368ae7908990604a'],
 'radio30_no_rows': [104126, 18, '__text', '6bf45c03269d1db2bb15b43cec7716427a0fd77b1abbeabbf0881f02ffdb6be0'],
 'stage_cursor_range_dispatch': [152218,
                                 26,
                                 '__text',
                                 '23bc006bab9a16564b3192ffe1b9ef40a326031bbe1752080c3f3edaad60eb2f'],
 'probe_stage29_only': [158956, 54, '__text', 'd8bd9f61a82a52f6a2aaca4e2c4125d2a87e09b43b00837838080fd121bc5f9e'],
 'kind156_visit_table_entry': [875890,
                               4,
                               '__text',
                               '44e6db8ff5fe147ec1b9d6ad94ad30417d6aa276f450cdb9be3d1d16baec00eb'],
 'kind156_visit_predicate': [875694,
                             54,
                             '__text',
                             '72a9691d0cb7be1d3437d26c9786f3b995f38ca33fbc93d83d958ef3aee3fb7b'],
 'flight_result_gate': [386369, 109, '__text', '2af73d00ee3e46e77974e9085966780544e1b6890ac57510a5d7156cf5443376'],
 'flight_result_open': [387751, 69, '__text', '18c016350e0859b81acec9d5ffd063eece112b1f7d995b124f549694336fdd2b'],
 'result_open_completion_mark': [-699449,
                                 21,
                                 '__text',
                                 '9ac9b75278cd1471014d9b2aa902c80d20bc29006d7eb82f80e757189a907756'],
 'briefing30_count': [1529706, 4, '__const', 'df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119'],
 'result30_count': [1530362, 4, '__const', '075de2b906dbd7066da008cab735bee896370154603579a50122f9b88545bd45'],
 'result30_pairs': [1522810, 40, '__const', 'dfce01d1ca534c1126683455865e217a16668703bf68a47e4a67eb053a1499b6'],
 'result30_voices': [1536546, 40, '__const', '5451e1c826a2df0e1f9badf4f3a26ee809a1a33f398bc839887b39dce7907048'],
 'final_next_advance_reward': [351990,
                               132,
                               '__text',
                               'ebfeae8ec6c3d30ba5df1fce0bee5b960576e9f75b9c7caf8337714e25fbdffa'],
 'final_next_special_cases': [352155,
                              511,
                              '__text',
                              'f705ba69a5cf90e82307156aec83d7f80f8abc4850d5bb0ff7611adb6a575b12'],
 'final_next_retire': [352666, 106, '__text', '86534471272c9e32850ae880fb81d8e009edc338c8025f4f486a34cb396c942c'],
 'factory31': [862947, 38, '__text', '45e6956a976ad0ebf9d9dbf3ac899781af65f3927c396bfb0e61238b3da9810d'],
 'station_contact_sentinel': [383568,
                              24,
                              '__text',
                              'f2490835939d777c4a406ba43230e0109b39d5f089883597474b53dcaeb8cc60']}
MAC_ALTERNATE = {'portal_return_story_selection_call': [379651,
                                        53,
                                        '__text',
                                        'ba265c9e1c06b8ff2a7e97e3e75334a688d86cf9543bd6c6fe0b1df24eb18fe7'],
 'story_target_selection': [857476,
                            134,
                            '__text',
                            '6bdf9aa4fff484c78ce80a032de42f66c8f32057b62c7a44bbd1be91318eef85'],
 'story_selected_pointer_write': [857239,
                                  28,
                                  '__text',
                                  '33b02c7f69b1474b32d342e74296a0325bbc984e73f1cd11a87d9fae39dbaddf'],
 'world_selected_story': [-42091,
                          75,
                          '__text',
                          'b056578bae65370af0b64cb1634466c6820cc7b3d8d30791fa37b9bf8e0be858'],
 'kind156_cast_dispatch': [2668, 33, '__text', '472a4fc75d775afe3c92f5d375d9ad655990d53ec6d958eca96fdfd523fcc8f9'],
 'kind156_cast_table_entry': [51414,
                              4,
                              '__text',
                              '4b4de3fd780c1598fee81a6ffff1cb79e610d1f2833aff86ee37897d45f6b823'],
 'common_world_default': [50503, 96, '__text', '534d8840b2bb6a4a3e681f2358bcf4909c2b05fa7f64a92241053d9ce9f24669'],
 'radio30_dispatch_entry': [104606,
                            4,
                            '__text',
                            '252213ec6e7c761917a66a526c67bfe75b5eedfbc077d8a3368ae7908990604a'],
 'radio30_no_rows': [104126, 18, '__text', '6bf45c03269d1db2bb15b43cec7716427a0fd77b1abbeabbf0881f02ffdb6be0'],
 'stage_cursor_range_dispatch': [152218,
                                 26,
                                 '__text',
                                 '23bc006bab9a16564b3192ffe1b9ef40a326031bbe1752080c3f3edaad60eb2f'],
 'probe_stage29_only': [158956, 54, '__text', '82283b815eaf7c818c2727915025e55610ba177c70863866b1535e4c2b772011'],
 'kind156_visit_table_entry': [875258,
                               4,
                               '__text',
                               '44e6db8ff5fe147ec1b9d6ad94ad30417d6aa276f450cdb9be3d1d16baec00eb'],
 'kind156_visit_predicate': [875062,
                             54,
                             '__text',
                             '97dac87f972ccf44ceb66358164e549ab04696a6d6e0b56fdd279e627bd79c1d'],
 'flight_result_gate': [385853, 109, '__text', '05669a65925ddf89a4050950070d6df77c7ea2e199b0f7646935e7c2dd28c5f8'],
 'flight_result_open': [387235, 69, '__text', 'a4df3f2c6ca4839073d59aded3ab5ccf24bc02729d7fb585aef56202649afe14'],
 'result_open_completion_mark': [-693553,
                                 21,
                                 '__text',
                                 '650b97df2203c0e75acae12f98601a8205587ba7723ea158ed9f6d7f31ca204c'],
 'briefing30_count': [1554722, 4, '__const', 'df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119'],
 'result30_count': [1555378, 4, '__const', '075de2b906dbd7066da008cab735bee896370154603579a50122f9b88545bd45'],
 'result30_pairs': [1547826, 40, '__const', '983ca9ed76aabd0a52397e5852c0224a90d271641547524c7d1ef32bcda0cbd3'],
 'result30_voices': [1561482, 40, '__const', '30daca1a27dae6e7204205c4361f39ed6e63ffbcd8d82a4f6fd674ae7d62d543'],
 'final_next_advance_reward': [352276,
                               132,
                               '__text',
                               'f5096f5485ce27c51aabe3497491022ae357d222a7df7fbcf37ca93b57cd1c66'],
 'final_next_special_cases': [352441,
                              511,
                              '__text',
                              '4efc8edd2bb9b1441b71308231aed402204faae899eb0b59166b751a137beb75'],
 'final_next_retire': [352952, 106, '__text', 'ac4de6b2d26fb2d4f40330f40e3a054dc8b63f4eef3f26af1f11632bcc123281'],
 'factory31': [862315, 38, '__text', 'd487e868bb5de2bff366a411495993e85f7d503f7958637fbfe0260668b29038'],
 'station_contact_sentinel': [383052,
                              24,
                              '__text',
                              'e2a830258b27c2ae0cbde8e2dd7b3a1084ebe1463dfb6c849cc4649e08e1a37f']}

ANDROID = {# The return, world selection and cursor 30's default world, radio and stage.
           'dima_return_portal_return_story_selection_call': ('_ZN5MGame8OnUpdateEv', 12080, 496, 'sha256:421dededd3cc1f9cd43234ad6868375cb2db5802c4591984b9f8d37797cae352'),
           'dima_return_story_target_selection': ('_ZN6Status13departStationEP7Station', 0, 1072, 'sha256:b7432b338855a0a259aa2b3d0d678bb305ea5293e9903e68114efafe3b6170d6'),
           'dima_return_world_selected_story': ('_ZN5Level4initEv', 0, 1792, 'sha256:fceec130c720743b341b16f0e8ce63d43a1382808e075533d391370c9949a244'),
           'dima_return_kind156_cast_dispatch': ('_ZN5Level21createCampaignMissionEv', 50, 72, 'sha256:199f7a8b39991522d2490e0f91eb46db22c738701ada8159377dbb7df6f2d3be'),
           'dima_return_kind156_cast_range': ('_ZN5Level21createCampaignMissionEv', 552, 10, 'ddf840a01d2807f2eb80'),
           'dima_return_common_world_default': ('_ZN5Level21createCampaignMissionEv', 29704, 26, 'sha256:51a12ccd37a83d3cc0390e228195c8a57dbd163b8258503299f415cf0179dcea'),
           'dima_return_radio30_dispatch': ('_ZN5Level19createRadioMessagesEi', 0, 26, 'sha256:2fb27116c5cd427d3d8d01c2af84739cd96a13de8ea5fc929fb78c2963332596'),
           'dima_return_radio30_dispatch_entry': ('_ZN5Level19createRadioMessagesEi', 86, 2, '4119'),
           'dima_return_radio30_no_rows': ('_ZN5Level19createRadioMessagesEi', 12956, 8, 'd4f8140102b0bde8'),
           'dima_return_stage_cursor_range_dispatch': ('_ZN11LevelScript7processEi', 2902, 16, '5b2876dc372800f368811c2800f35383'),
           'dima_return_stage_slot': ('_ZN11LevelScript7processEi', 4620, 18, '282800f364831d2801f0718528284bf06a81'),
           # Completion, the result, the final acknowledgement and case 30's Mission(11, 30000, 98).
           'dima_return_kind156_visit': ('_ZN6Status16missionCompletedEbbx', 0, 1508, 'sha256:0162f8ffdfa5a9e47021d6551470479343189754dde03c334ec2ffc6cbb2634e'),
           'dima_return_flight_result': ('_ZN5MGame12successCheckEv', 0, 1764, 'sha256:ea65079e511029adc0634a0ca72b39105a299c510ec2315692fb93d2d4ec9434'),
           'dima_return_result_open_completion_mark': ('_ZN14DialogueWindow3setEP7Missionii', 0, 120, 'sha256:9d7513e11d3d0954171e396f284ecca11aa43033d3d69c6f1e8da8a4c5cbecbb'),
           'dima_return_final_next': ('_ZN5MGame10OnTouchEndEiiPv', 0, 9784, 'sha256:fdba63f59493b8c11bd31fd1cad8857708de40b6cfb3e0221e5f2eba567c65e0'),
           'dima_return_factory_dispatch': ('_ZN6Status19nextCampaignMissionEb', 128, 2, '6302'),
           'dima_return_factory31': ('_ZN6Status19nextCampaignMissionEb', 1290, 30, 'sha256:cc7dd1b8b5ab9ae101ad27289149f24d68de0d3a8fbbe8ba6b24ca05aa00fcda'),
           'dima_return_mission_constructor': ('_ZN7MissionC2Eiii', 0, 288, 'sha256:e034656d66c8e5c671a0fba356c49d2af308495b7a3dcda2601e9fb9457c9306'),
           'dima_return_station_contact_sentinel': ('_ZN5MGame9dockEventEii', 0, 1500, 'sha256:c509b37791ee035ac28c716b3765e52ba5705d02fa07f400333fcb885a2b9ee0'),
           # Cursor 30: counts, the five result lines and all voices.
           'dima_return_briefing30_count': ('_ZN14DialogueWindow19hasBriefingDialogueEi', 10, 4, '00000000', 'literal', 120),
           'dima_return_result30_count': ('_ZN14DialogueWindow18hasSuccessDialogueEi', 10, 4, '0a000000', 'literal', 120),
           'dima_return_result30_pairs': ('_ZN14DialogueWindow11loadContentEv', 208, 40, 'sha256:10c2033d20a606c0e31314aa93c48d5941b20801d303246d3cae79419ffa7e38', 'literal', 1464),
           'dima_return_result30_voices': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 8, 12032, 'sha256:24201ffc5c374c33aeec4660c20bd8af5788878246a0e6f0b1cae22c09895b52', 'literal', 0)}
