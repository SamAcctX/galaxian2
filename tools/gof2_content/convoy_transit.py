"""Verified ordinary travel before the convoy story target is selected.

Android: Status::departStation selects the cursor-14 convoy story mission
(Status::nextCampaignMission case 13: Mission(4, 0, 79),
Status::setCampaignMission) before an accepted side mission, which stays;
ModStation::OnTouchEnd departs; Level::assignGuns gives the NPCs 600 - 2 x 14 =
572 ms between shots. Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants

def extract_convoy_transit(mach,arrival):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    return (copy.deepcopy(VALUES), proof) if proof else ({}, {})

VALUES = {'scope': 'mido_convoy_transit',
 'campaign_cursor': 14,
 'system_id': 15,
 'story_kind': 4,
 'story_station_id': 79,
 'story_reward': 0,
 'requires_target_match': True,
 'story_precedes_side_mission': True,
 'retains_side_mission': True,
 'npc_weapon_interval_ms': 572}

LAYOUTS = {'convoy_transit_selection': [856506,
                              1129,
                              '__text',
                              'e3f766995d67858baf291908dc9367266796ae96e6c29cb8c7ff1d87c2bc9f04'],
 'convoy_transit_story_factory': [861385,
                                  38,
                                  '__text',
                                  'ab51b26abc9a675cc574485fe1edef14243bb716e31d08f17fb5734e43518749'],
 'convoy_transit_story_slot': [859544,
                               122,
                               '__text',
                               '0e1548dc4236b4a447747ac3453da996a0e60f5019e81f51aa757bd81957dbcb'],
 'convoy_transit_departure_selection': [428158,
                                        29,
                                        '__text',
                                        '5454c8eb6d87758d902f2748251c82abad08fa1715b891304c4b1ba3bc6d423e'],
 'convoy_transit_departure_state': [431869,
                                    126,
                                    '__text',
                                    'faf79612974e31946653c4d52efa1d5977ea201dc5e3e86d8a07d688248fa066'],
 'convoy_transit_weapon_interval': [57315,
                                    107,
                                    '__text',
                                    '6353c882b18462d64aecbfe0935f84872953e14fbf57c81810fda3a832246ceb']}

# Complete alternate source declarations; no executable payloads.
MAC_ALTERNATE = {'convoy_transit_selection': [857138,
                              1129,
                              '__text',
                              '2f9d211b068e4815964b861f9b796bf53c7f5fe2966af1910393455031c71b55'],
 'convoy_transit_story_factory': [862017,
                                  38,
                                  '__text',
                                  'b54ce9776473759ee30a1fc444a1b223f8bd2dc97c30fd06e38f02cc4eca399c'],
 'convoy_transit_story_slot': [860176,
                               122,
                               '__text',
                               '739abc1d077b3983a8608e92b4711ce6f40ea480212abdb3ad1c54fe24a01ba1'],
 'convoy_transit_departure_selection': [428586,
                                        29,
                                        '__text',
                                        '6be22aa6a0c6edf07dc62ed927c1ff27a2cd40074e59748fb1803c65b6e2d0b4'],
 'convoy_transit_departure_state': [432297,
                                    126,
                                    '__text',
                                    '22e22d431eb8490d3fb080a6ff593846fe5a8be334465ac95478827768b22415'],
 'convoy_transit_weapon_interval': [57315,
                                    107,
                                    '__text',
                                    '6e0a51579be6a46943b6d74e57818e23f0d29d5697488eb4ce573b1d36a9e18c']}

# Android spans inside named functions and their tables; the values are VALUES.
ANDROID = {# Status::departStation: the convoy story mission is selected before a side mission, which stays.
           'convoy_transit_selection': ('_ZN6Status13departStationEP7Station', 0, 1072, 'sha256:b7432b338855a0a259aa2b3d0d678bb305ea5293e9903e68114efafe3b6170d6'),
           # Status::nextCampaignMission case 13: Mission(4, 0, 79).
           'convoy_transit_dispatch': ('_ZN6Status19nextCampaignMissionEb', 58, 10, 'a12800f21b82dfe810f0'),
           'convoy_transit_case': ('_ZN6Status19nextCampaignMissionEb', 94, 2, '5a0e'),
           'convoy_transit_story_factory': ('_ZN6Status19nextCampaignMissionEb', 7416, 30, 'sha256:0ac3d0e6fb11d9a8c33c0fa39815408687aba9f7f2dee1622041276274b314b7'),
           'convoy_transit_story_slot': ('_ZN6Status18setCampaignMissionEP7Mission', 0, 72, 'sha256:1d0b38f030f7e22ca6bc067f23404c8a6c8e5ff95990b29a89f875b44a0209c1'),
           'convoy_transit_departure': ('_ZN10ModStation10OnTouchEndEiiPv', 0, 6536, 'sha256:5b29b2bf44b1e0a442eb14b5646a1aad12932fedee58112b028e31589316b50e'),
           # Level::assignGuns: 600 - 2 x 14 = 572 ms between NPC shots.
           'convoy_transit_weapon_interval': ('_ZN5Level10assignGunsEv', 0, 3320, 'sha256:2d4c9a0a16410a8459ff79a6c70158b826a10813a8dee82ee37fe387abbcec55')}
