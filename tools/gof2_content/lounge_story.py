"""Original station conversation after the earned contract threshold.

Android: ModStation::OnUpdate asks Status::missionCompleted for the won
kind-150 mission at the station and opens its success dialogue
(DialogueWindow::DialogueWindow, set); MGame::successCheck leaves it to the
station; ModStation::OnTouchEnd advances to Status::nextCampaignMission case 13
(Mission(4, 0, 79)). DialogueWindow's tables and Globals::getDialogueSoundId
hold the two lines. Values equal the Mac 1.0.7 ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_lounge_story(mach, arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(MAC_VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy((VALUES, MAC_VALUES)[variant]), proof) if proof else ({}, {})

VALUES = {'scope': 'mido_contract_story_handoff',
 'campaign_cursor': 13,
 'story_kind': 150,
 'station_scope': 'current_station',
 'acknowledgement_required': True,
 'events': [{'speaker_id': 3, 'text_id': 1792, 'voice_event_id': 222},
            {'speaker_id': 0, 'text_id': 1793, 'voice_event_id': 223}],
 'next_cursor': 14,
 'next_kind': 4,
 'next_station_id': 79,
 'reward': 0,
 'bonus': 0,
 'source_parameter': 0}

LAYOUTS = {'contract_story_dialogue': [1547114,
                             16,
                             '__const',
                             '920d83222b8e55ac2075a3fec397ed8aeeac95c8d64db4b75d82ef4be684c0e4'],
 'contract_story_voices': [1560626,
                           16,
                           '__const',
                           '048a42a2f230fb9e63abc11bca10ecdd1ef719d36ae7ca241f84d4bf0d49962c'],
 'contract_story_dialogue_count': [1555310,
                                   4,
                                   '__const',
                                   'fb5e512425fc9449316ec95969ebe71e2d576dbab833d61e2a5b9330fd70ee02'],
 'contract_story_station_poll': [446081,
                                 58,
                                 '__text',
                                 'f8ab2b62c439b2ef57a10b6d54d9c38e0e408432ad3f69af7a32f430c2760639'],
 'contract_story_station_result': [447318,
                                   69,
                                   '__text',
                                   '3e0ee597c8ca45b201c228b6a1a64a09a005b3a9a4e56f9783350abb096fe041'],
 'contract_story_acknowledged_story': [428880,
                                       54,
                                       '__text',
                                       'fba0754f1f13a5d5876f3b4ce2b76f286c3f8a340e8334f3daa4ee8ac302d594'],
 'contract_story_advance_story': [429803,
                                  32,
                                  '__text',
                                  'e5d75f54bd648b866fd0c6396f1bf12035b07c46a30ad0f349ba292f01b3a882'],
 'contract_story_advance_cursor': [859851,
                                   9,
                                   '__text',
                                   '98224ca6950faa2fc3633c703da68d1435c5d92e31ecc668256f6776bf490227'],
 'contract_story_next_mission': [861385,
                                 38,
                                 '__text',
                                 'ab51b26abc9a675cc574485fe1edef14243bb716e31d08f17fb5734e43518749'],
 'contract_story_result_mode': [-693553,
                                73,
                                '__text',
                                '287e45d0d4f73711ccccc508c77710f1ff335482f8976a6fcd4869157536c55b'],
 'contract_story_dialogue_constructor': [-694652,
                                         84,
                                         '__text',
                                         'a79548d6bf1c4e64a2239c2948aa0b00b9c5f390a33f7a7939c4377b06bcd337'],
 'contract_story_flight_defer_dialogue': [386979,
                                          88,
                                          '__text',
                                          '144e702569e563a7b25670e8b43b5ad5b426f0ad772b7c7f408d59590fc0f1f0'],
 'contract_story_flight_early_story': [388111,
                                       24,
                                       '__text',
                                       '40ce6014c69a9881f775974499c243447638fb0dc6c92ad34a8cf41b7da12f3c']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'contract_story_dialogue': [1522098,
                             16,
                             '__const',
                             '228a7d18a04be30f7c5ff209f0b2b5dabaa94d5cc0730e9287c07ca30a03d6ba'],
 'contract_story_voices': [1535690,
                           16,
                           '__const',
                           'cd61e4909279e0a73ae464e9938539b85dfc970325209e04f8f548eb53b489d0'],
 'contract_story_dialogue_count': [1530294,
                                   4,
                                   '__const',
                                   'fb5e512425fc9449316ec95969ebe71e2d576dbab833d61e2a5b9330fd70ee02'],
 'contract_story_station_poll': [446607,
                                 58,
                                 '__text',
                                 'd34f7870618d3ac5617d95936a56ab951e32bc6a6b54d2e4b4aec65a91330156'],
 'contract_story_station_result': [447844,
                                   69,
                                   '__text',
                                   'f515790ae6100b965b4bea3dababdd8f5037a5bf3206420792f217526568be58'],
 'contract_story_acknowledged_story': [429308,
                                       54,
                                       '__text',
                                       'b1ef70c58b888b8e718b7aeac0b8e41b1935d60bcbdc91c34d384a90d3f9f31d'],
 'contract_story_advance_story': [430231,
                                  32,
                                  '__text',
                                  '5f8d3f6e14f9212285ac1b113a001c1d540041ec9f7235d70c1db3c4835d9437'],
 'contract_story_advance_cursor': [860483,
                                   9,
                                   '__text',
                                   '98224ca6950faa2fc3633c703da68d1435c5d92e31ecc668256f6776bf490227'],
 'contract_story_next_mission': [862017,
                                 38,
                                 '__text',
                                 'b54ce9776473759ee30a1fc444a1b223f8bd2dc97c30fd06e38f02cc4eca399c'],
 'contract_story_result_mode': [-699449,
                                73,
                                '__text',
                                '46ba93bafb8859666914758e05f98b0789a5441fc2ffbdc89689100a070746b6'],
 'contract_story_dialogue_constructor': [-700548,
                                         84,
                                         '__text',
                                         'e9a3a6646800efe3bdf19ba0026a20d990d38a38e0a50dfdd61113d8decdaad7'],
 'contract_story_flight_defer_dialogue': [387495,
                                          88,
                                          '__text',
                                          '396a948abc657b0c2dca882faa2442ec9f4a38d8576bc4d1209b7ff9e4d26f3b'],
 'contract_story_flight_early_story': [388627,
                                       24,
                                       '__text',
                                       'd0801e70ee3fadd18cc87d8e3caa0dc856c63acf4e24fdc1c6d6d8313063c5ae']}
MAC_VALUES = {'scope': 'mido_contract_story_handoff',
 'campaign_cursor': 13,
 'story_kind': 150,
 'station_scope': 'current_station',
 'acknowledgement_required': True,
 'events': [{'speaker_id': 3, 'text_id': 1806, 'voice_event_id': 222},
            {'speaker_id': 0, 'text_id': 1807, 'voice_event_id': 223}],
 'next_cursor': 14,
 'next_kind': 4,
 'next_station_id': 79,
 'reward': 0,
 'bonus': 0,
 'source_parameter': 0}

# Android spans inside named functions and their tables; the values are MAC_VALUES.
ANDROID = {# ModStation::OnUpdate asks Status::missionCompleted at the station and opens the success dialogue.
           'contract_story_station_poll': ('_ZN10ModStation8OnUpdateEv', 0, 4016, 'sha256:5ea1f2b464ebfc3d848a87a9d50f3ddd2dde514688e13b51a4aab467e8fbc8a4'),
           # Kind 150 is won once the completed contracts reach its status value.
           'contract_story_gate': ('_ZN6Status16missionCompletedEbbx', 0, 1508, 'sha256:0162f8ffdfa5a9e47021d6551470479343189754dde03c334ec2ffc6cbb2634e'),
           'contract_story_dialogue_constructor': ('_ZN14DialogueWindowC2EP7MissionP5Leveli', 0, 86, 'sha256:af40e073975dc60ef72e866a79f8418a86327ba034ddf5328361b636e21e7b2b'),
           'contract_story_result_mode': ('_ZN14DialogueWindow3setEP7Missionii', 0, 120, 'sha256:9d7513e11d3d0954171e396f284ecca11aa43033d3d69c6f1e8da8a4c5cbecbb'),
           # ModStation::OnTouchEnd advances the campaign after the acknowledged story dialogue.
           'contract_story_acknowledged_story': ('_ZN10ModStation10OnTouchEndEiiPv', 0, 6536, 'sha256:5b29b2bf44b1e0a442eb14b5646a1aad12932fedee58112b028e31589316b50e'),
           # MGame::successCheck leaves a won story mission to the station.
           'contract_story_flight_defer_dialogue': ('_ZN5MGame12successCheckEv', 0, 1764, 'sha256:ea65079e511029adc0634a0ca72b39105a299c510ec2315692fb93d2d4ec9434'),
           # Status::nextCampaignMission: cursor 13 -> 14, Mission(4, 0, 79).
           'contract_story_dispatch': ('_ZN6Status19nextCampaignMissionEb', 58, 10, 'a12800f21b82dfe810f0'),
           'contract_story_case': ('_ZN6Status19nextCampaignMissionEb', 94, 2, '5a0e'),
           'contract_story_advance_cursor': ('_ZN6Status19nextCampaignMissionEb', 392, 8, '1846431c00214be7'),
           'contract_story_next_mission': ('_ZN6Status19nextCampaignMissionEb', 7416, 30, 'sha256:0ac3d0e6fb11d9a8c33c0fa39815408687aba9f7f2dee1622041276274b314b7'),
           # Cursor 13: two mode-1 events and their voices 222 and 223.
           'contract_story_dialogue_count': ('_ZN14DialogueWindow18hasSuccessDialogueEi', 10, 4, '04000000', 'literal', 52),
           'contract_story_dialogue': ('_ZN14DialogueWindow11loadContentEv', 208, 16, '0300000019070000000000001a070000', 'literal', 752),
           'contract_story_voices': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 8, 16, '19070000de0000001a070000df000000', 'literal', 472)}
