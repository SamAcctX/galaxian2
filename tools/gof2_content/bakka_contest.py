"""B'akka36 result content and its existing shared pirate-contest condition.

The story owns a fixed population rather than the generated lounge recipe.
These declarations do not authorize flight, result acknowledgement or a career
transition. Those remain separate owners.

Android: Level::createCampaignMission case 36 names the rival (Android text
1604) through an Agent, builds the 4-point route from .rodata, the rival
(createShip(1, 0, 9) next to the player +-700, +1000 ahead, speed 3,
PlayerFighter::setRotate, 9999999 hull, friendly, no cargo, a cloned route)
and seven sleeping pirates (createShip(8, 0, Globals::getRandomEnemyFighter(8))
at random route points), then Objective(20, 1, 8) and Objective(21, 1, 8)
that Objective::achieved scores; cursor 36 has no radio lines; DialogueWindow
and Globals::getDialogueSoundId hold the two result lines (Android text ids
2018 and 2019). Values are the Mac 1.0.7 ones (VALUES); the reader requires
the Mac 1.0.7 Ga'kkrr visit.
"""
import copy
from .declaration_layouts import recognize_symbols
from .station_exterior import hashed_variants
from .gakkrr_visit import VALUES as GAKKRR_APP, MAC_VALUES as GAKKRR_OLD
from .contract_ship_lifecycle import VALUES as LIFECYCLE

VALUES = {
    'scope': 'bakka_pirate_contest36',
    'mission': copy.deepcopy(GAKKRR_APP['next_mission']),
    'encounter_kind': 12,
    'objectives': copy.deepcopy(LIFECYCLE['objectives']),
    'result_events': [
        {'speaker_id': 7, 'text_id': 2007, 'voice_event_id': 389},
        {'speaker_id': 0, 'text_id': 2008, 'voice_event_id': 390},
    ],
    'authored_radio_events': [],
    'population': {
        'actor_count': 8,
        'subtype': 0,
        'pirate_actor_kind': 8,
        'rival_actor_id': 0,
        'rival_actor_kind': 1,
        'rival_hull_catalogue_id': 9,
        'rival_name_text_id': 1593,
        'rival_position_bound': 1400,
        'rival_position_offset': -700,
        'rival_position_z_offset': 1000.0,
        'rival_base_speed': 3.0,
        'rival_speed': 3.0,
        'rival_current_hull_override': 9999999,
        'rival_friendly': True,
        'rival_retains_cargo': False,
        'rival_retains_generated_route': False,
        'pirate_mode': 5,
        'pirate_active': False,
        'pirate_targeting_blocked': True,
        'pirates_retain_cargo_and_routes': True,
        'route_initial_index': 0,
        'route_loop': False,
        'waypoints': [[110000, -10000, -80000], [70000, 0, -100000],
                      [-100000, 10000, -80000], [-130000, -50000, -150000]],
        'condition_first_actor': 1,
        'condition_end_actor': 8,
    },
}
MAC_VALUES = copy.deepcopy(VALUES)
MAC_VALUES['mission'] = copy.deepcopy(GAKKRR_OLD['next_mission'])
MAC_VALUES['population']['rival_name_text_id'] = 1585
for event in MAC_VALUES['result_events']:
    event['text_id'] -= 14


def extract_bakka_contest(mach, arrival, gakkrr):
    if mach.architecture == 'android-armv7':
        proof = recognize_symbols(mach, ANDROID) if arrival and gakkrr == GAKKRR_APP else {}
        return (copy.deepcopy(VALUES), proof) if proof else ({}, {})
    variant, proof = hashed_variants(mach, arrival, [LAYOUTS, MAC_ALTERNATE])
    if not proof or gakkrr != (GAKKRR_APP, GAKKRR_OLD)[variant]:
        return {}, {}
    return copy.deepcopy((VALUES, MAC_VALUES)[variant]), proof


LAYOUTS = {
    'bakka_population36_dispatch': [1233, 64, '__text', '216ef3ba7fcfad627ca2bc6b5154b3b0b5efce909e0f69f0e8fa18d46a34c84b'],
    'bakka_population_gate': [-42341, 312, '__text', '7834640169a9cb00008efdb3913e8af3a02bf23076f087c0b179b4217212a219'],
    'bakka_defeat_conditions': [481528, 1170, '__text', '914d71d12d2a226245b5a792f82d9c60dc7e24ebaa6b913c2d3e476bfbf5a966'],
    'bakka_result36_count': [1530386, 4, '__const', 'fb5e512425fc9449316ec95969ebe71e2d576dbab833d61e2a5b9330fd70ee02'],
    'bakka_result36_pairs': [1523290, 16, '__const', 'a4f56a01056c020d8c33b609cc263cb47e5631ed73b683ecf1bcdf24e98ba5ee'],
    'bakka_result36_voices': [1537026, 16, '__const', '3d91a35dc55f06315af6ae20494d519f75461b406c3916f50e6adb916e72620b'],
    'bakka_radio36_entry': [104630, 4, '__text', '252213ec6e7c761917a66a526c67bfe75b5eedfbc077d8a3368ae7908990604a'],
    'bakka_population36_entry': [51738, 4, '__text', '1b00db6c37d66e6425e4cd208cf257b689dec18107942c4f3d8f6648a29b01df'],
    'bakka_population36_case': [8434, 998, '__text', 'bffe64668ad9dff3d2aec754be8854507ebeb29c73783770b30b0631c3d11815'],
    'bakka_population36_path': [1554626, 48, '__const', 'a0461f655a46073a8b0aef51a95483707f4afdf6a07e6a92fabf74fac2fd0989'],
    'bakka_population36_speed': [1531910, 4, '__const', 'ea2845900b5856c9bf354b1aa9761b5aa6888e5ed61738fe9579ca42bc0f6054'],
    'bakka_population36_z': [1531930, 4, '__const', '07883481b5c147464597d44401db095d88c2a6b049fbbcd7b278de98a5ceeb71'],
}
MAC_ALTERNATE = {
    'bakka_population36_dispatch': [1233, 64, '__text', '216ef3ba7fcfad627ca2bc6b5154b3b0b5efce909e0f69f0e8fa18d46a34c84b'],
    'bakka_population_gate': [-42341, 312, '__text', 'c8df0640b69b9bb5de6b8ccae85c361d7ba09addcb7b948fb8d660d924182c3a'],
    'bakka_defeat_conditions': [481000, 1170, '__text', '7942a6a917f06f54d93bfa99ac27eefe9711185a46fc380abf7ee38446f81937'],
    'bakka_population36_entry': [51738, 4, '__text', '1b00db6c37d66e6425e4cd208cf257b689dec18107942c4f3d8f6648a29b01df'],
    'bakka_population36_case': [8434, 998, '__text', '2ac1fd0614d3dae69b7509ebe987dfcc589a530ccd99f79a48399ff1bbf15841'],
    'bakka_population36_path': [1579562, 48, '__const', 'a0461f655a46073a8b0aef51a95483707f4afdf6a07e6a92fabf74fac2fd0989'],
    'bakka_population36_speed': [1556910, 4, '__const', 'ea2845900b5856c9bf354b1aa9761b5aa6888e5ed61738fe9579ca42bc0f6054'],
    'bakka_population36_z': [1556930, 4, '__const', '07883481b5c147464597d44401db095d88c2a6b049fbbcd7b278de98a5ceeb71'],
    'bakka_result36_count': [1555402, 4, '__const', 'fb5e512425fc9449316ec95969ebe71e2d576dbab833d61e2a5b9330fd70ee02'],
    'bakka_result36_pairs': [1548306, 16, '__const', '5762782fd69722993787b223451f9a9d68252e5efda754be784c2e0cc12b961b'],
    'bakka_result36_voices': [1561962, 16, '__const', 'e8d46f44f06c4cf3ec7ceae883ec3dd01215383a52b719835c4d0ddaa8473bae'],
    'bakka_radio36_entry': [104630, 4, '__text', '252213ec6e7c761917a66a526c67bfe75b5eedfbc077d8a3368ae7908990604a'],
}

ANDROID = {# Level::createCampaignMission case 36: route, rival, seven pirates and the two contest objectives.
           'bakka_population36_dispatch': ('_ZN5Level21createCampaignMissionEv', 50, 108, 'sha256:12f545c9f45b98e1555ed2abcfb8fa33287cdd7d63c914d9c34e0aa888891c2a'),
           'bakka_population36_entry': ('_ZN5Level21createCampaignMissionEv', 158, 2, '8112'),
           'bakka_population36_case': ('_ZN5Level21createCampaignMissionEv', 9632, 660, 'sha256:3b638dddbca2e0ec0964d0fb6c0028d740019dc9e0260c24b5be4569db1d71cb'),
           'bakka_population36_conditions': ('_ZN5Level21createCampaignMissionEv', 21240, 8, 'caf82c5002f084b8'),
           'bakka_population36_path': ('_ZN5Level21createCampaignMissionEv', 9744, 48, 'sha256:a0461f655a46073a8b0aef51a95483707f4afdf6a07e6a92fabf74fac2fd0989', 'literal', 0),
           # Shared world, route and actor helpers; the contest scoring.
           'bakka_population_gate': ('_ZN5Level4initEv', 0, 1792, 'sha256:fceec130c720743b341b16f0e8ce63d43a1382808e075533d391370c9949a244'),
           'bakka_population_factory': ('_ZN5Level10createShipEiiiP8Waypointbb', 0, 3112, 'sha256:678eef9996991343994b4360f4e6ce25dc05eb2aab54b3b5f09e665f7f83d91c'),
           'bakka_population_route': ('_ZN5RouteC2EPii', 0, 252, 'sha256:ca7150cd62482cc53dbfdf0a65bbe663c975f533f5e0fa5d80515fc638df1c70'),
           'bakka_population_route_copy': ('_ZN5Route5cloneEv', 0, 348, 'sha256:c628d2ae59c27b4ad6e88c47bbcb48db0ee9fc8e6cc917af36c4ade43200da78'),
           'bakka_population_route_assignment': ('_ZN8KIPlayer8setRouteEP5Route', 0, 36, 'sha256:2f00603c48d28f9708289d12f63227139eebaa3ce45e155ddc64e7ddf20197b5'),
           'bakka_population_route_point': ('_ZN5Route11getWaypointEi', 0, 160, 'sha256:2e1859f50ce2c5863ea686738eaee454bb9897fffa2138de083e0c1f540a03c6'),
           'bakka_population_route_length': ('_ZN5Route6lengthEv', 0, 6, 'c06800687047'),
           'bakka_population_hull': ('_ZN7Globals21getRandomEnemyFighterEi', 0, 180, 'sha256:1d49b61c9159e9f48d52329d75df5467b226c40b845983a4b5820b1955e88682'),
           'bakka_population_rotation': ('_ZN13PlayerFighter9setRotateEi', 0, 24, '00ee101a0021b8eec00a80f8391180ed680a80ed7a0a7047'),
           'bakka_population_hitpoints': ('_ZN6Player12setHitpointsEi', 0, 18, '8167d0f884208a42b8bfc0f8841029f115bc'),
           'bakka_population_friendly': ('_ZN6Player15setAlwaysFriendEb', 0, 20, '80f8ed104ff48071a0f85c10002180f8e0107047'),
           'bakka_population_sleep': ('_ZN8KIPlayer10setToSleepEv', 0, 28, 'sha256:cc84c0937afb4bb67537f3edaabf3c0dddc9ff41c2ff7882b2060d2d3248972a'),
           'bakka_condition_constructor': ('_ZN9ObjectiveC2EiiiP5Level', 0, 26, 'sha256:30dd11b72e7d11ccea2af7a074ffa56174271f930893296da195a02e4f32586d'),
           'bakka_defeat_conditions': ('_ZN9Objective8achievedEi', 0, 978, 'sha256:da3086f410423068084e2547c16738945cb696b15a3685f82075a90dd6538eab'),
           # Cursor 36: the two result lines, all voices and no radio lines.
           'bakka_result36_count': ('_ZN14DialogueWindow18hasSuccessDialogueEi', 10, 4, '04000000', 'literal', 144),
           'bakka_result36_pairs': ('_ZN14DialogueWindow11loadContentEv', 208, 16, '07000000e207000000000000e3070000', 'literal', 1944),
           'bakka_result36_voices': ('_ZN7Globals18getDialogueSoundIdEiP5Agent', 8, 12032, 'sha256:24201ffc5c374c33aeec4660c20bd8af5788878246a0e6f0b1cae22c09895b52', 'literal', 0),
           'bakka_radio36_dispatch': ('_ZN5Level19createRadioMessagesEi', 0, 26, 'sha256:2fb27116c5cd427d3d8d01c2af84739cd96a13de8ea5fc929fb78c2963332596'),
           'bakka_radio36_entry': ('_ZN5Level19createRadioMessagesEi', 98, 2, '4119'),
           'bakka_radio_default': ('_ZN5Level19createRadioMessagesEi', 12956, 8, 'd4f8140102b0bde8')}
