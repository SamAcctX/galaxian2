"""B'akka36 result content and its existing shared pirate-contest condition.

The story owns a fixed population rather than the generated lounge recipe.
These declarations do not authorize flight, result acknowledgement or a career
transition. Those remain separate owners.
"""
import copy
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
