"""Guarded Mac declarations for the Ga'kkrr station visit at cursor 35.

The next contest is declared, not completed here. Only content identities and
constant parameters are emitted; no executable bytes or original logic run.

Android: Status::nextCampaignMission case 35 creates Mission(12, 0, 27);
cursor 35 has no radio lines (Level::createRadioMessages); DialogueWindow and
Globals::getDialogueSoundId hold its ten landed result lines (Android text
ids 2006-2015) and the two cursor-36 briefing lines (2016, 2017). Values are
the Mac 1.0.7 ones (this module's VALUES); the reader requires the Android
Nehma declaration.
"""
import copy

from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants
from .nehma_visit import VALUES as NEHMA_APP, MAC_VALUES as NEHMA_OLD


def extract_gakkrr_visit(mach, arrival, nehma):
    """Require the same edition's accepted Néhma prerequisite and every guard."""
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival and nehma == NEHMA_APP else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    if not proof or nehma != (NEHMA_APP, NEHMA_OLD)[variant]:
        return {}, {}
    return copy.deepcopy((VALUES, MAC_VALUES)[variant]), proof


VALUES = {
    "scope": "gakkrr_station_visit35",
    "mission35": {
        "campaign_cursor": 35, "kind": 11, "station_id": 29, "system_id": 5,
        "story": True, "reward": 0, "bonus": 0, "briefing_events": [],
        "result_events": [
            {"speaker_id": 7 if i % 2 == 0 else 0,
             "text_id": 1995 + i, "voice_event_id": 379 + i}
            for i in range(10)
        ],
        "completion": {
            "result_mode": 1, "requires_landed_target": True,
            "completed_on_result_open": True,
            "intermediate_next_keeps_cursor": 35,
            "final_next_requires_all_modal_acknowledgements": True,
            "final_next_advances_to_cursor": 36,
            "reward_credits": 0, "stays_landed_station_id": 29,
            "cargo_or_equipment_change": False, "ship_change": False,
            "extra_blueprint_change": False, "extra_system_access_granted": False,
        },
    },
    "world": {
        "authored_cast": [], "authored_radio_events": [],
        "selected_kind11_actor_count": 0,
    },
    "next_mission": {
        "campaign_cursor": 36, "kind": 12, "station_id": 27, "system_id": 5,
        "story": True, "reward": 0, "bonus": 0,
        "briefing_events": [
            {"speaker_id": 7, "text_id": 2005, "voice_event_id": 182},
            {"speaker_id": 0, "text_id": 2006, "voice_event_id": 183},
        ],
    },
}
MAC_VALUES = copy.deepcopy(VALUES)
for _event in (MAC_VALUES["mission35"]["result_events"] +
               MAC_VALUES["next_mission"]["briefing_events"]):
    _event["text_id"] -= 14

# Relative to the shared actor source anchor, in each source's own layout.
# Names remain distinct when merged with the prerequisite's provenance.
LAYOUTS = {
    "gakkrr_factory36_entry": [872178, 4, "__text", "33662043727d1701ce7a1354e0814bc1a3ade3b725eab4741859a6e028bd0e6e"],
    "gakkrr_factory36": [863336, 38, "__text", "a1454e65fdc97d3b93f646625d3fadb7e8148d8d9b84d692db6aef6a38361ce5"],
    "gakkrr_result35_count": [1530382, 4, "__const", "447e12701a0d03cf90a4ad7f02f1a045b35d284e26fe520440edb116d76bf700"],
    "gakkrr_result35_pairs": [1523210, 80, "__const", "d9991dc1e5a5ecaa312973e7e4098a4b207f35dc166ac93921009f8ab2253644"],
    "gakkrr_result35_voices": [1536946, 80, "__const", "5dc757d78d7b102b35966f3d37eea7a2ad9c0bab87e6a079f1cc9d8773560676"],
    "gakkrr_brief36_count": [1529730, 4, "__const", "fb5e512425fc9449316ec95969ebe71e2d576dbab833d61e2a5b9330fd70ee02"],
    "gakkrr_brief36_pairs": [1531122, 16, "__const", "4e8d5ad6ec98b6684920972ae4fdf422cac4ccdf83272e5f97294071b9deaa96"],
    "gakkrr_brief36_voices": [1535370, 16, "__const", "5da0cd2d97d05eb95d7d9e57774f0ceded0b2c9c71c6c6d7ed16791a23d00f1f"],
    "gakkrr_radio35_entry": [104626, 4, "__text", "252213ec6e7c761917a66a526c67bfe75b5eedfbc077d8a3368ae7908990604a"],
}
MAC_ALTERNATE = {
    "gakkrr_factory36_entry": [871546, 4, "__text", "33662043727d1701ce7a1354e0814bc1a3ade3b725eab4741859a6e028bd0e6e"],
    "gakkrr_factory36": [862704, 38, "__text", "88fb0c65e0be38189e11cc9e426272d732aecacbbbd97b283a184e1fce194d96"],
    "gakkrr_result35_count": [1555398, 4, "__const", "447e12701a0d03cf90a4ad7f02f1a045b35d284e26fe520440edb116d76bf700"],
    "gakkrr_result35_pairs": [1548226, 80, "__const", "46759b6c731f9d730272d572a283f5b5908538057c8838b6fa742665573c4a9d"],
    "gakkrr_result35_voices": [1561882, 80, "__const", "dd96b0216278407f817478ba67b7e723582d9b195f6000b57bc2aadefa8706aa"],
    "gakkrr_brief36_count": [1554746, 4, "__const", "fb5e512425fc9449316ec95969ebe71e2d576dbab833d61e2a5b9330fd70ee02"],
    "gakkrr_brief36_pairs": [1556122, 16, "__const", "da741547ab55894210ce9ae7c675489e11bfac200201ed63b8aeafa44a4fa968"],
    "gakkrr_brief36_voices": [1560306, 16, "__const", "71fa287d27ef5cf5d4fe4519774c3b060df80eda1e17d99edb0ae0faee41f512"],
    "gakkrr_radio35_entry": [104626, 4, "__text", "252213ec6e7c761917a66a526c67bfe75b5eedfbc077d8a3368ae7908990604a"],
}

ANDROID = {# Status::nextCampaignMission case 35: Mission(12, 0, 27).
           'gakkrr_factory36_entry': ('_ZN6Status19nextCampaignMissionEb', 138, 2, 'f00c'),
           'gakkrr_factory36': ('_ZN6Status19nextCampaignMissionEb', 6692, 30, 'sha256:a996fc36b98bf26e7bece8fed5b866b8bff8bc060161eb6447eeaee04b766d01'),
           'gakkrr_mission_constructor': ('_ZN7MissionC2Eiii', 0, 288, 'sha256:e034656d66c8e5c671a0fba356c49d2af308495b7a3dcda2601e9fb9457c9306'),
           # Cursor 35's results, cursor 36's briefing, all voices and no radio lines.
           'gakkrr_result35_count': ('_ZN14DialogueWindow18hasSuccessDialogueEi', 10, 4, '14000000', 'literal', 140),
           'gakkrr_result35_pairs': ('_ZN14DialogueWindow11loadContentEv', 208, 80, 'sha256:6a3d411e2507428432b8b2635158345927faa07fd16245fa30619262c0a7cc98', 'literal', 1864),
           'gakkrr_brief36_count': ('_ZN14DialogueWindow19hasBriefingDialogueEi', 10, 4, '04000000', 'literal', 144),
           'gakkrr_brief36_pairs': ('_ZN14DialogueWindow11loadContentEv', 128, 16, '07000000e007000000000000e1070000', 'literal', 224),
           'gakkrr_voices': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 8, 12032, 'sha256:24201ffc5c374c33aeec4660c20bd8af5788878246a0e6f0b1cae22c09895b52', 'literal', 0),
           'gakkrr_radio35_dispatch': ('_ZN5Level19createRadioMessagesEi', 0, 26, 'sha256:2fb27116c5cd427d3d8d01c2af84739cd96a13de8ea5fc929fb78c2963332596'),
           'gakkrr_radio35_entry': ('_ZN5Level19createRadioMessagesEi', 96, 2, '4119'),
           'gakkrr_radio_default': ('_ZN5Level19createRadioMessagesEi', 12956, 8, 'd4f8140102b0bde8')}
