"""Optional Mac combat-training actor and authored-route declarations.

Static reader only: emits constants and file extents, never executable bytes.

Android: Level::createCampaignMission's cursor-7 case (tbh entry 7) builds a
6-word Route (Route::Route, Waypoint::Waypoint) and four actors: three
Level::createShip(8, 0, 2, waypoint 1, true, false) pirates put to sleep
(KIPlayer::setToSleep: mode 5, inactive, targeting blocked) and the companion
Level::createShip(3, 0, 30, none, true, false), always friendly
(Player::setAlwaysFriend), at the player + (700, 50, 6000) through
PlayerFighter's vtable slot 18, on a Route::clone of the route
(KIPlayer::setRoute), with 9999999 hull points (Player::setHitpoints) and
name 1599 (Mac 1588). Level::assignGuns and Gun::setIndex arm them as on the
Mac. Values equal the Mac 1.0.7 ones.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes, vtable_proof

def extract_combat_training(mach,arrival,equipment,actors):
    if mach.architecture == 'android-armv7':
        try:
            if equipment['scope'] != 'var_hastra_equipment_tutorial': return {}
            npc = actors['npc_initialization']
            if not all(npc.get(k) for k in ['construction', 'routes', 'world_initialization']): return {}
        except (KeyError, TypeError, AttributeError): return {}
        proof, slots = recognize_symbols(mach, ANDROID), vtable_proof(mach, ANDROID_VTABLES)
        return dict(copy.deepcopy(MAC_VALUES), provenance={**proof, **slots}) if proof and slots is not None else {}
    if mach.architecture!='x86_64' or equipment.get('scope')!='var_hastra_equipment_tutorial':return {}
    try:
        npc=actors['npc_initialization']
        if not npc['construction'] or not npc['routes'] or not npc['world_initialization']:return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts,reader=declaration_bytes)
        if not proof:return {}
        values=MAC_VALUES if proof['waypoints']['offset']==origin['offset']+MAC_ALTERNATE['waypoints'][0] else VALUES
        result=copy.deepcopy(values);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'combat_training_encounter_construction',
 'campaign_cursor': 7,
 'mission_kind': 4,
 'station_id': 78,
 'system_id': 15,
 'actor_count': 4,
 'waypoints': [[-4000, -3000, 80000], [10000, 7000, 160000]],
 'authored_route_initial_index': 0,
 'authored_route_loop': False,
 'pirate_count': 3,
 'pirate_actor_kind': 8,
 'pirate_hull_catalogue_id': 2,
 'pirate_waypoint_index': 1,
 'pirate_mode': 5,
 'pirate_active': False,
 'pirate_targeting_blocked': True,
 'companion_actor_id': 3,
 'companion_actor_kind': 3,
 'companion_hull_catalogue_id': 30,
 'companion_position_offset': [700.0, 50.0, 6000.0],
 'companion_friendly': True,
 'companion_current_hull_override': 9999999,
 'companion_name_text_id': 1580,
 'subtype': 0,
 'retains_generated_cargo': True,
 'companion_replaces_generated_route': True,
 'weapon_item_sequence': [0, 19],
 'weapon_effect_sequence': [14600, 14605],
 'companion_weapon_item_sequence': [0, 25],
 'companion_weapon_effect_sequence': [14600, 14606],
 'weapon_effect_capacity': 4,
 'weapon_effect_random_bound': 2,
 'zero_means_flipped': True}

LAYOUTS = {'actor_dispatch': [571,
                    611,
                    '__text',
                    'sha256:c2105f90328838146fbb53084075061a04276b2edc0163ebe4716b8849433861'],
 'waypoints': [1579386,
               24,
               '__const',
               'sha256:e343df0835dbe26be4a8183b1e18c3fe07a892eaeaa99619807d2bf55f348930'],
 'companion_x': [1546006,
                 4,
                 '__const',
                 'sha256:7bfbc6b6592978d852ba691af28fd3a7ee782e1fb7c8623b904546a2f1d6e177'],
 'companion_y': [1557078,
                 4,
                 '__const',
                 'sha256:0c05e73c2748cbfd2e38c0afaf9cb594f78e14fefa3c24190ebc121d45dbee4f'],
 'companion_z': [1575334,
                 4,
                 '__const',
                 'sha256:d51bfdd72a6abbbe822a1288a316bab8713a9b743af5b427746d5639b554cbd4'],
 'route_constructor': [721210,
                       378,
                       '__text',
                       'sha256:23b5dc5ec77e5ada2602dc0ca810786a4068eb8937fe269a96e0b5d3ee52c2f2'],
 'route_wrapper': [721200,
                   10,
                   '__text',
                   'sha256:aafd66af2c321a1032ffdbaea51ef446e7df7cd4b20fe53e4fdf6af362acadb2'],
 'route_copy': [723224,
                472,
                '__text',
                'sha256:2245177e08410aa58bf0468df67d5171131ea6f7f16fb9735efb67b194f1ce04'],
 'route_point': [722434,
                 150,
                 '__text',
                 'sha256:bf8c7a526ff2078ff7f5e79f78e70b9c6cc705d202945070ed511582c0b9fc6f'],
 'route_replace': [-77698,
                   104,
                   '__text',
                   'sha256:9319ae262fb3fa97527e836a13e5db719393ac480dc9070bca8e0fc9b8abc66a'],
 'route_advance': [722824,
                   302,
                   '__text',
                   'sha256:287854a032c7d6e07d73b41c25a02da13ecdea7cda53b1226e452789115a97c8'],
 'friendly': [535652,
              28,
              '__text',
              'sha256:29f61672e56345b7cd33246f9865630c51342b38086156ed5ac59e432e6804c6'],
 'hull_override': [537014,
                   30,
                   '__text',
                   'sha256:801050060c14a0fbdc641193dc1d0fb465b799d0c6c551f2562dc16da0b35bc3'],
 'weapon_effect_0': [1572842,
                     4,
                     '__const',
                     'sha256:2f71717123e07e2e209cc0dc807e9d1e48dd2e9d0cddb9e5238afa837b209770'],
 'weapon_effect_19': [1572918,
                      4,
                      '__const',
                      'sha256:ba68c0bc07a4ca462026f5108537fb3a023f3095f79c0d4c205fde3e86089e80'],
 'weapon_effect_25': [1572942,
                      4,
                      '__const',
                      'sha256:b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720'],
 'factory': [77944,
             3478,
             '__text',
             'sha256:9b9cfd3e564cc131a926a3f0704be2479fa2ee4dcf4c291e129e904aeb57b6cb'],
 'route_and_cargo': [605172,
                     2070,
                     '__text',
                     'sha256:5c736e8f5a1a01fba01080af14930276fe27daf62659649ba266bdc8e28b57e4'],
 'inactive_mode': [-78898,
                   44,
                   '__text',
                   'sha256:3c80e3fd3b5b1084c0783503775d0f75f509fbe6a7f78ac8e2cf86c4a6669b87'],
 'activity': [-78836,
              36,
              '__text',
              'sha256:5a276659e47f2b8a41af0114a37476e4b91b9ae01a809203d0ae1d66eef21136'],
 'activity_field': [540910,
                    14,
                    '__text',
                    'sha256:e592bbf637fe58b32fb61e9aede45c8d603d334bdfeb2c031ba9649201d0a33c'],
 'hostile': [535624,
             28,
             '__text',
             'sha256:b6bfcb7e235910cff0dd3613bb0d4daaad101ddbdbf2166b2708e8a5426891bb'],
 'position_setter': [609228,
                     176,
                     '__text',
                     'sha256:f9f75567832a61860218b92636f68ab668e8cb6beb1f666598fc7c95a5397c25'],
 'world_order': [-44096,
                 2458,
                 '__text',
                 'sha256:8e77d24e7a62a0ebd87fa6aba01be64f590ee82544d83b799c9666e9b551e64a'],
 'weapons': [54772,
             4266,
             '__text',
             'sha256:93395d2357f50de1eae22eb2ec4b6f53cda4499231fe0110d2a04c1bd99c392d'],
 'extra_story': [51826,
                 1046,
                 '__text',
                 'sha256:f9888874fd48b47efc6738660c865a899430cfdd540c30372ca09d04e7a0443a']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'actor_dispatch': [571, 611, '__text', 'sha256:bcfd88a3be0d6af62e71c0b6149e51ed0a2799905125195804766dca3bad21aa'],
 'waypoints': [1554450, 24, '__const', 'sha256:e343df0835dbe26be4a8183b1e18c3fe07a892eaeaa99619807d2bf55f348930'],
 'companion_x': [1520990, 4, '__const', 'sha256:7bfbc6b6592978d852ba691af28fd3a7ee782e1fb7c8623b904546a2f1d6e177'],
 'companion_y': [1532078, 4, '__const', 'sha256:0c05e73c2748cbfd2e38c0afaf9cb594f78e14fefa3c24190ebc121d45dbee4f'],
 'companion_z': [1550398, 4, '__const', 'sha256:d51bfdd72a6abbbe822a1288a316bab8713a9b743af5b427746d5639b554cbd4'],
 'route_constructor': [721834,
                       378,
                       '__text',
                       'sha256:cc56cada952b0004770c13e0885b8afa316f1ee61dde29fcbf6f2b46b8303c83'],
 'route_wrapper': [721824, 10, '__text', 'sha256:aafd66af2c321a1032ffdbaea51ef446e7df7cd4b20fe53e4fdf6af362acadb2'],
 'route_copy': [723848, 472, '__text', 'sha256:5abfccebe5b5415fd1dcc48dbb04fcaef3db77409642d5afc0a6ae34af9badc0'],
 'route_point': [723058, 150, '__text', 'sha256:bf8c7a526ff2078ff7f5e79f78e70b9c6cc705d202945070ed511582c0b9fc6f'],
 'route_replace': [-77698, 104, '__text', 'sha256:7cbfdc0c5acc3bd38d42bf2085e6f9af2d686e827bfeaaafcabb869810df8cb8'],
 'route_advance': [723448, 302, '__text', 'sha256:3f453b905e5352a8bfae989e9b35ef237bc977814aa15b13b6360f0b9c2d1482'],
 'friendly': [536188, 28, '__text', 'sha256:29f61672e56345b7cd33246f9865630c51342b38086156ed5ac59e432e6804c6'],
 'hull_override': [537550, 30, '__text', 'sha256:801050060c14a0fbdc641193dc1d0fb465b799d0c6c551f2562dc16da0b35bc3'],
 'weapon_effect_0': [1547906, 4, '__const', 'sha256:2f71717123e07e2e209cc0dc807e9d1e48dd2e9d0cddb9e5238afa837b209770'],
 'weapon_effect_19': [1547982, 4, '__const', 'sha256:ba68c0bc07a4ca462026f5108537fb3a023f3095f79c0d4c205fde3e86089e80'],
 'weapon_effect_25': [1548006, 4, '__const', 'sha256:b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720'],
 'factory': [77944, 3478, '__text', 'sha256:1edb599619eeabcc4601e757d01307eba28fc1a7bfb5ea74ea86ef4b365fcbf3'],
 'route_and_cargo': [605720, 2070, '__text', 'sha256:9465ec13dc3e42a12689abc652190347dad3912ec48a58a6f9e15f23b769849d'],
 'inactive_mode': [-78898, 44, '__text', 'sha256:c1edf2d38df7afdd0b096f4c3e81bebd3df823b0046c91eb5be9dbd4689af886'],
 'activity': [-78836, 36, '__text', 'sha256:33a6770710bcfe46dd8328b35c5b1aeff975d9f4bae30a88cf99280058772f83'],
 'activity_field': [541446, 14, '__text', 'sha256:e592bbf637fe58b32fb61e9aede45c8d603d334bdfeb2c031ba9649201d0a33c'],
 'hostile': [536160, 28, '__text', 'sha256:b6bfcb7e235910cff0dd3613bb0d4daaad101ddbdbf2166b2708e8a5426891bb'],
 'position_setter': [609776, 176, '__text', 'sha256:d7f595d98dfbf167120727344ec27bdcb00027b44c1345292f575de7c9197330'],
 'world_order': [-44096, 2458, '__text', 'sha256:0cdaa357638444d69604f1f9989b89fcce3e2f2fcd894351d0e3b5e94608f7d6'],
 'weapons': [54772, 4266, '__text', 'sha256:3f2a1241cc0c6a3b727f4b1e1e83eb9328004ecc7ee2d56d85d10163057bf0d3'],
 'extra_story': [51826, 1046, '__text', 'sha256:1335a39e49f4f68f662e67e9c0a9ff1687c9138f7de54ec091cee8875401c351']}
MAC_VALUES = {'scope': 'combat_training_encounter_construction',
 'campaign_cursor': 7,
 'mission_kind': 4,
 'station_id': 78,
 'system_id': 15,
 'actor_count': 4,
 'waypoints': [[-4000, -3000, 80000], [10000, 7000, 160000]],
 'authored_route_initial_index': 0,
 'authored_route_loop': False,
 'pirate_count': 3,
 'pirate_actor_kind': 8,
 'pirate_hull_catalogue_id': 2,
 'pirate_waypoint_index': 1,
 'pirate_mode': 5,
 'pirate_active': False,
 'pirate_targeting_blocked': True,
 'companion_actor_id': 3,
 'companion_actor_kind': 3,
 'companion_hull_catalogue_id': 30,
 'companion_position_offset': [700.0, 50.0, 6000.0],
 'companion_friendly': True,
 'companion_current_hull_override': 9999999,
 'companion_name_text_id': 1588,
 'subtype': 0,
 'retains_generated_cargo': True,
 'companion_replaces_generated_route': True,
 'weapon_item_sequence': [0, 19],
 'weapon_effect_sequence': [14600, 14605],
 'companion_weapon_item_sequence': [0, 25],
 'companion_weapon_effect_sequence': [14600, 14606],
 'weapon_effect_capacity': 4,
 'weapon_effect_random_bound': 2,
 'zero_means_flipped': True}

# Android spans inside named functions and tables; the values are MAC_VALUES.
ANDROID = {# Level::createCampaignMission: the player position sample, the 9999999 hull constant and the
           # dispatch to tbh entry 7; the case builds the route, three sleeping pirates on waypoint 1 and
           # the friendly companion (name 1599), stores the cursor-7 objective and makes the radio.
           'campaign_head': ('_ZN5Level21createCampaignMissionEv', 0, 126, 'sha256:ee2b93b7db435fca79ab22490406898990e60c20ea997a0e0695e842f8c7ce28'),
           'actor_dispatch': ('_ZN5Level21createCampaignMissionEv', 552, 14, 'ddf840a01d2807f2eb80dfe810f0'),
           'actor_entry': ('_ZN5Level21createCampaignMissionEv', 580, 2, '6b30'),
           'actor_case': ('_ZN5Level21createCampaignMissionEv', 25356, 378, 'sha256:957c593ccb135e54d016d4ef808bd44f3ac41b9f0fb0bc50e5ece4a9894a5e15'),
           'companion_offset': ('_ZN5Level21createCampaignMissionEv', 24600, 12, '00002f44000048420080bb45'),
           'defeat_store': ('_ZN5Level21createCampaignMissionEv', 26158, 8, 'caf8285000f0e9be'),
           'story_tail': ('_ZN5Level21createCampaignMissionEv', 29704, 26, 'sha256:51a12ccd37a83d3cc0390e228195c8a57dbd163b8258503299f415cf0179dcea'),
           'waypoints': ('_ZN5Level21createCampaignMissionEv', 25356, 24, '60f0ffff48f4ffff8038010010270000581b000000710200', 'literal', 0),
           # The authored route: index 0, no loop; waypoint 1 for the pirates, a clone for the companion.
           'route_constructor': ('_ZN5RouteC2EPii', 0, 252, 'sha256:ca7150cd62482cc53dbfdf0a65bbe663c975f533f5e0fa5d80515fc638df1c70'),
           'waypoint_constructor': ('_ZN8WaypointC2EiiiP5Route', 0, 212, 'sha256:1c80c1a2eb9571b110121bd0f07d15105a611a1ae48cddc05ac914a6cf7327a2'),
           'route_point': ('_ZN5Route11getWaypointEi', 0, 160, 'sha256:2e1859f50ce2c5863ea686738eaee454bb9897fffa2138de083e0c1f540a03c6'),
           'route_copy': ('_ZN5Route5cloneEv', 0, 348, 'sha256:c628d2ae59c27b4ad6e88c47bbcb48db0ee9fc8e6cc917af36c4ade43200da78'),
           'route_replace': ('_ZN8KIPlayer8setRouteEP5Route', 0, 36, 'sha256:2f00603c48d28f9708289d12f63227139eebaa3ce45e155ddc64e7ddf20197b5'),
           'route_advance': ('_ZN5Route6updateEfff', 0, 260, 'sha256:654bab3aaaa45cebd6ff7ea04b2513f5c041b54e90c912d27f86d5e189b7a19c'),
           # Actor state setters, ship construction, the world order and the NPC weapons and effects.
           'friendly': ('_ZN6Player15setAlwaysFriendEb', 0, 20, '80f8ed104ff48071a0f85c10002180f8e0107047'),
           'hull_override': ('_ZN6Player12setHitpointsEi', 0, 18, '8167d0f884208a42b8bfc0f8841029f115bc'),
           'factory': ('_ZN5Level10createShipEiiiP8Waypointbb', 0, 3112, 'sha256:678eef9996991343994b4360f4e6ce25dc05eb2aab54b3b5f09e665f7f83d91c'),
           'route_and_cargo': ('_ZN13PlayerFighterC2EiiP6PlayerP10AEGeometryfffb', 0, 1668, 'sha256:9722fa1dff717e74e4f5d93a1ee0e2af195659b26021723e8d5632f5ba9eaf91'),
           'inactive_mode': ('_ZN8KIPlayer10setToSleepEv', 0, 28, 'd0b502af04460520c4f8840000216068b8f736eb012084f8ad00d0bd'),
           'activity': ('_ZN8KIPlayer13setInitActiveEb', 0, 20, 'd0b502af04466068b8f72aeb002084f8ae00d0bd'),
           'activity_field': ('_ZN6Player9setActiveEb', 0, 6, '80f8c0107047'),
           'hostile': ('_ZN6Player14setAlwaysEnemyEb', 0, 16, '80f8ec100121a0f85c1080f8e0107047'),
           'position_setter': ('_ZN13PlayerFighter11setPositionEfff', 0, 120, 'sha256:84b11cc073cadac276caa21eb0eef09b9016bb682c15fad91054bd0e74a4dbe8'),
           'world_order': ('_ZN5Level4initEv', 0, 1792, 'sha256:fceec130c720743b341b16f0e8ce63d43a1382808e075533d391370c9949a244'),
           'weapons': ('_ZN5Level10assignGunsEv', 0, 3320, 'sha256:2d4c9a0a16410a8459ff79a6c70158b826a10813a8dee82ee37fe387abbcec55'),
           'weapon_effect': ('_ZN3Gun8setIndexEi', 0, 280, 'sha256:49874dec0a3b669f6555df7804296846b7a92559002168440a630d4b0ea50c92'),
           # Items 0..25 of the effect model table: 14600 for item 0, 14605 for 19, 14606 for 25.
           'weapon_effects': ('_ZN3Gun8setIndexEi', 56, 104, '08390000083900000839000009390000093900000a3900000a3900000b3900000b390000083900000b3900000a390000093900000939000009390000093900000c3900000c3900000c3900000d3900000d3900000d3900000e3900000e3900000e3900000e390000', 'literal', 0)}
# The companion's setPosition(float, float, float) call reads slot 18 of PlayerFighter's vtable.
ANDROID_VTABLES = {'placement_virtual': ('_ZTV13PlayerFighter', 18, ['_ZN13PlayerFighter11setPositionEfff'])}
