"""Optional Mac training weapon/player constants. Static import, no code output.

Android: Level::assignGuns builds each NPC's 4-shot Gun (3000 ms, interval
600 - 2 x cursor, speed 16) with item 0, then item 19 (kind 1, projectile
6795) for kind 8 and item 25 (kind 0, projectile 6802) for kind 3; for
cursor 7 it then halves the damage of every kind-8 actor (vmul by 0.5,
truncated: 3 -> 1), which the Mac 1.0.7 Level::assignGuns does not do.
Gun::Gun, setIndex, setFriendGun, setLevel, setErrorMagnitudePercentage,
setOffset, shootAt (0.01 and 0.005 dispersion), update and
calcCharacterCollision, Player::damage, Level::createPlayer and createGun
(item 22: kind 2, 25 shots, dispersion 2), ModStation::OnTouchEnd (the four
-1 resets before the launch), MGame::OnInitialize (Level(3) then
Level::init), Status::departStation and ModStation::leaveStation hold the
rest; those values equal the Mac ones.

Android-only mercy rule (ANDROID_VALUES 'mercy'): when the player dies in a
campaign mission (MGame::gameOverCheck: Status::getMission,
Mission::isCampaignMission, Status::getCurrentCampaignMission), the
Globals::lastCampaignMissionFailCount grows for the same cursor
(Globals::lastCampaignMissionFailed) and restarts at 1 for another; MGame::OnUpdate
stops calling gameOverCheck once failed, so each death counts once. The
Globals are never saved. Level::assignGuns then multiplies every enemy
(KIPlayer::isEnemy) gun's damage by 0.7f, truncated, in that campaign mission
once its count reaches 3. The Mac assignGuns has no such rule.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes

def extract_combat_training_weapons(mach,arrival,training,control,equipment,actors,weapons):
    if mach.architecture == 'android-armv7':
        try:
            if training['scope'] != 'combat_training_encounter_construction' or control['scope'] != 'combat_training_live_control' or equipment['scope'] != 'var_hastra_equipment_tutorial': return {}
            player = actors['player_initialization']
            if not player['flight_cache'] or not player['repair']: return {}
            if not all(weapons.get(k) for k in ['ordinary_hit_policy', 'player_hit_policy', 'collision_bounds', 'audio']): return {}
        except (KeyError, TypeError, AttributeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(ANDROID_VALUES), provenance=proof) if proof else {}
    if mach.architecture!='x86_64':return {}
    try:
        if training.get('scope')!='combat_training_encounter_construction' or control.get('scope')!='combat_training_live_control' or equipment.get('scope')!='var_hastra_equipment_tutorial':return {}
        if not actors['player_initialization']['flight_cache'] or not actors['player_initialization']['repair']:return {}
        if not weapons['ordinary_hit_policy'] or not weapons['player_hit_policy'] or not weapons['collision_bounds'] or not weapons['audio']:return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts,reader=declaration_bytes)
        if not proof:return {}
        values=VALUES
        result=copy.deepcopy(values);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'combat_training_ordinary_weapons',
 'campaign_cursor': 7,
 'actor_count': 4,
 'rank_min': 0,
 'rank_max': 1,
 'npc_weapons': [{'actor_id': 0,
                  'actor_kind': 8,
                  'hull_catalogue_id': 2,
                  'item_id': 19,
                  'category': 0,
                  'kind': 1,
                  'catalogue_kind': 1,
                  'damage': 3,
                  'interval_ms': 586,
                  'lifetime_ms': 3000,
                  'projectile_capacity': 4,
                  'speed_units_per_millisecond': 16.0,
                  'model_resource_id': 6795,
                  'nonplayer_source': True},
                 {'actor_id': 1,
                  'actor_kind': 8,
                  'hull_catalogue_id': 2,
                  'item_id': 19,
                  'category': 0,
                  'kind': 1,
                  'catalogue_kind': 1,
                  'damage': 3,
                  'interval_ms': 586,
                  'lifetime_ms': 3000,
                  'projectile_capacity': 4,
                  'speed_units_per_millisecond': 16.0,
                  'model_resource_id': 6795,
                  'nonplayer_source': True},
                 {'actor_id': 2,
                  'actor_kind': 8,
                  'hull_catalogue_id': 2,
                  'item_id': 19,
                  'category': 0,
                  'kind': 1,
                  'catalogue_kind': 1,
                  'damage': 3,
                  'interval_ms': 586,
                  'lifetime_ms': 3000,
                  'projectile_capacity': 4,
                  'speed_units_per_millisecond': 16.0,
                  'model_resource_id': 6795,
                  'nonplayer_source': True},
                 {'actor_id': 3,
                  'actor_kind': 3,
                  'hull_catalogue_id': 30,
                  'item_id': 25,
                  'category': 0,
                  'kind': 0,
                  'catalogue_kind': 2,
                  'damage': 3,
                  'interval_ms': 586,
                  'lifetime_ms': 3000,
                  'projectile_capacity': 4,
                  'speed_units_per_millisecond': 16.0,
                  'model_resource_id': 6802,
                  'nonplayer_source': True}],
 'target_memberships': [[-1, 3], [-1, 3], [-1, 3], [-1, 0, 1, 2]],
 'player_weapon_targets': [0, 1, 2, 3],
 'player_primary': {'item_id': 22,
                    'category': 0,
                    'kind': 2,
                    'projectile_capacity': 25,
                    'dispersion': {'steps': 2,
                                   'draw_scale': 0.01,
                                   'center_scale': 0.005}},
 'player_entry': {'ship_id': 0,
                  'station_id': 78,
                  'system_id': 15,
                  'campaign_cursor': 7,
                  'cache_reset': -1}}

LAYOUTS = {'npc_setup': [54772,
               4266,
               '__text',
               'sha256:93395d2357f50de1eae22eb2ec4b6f53cda4499231fe0110d2a04c1bd99c392d'],
 'weapon_constructor': [-190034,
                        1052,
                        '__text',
                        'sha256:4b0208493df049fbb0bfd01ecc5256fb626a03224588905359578b21399d347d'],
 'item_setter': [-188700,
                 356,
                 '__text',
                 'sha256:8b5b5b6b765bdeb35578f046abcf75ea7a163d82b6774058e073c3e40441f47a'],
 'nonplayer_setter': [-188326,
                      14,
                      '__text',
                      'sha256:56fb4708b51db8473a556671ad05fbcb6e5acda136b1ffc4b9cc745236913c8c'],
 'world_setter': [-187836,
                  10,
                  '__text',
                  'sha256:f32fa1facba93f311868735c6e7da4d4bde6742a6e26f5f9fe021d3dc995180c'],
 'spread_setter': [-188344,
                   18,
                   '__text',
                   'sha256:927d86e6419e8a53a0c3181171b9e9f0eb58f50971e7b894006e09cb6bcbe20b'],
 'mount_setter': [-188274,
                  68,
                  '__text',
                  'sha256:270cb597672058226a3133fd9217be3d1d47d2e391140f6dc1accbf130ca1070'],
 'ordinary_launch': [-187798,
                     3176,
                     '__text',
                     'sha256:4093e51968f4cc297bf8a653364794cbf4ddc8cf1dc3b522ac48781c623fee2a'],
 'ordinary_update': [-180366,
                     710,
                     '__text',
                     'sha256:d63dda0ec09085ad9a3f0d2866c2ccb34e595001cca0122704439d56bd89da8e'],
 'contacts': [-183076,
              2704,
              '__text',
              'sha256:426bbdd5daf4550adeb6d19eb5aa1ee7692b5f8a59e5de2993f50b3af7b0cfa6'],
 'normal_damage': [538936,
                   1846,
                   '__text',
                   'sha256:bf43e8c8d5ea3461a0c97d0794cf51c69df8f95220efcaf59786d0042e357778'],
 'player_factory': [-37352,
                    2046,
                    '__text',
                    'sha256:b45e401d2205817ae7597b446766e24a6435180298013ba7971b93be3b674b8c'],
 'weapon_factory': [64358,
                    2880,
                    '__text',
                    'sha256:ff92dfcf6d3002f4d02a862b2336d0e5a6db851832300c2b4d67814665746d82'],
 'cache_reset_and_state': [431888,
                           113,
                           '__text',
                           'sha256:b98a7ba01bfaa5d3bfb5afcc0f1a8d6afc01ca8364c6205aebb5046feadc4c3f'],
 'world_entry': [335220,
                 77,
                 '__text',
                 'sha256:57eb5999c4ff87defda4e0e74db9a1ee1737eccd2b19449db323920ce5543330'],
 'refresh_equipment': [857965,
                       93,
                       '__text',
                       'sha256:15e8304f44d7e374ede651a47b8b3059fbb75ca4c9cadf129afb7715e0f99bb3'],
 'equipment_departure_gate': [437089,
                              263,
                              '__text',
                              'sha256:d4de87be7cda1f8c669f5bcc709c6cf560d3be5b80bfe5398faa64cf62b0fdf2'],
 'player_mount_assignment': [-35754,
                             56,
                             '__text',
                             'sha256:d2516c36eda67ceecdf1eabedce62c4769f07f725f3a8d83b36a5bafd71cd6d4'],
 'weapon_dispatch': [67166,
                     12,
                     '__text',
                     'sha256:da0539709d33338afecfe1a11fff68db652d01c4439e15d1cf11db2053ae1eb5'],
 'npc_dispatch': [58994,
                  36,
                  '__text',
                  'sha256:fc5b001250e8975b3c3e1f02e89ac3c7424ae54434e597ed02569bd596679033'],
 'spread_scale': [1556914,
                  4,
                  '__const',
                  'sha256:0d66bd808e9247acb560fe33efaa62ad6f11ee6f85cc4f61bd17673263de04ee'],
 'spread_center': [1572190,
                   4,
                   '__const',
                   'sha256:1229f28c7e699bf60a4b44363dcb39610e8b7206037302d7f69ba6f80d4009e7'],
 'npc_speed': [1575350,
               4,
               '__const',
               'sha256:140efb356462f70dd1c7f1dfb10bcc07d0f14d439043fb9e9d50f4d7be71ea96']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'npc_setup': [54772, 4266, '__text', 'sha256:3f2a1241cc0c6a3b727f4b1e1e83eb9328004ecc7ee2d56d85d10163057bf0d3'],
 'weapon_constructor': [-190526,
                        1052,
                        '__text',
                        'sha256:0d46de6f95e493fc2a0c353d0f33e25cad4e4678ebd72dfa35b1c7a38d05dea5'],
 'item_setter': [-189192, 356, '__text', 'sha256:549578b4a8d139aeb21819c03e2a69130554ad105eb89faf7d11210f35c6a92b'],
 'nonplayer_setter': [-188818, 14, '__text', 'sha256:56fb4708b51db8473a556671ad05fbcb6e5acda136b1ffc4b9cc745236913c8c'],
 'world_setter': [-188328, 10, '__text', 'sha256:f32fa1facba93f311868735c6e7da4d4bde6742a6e26f5f9fe021d3dc995180c'],
 'spread_setter': [-188836, 18, '__text', 'sha256:927d86e6419e8a53a0c3181171b9e9f0eb58f50971e7b894006e09cb6bcbe20b'],
 'mount_setter': [-188766, 68, '__text', 'sha256:6a30a310d28ea8b642197c73d046d099b73f48f66729b1e9bfbebfb0048e5788'],
 'ordinary_launch': [-188290,
                     3176,
                     '__text',
                     'sha256:9411e1de70cd54d11251e4f8650dc7128912700b0665aee0ec503048acb485e3'],
 'ordinary_update': [-180858, 710, '__text', 'sha256:e591e7e82ceadf82cba3504357a15d97d1d3950db93ab413642a69444cf5cfd9'],
 'contacts': [-183568, 2704, '__text', 'sha256:95db4cd298c721650cdb2404b89369161f9ff093fb25dbcaee789e1548a72c3e'],
 'normal_damage': [539472, 1846, '__text', 'sha256:407b208cd78b7b7e70b5bc505bc9509f70781ad9d1af9c2b9a9f80104cd54242'],
 'player_factory': [-37352, 2046, '__text', 'sha256:336ea8b85ccab161993f9d90974fb994f051e0f742847246a42534557ce31a95'],
 'weapon_factory': [64358, 2880, '__text', 'sha256:6fe1557f355730ee3310898ecb965bce0b67fae080d269c760ca1466d0e17dc7'],
 'cache_reset_and_state': [432316,
                           113,
                           '__text',
                           'sha256:f3de56aa4b643ba9b5cc37a3c2b5291426a189229a16fe58370da10741fcf5f0'],
 'world_entry': [334920, 77, '__text', 'sha256:4b4d616ea9b0dc66d5e9277035f0f0f48c2b15df901a53b334f963501de6f179'],
 'refresh_equipment': [858597, 93, '__text', 'sha256:ca675b06817328cdf2ff0e5a751b2abe9f12a033d6c832890c88b0038c6cbb00'],
 'equipment_departure_gate': [437523,
                              262,
                              '__text',
                              'sha256:7f09346020c2ed731652b3e520d8c7d98ed3126c1e6cb4659b123862910b8a32'],
 'player_mount_assignment': [-35754,
                             56,
                             '__text',
                             'sha256:c047bd09340ad1ed822891b8be6e668aa7f53dcc17626e4a99d95e1a2cd48f36'],
 'weapon_dispatch': [67166, 12, '__text', 'sha256:da0539709d33338afecfe1a11fff68db652d01c4439e15d1cf11db2053ae1eb5'],
 'npc_dispatch': [58994, 36, '__text', 'sha256:fc5b001250e8975b3c3e1f02e89ac3c7424ae54434e597ed02569bd596679033'],
 'spread_scale': [1531914, 4, '__const', 'sha256:0d66bd808e9247acb560fe33efaa62ad6f11ee6f85cc4f61bd17673263de04ee'],
 'spread_center': [1547254, 4, '__const', 'sha256:1229f28c7e699bf60a4b44363dcb39610e8b7206037302d7f69ba6f80d4009e7'],
 'npc_speed': [1550414, 4, '__const', 'sha256:140efb356462f70dd1c7f1dfb10bcc07d0f14d439043fb9e9d50f4d7be71ea96']}

# Android: Level::assignGuns halves the kind-8 damage for cursor 7 (3 -> 1); the rest equals VALUES.
ANDROID_VALUES = copy.deepcopy(VALUES)
for _row in ANDROID_VALUES['npc_weapons']:
    if _row['actor_kind'] == 8: _row['damage'] = 1
del _row
# Android: three deaths in a row in the same campaign mission weaken its enemy guns (0.7f).
ANDROID_VALUES['mercy'] = {'minimum_failures': 3, 'damage_factor': 0.699999988079071}
# Android spans inside named functions.
ANDROID = {# Level::assignGuns: the NPC guns; s24 = 0.5 and, for cursor 7 and kind 8, damage = trunc(damage x s24).
           'npc_setup': ('_ZN5Level10assignGunsEv', 0, 3320, 'sha256:2d4c9a0a16410a8459ff79a6c70158b826a10813a8dee82ee37fe387abbcec55'),
           'training_damage_scale': ('_ZN5Level10assignGunsEv', 480, 4, 'b6ee00ca'),
           'training_damage_cursor': ('_ZN5Level10assignGunsEv', 1898, 8, 'b8f1070f11d0b8f1'),
           'training_damage': ('_ZN5Level10assignGunsEv', 1940, 36, 'daf8f800406850f82900406a082809d195ed180ab8eec00a20ee0c0abdeec00a85ed180a'),
           # The mercy rule: s26 = 0.7f; a campaign mission at the last failed cursor with 3+ failures
           # scales every enemy gun (KIPlayer::isEnemy, Mission::isCampaignMission).
           'mercy_factor_load': ('_ZN5Level10assignGunsEv', 518, 4, '9fed71da'),
           'mercy_factor': ('_ZN5Level10assignGunsEv', 972, 4, '3333333f'),
           'mercy_damage': ('_ZN5Level10assignGunsEv', 1976, 94, 'sha256:35ad18a89b642433ddd2d19c5051ac45b689d440ec4687405d7fbff50a819672'),
           'mercy_failures': ('_ZN5Level10assignGunsEv', 2024, 8, '0c980068032859db'),
           'mercy_enemy': ('_ZN8KIPlayer7isEnemyEv', 0, 8, '406890f85c007047'),
           'mercy_campaign': ('_ZN7Mission17isCampaignMissionEv', 0, 10, '006d002818bf01207047'),
           # MGame::gameOverCheck counts a campaign death; MGame::OnUpdate calls it only until failure.
           'mercy_count': ('_ZN5MGame13gameOverCheckEv', 178, 102, 'sha256:b120529f36969de109f70079a0da86b701cd760b3b6fa9713880e11647583c8b'),
           'mercy_once': ('_ZN5MGame8OnUpdateEv', 10572, 86, 'sha256:d32ffc72ac1874d2159af3abb568f0d683c41ad513b1795ca0c0b91e2124f4e0'),
           # The Gun: construction, items and effects, NPC flag, world, dispersion, mount, launch, update, contacts.
           'weapon_constructor': ('_ZN3GunC2EiiiiiifN11AbyssEngine6AEMath6VectorES2_', 0, 688, 'sha256:f137885ac07db5356a568ef2dcae645ad787e5602551a8faa0c3dd568a1a5a91'),
           'item_setter': ('_ZN3Gun8setIndexEi', 0, 280, 'sha256:49874dec0a3b669f6555df7804296846b7a92559002168440a630d4b0ea50c92'),
           'nonplayer_setter': ('_ZN3Gun12setFriendGunEb', 0, 6, '80f8f9107047'),
           'world_setter': ('_ZN3Gun8setLevelEP5Level', 0, 4, '81637047'),
           'spread_setter': ('_ZN3Gun27setErrorMagnitudePercentageEi', 0, 14, '00ee101ab8eec00a80ed3f0a7047'),
           'mount_setter': ('_ZN3Gun9setOffsetEPN11AbyssEngine6AEMath6VectorE', 0, 84, 'sha256:4d88afe3773e0d53e623f4d1a1e61c2541282f57da9f9d062aeb89914f9a617b'),
           'ordinary_launch': ('_ZN3Gun7shootAtEN11AbyssEngine6AEMath6MatrixEiP6Playerb', 0, 1948, 'sha256:dd968f45f46de04659309714d596219f1a8c6c80feef2681d3edbd6b4cd876a8'),
           'ordinary_update': ('_ZN3Gun6updateEi', 0, 604, 'sha256:d6a8465662a76ab2f115107bb4e59dde8ea426f6b7a7a089e290bd18a80bb89a'),
           'contacts': ('_ZN3Gun22calcCharacterCollisionEv', 0, 2024, 'sha256:ee0110d3a7495e15d266903440f69f9b21dd2a6b23b30b4a5aafb5e4720eab9b'),
           'normal_damage': ('_ZN6Player6damageEibi', 0, 1376, 'sha256:577391dd7b7a6d8ee3273ce37004ea80f21a4f1a173666529c7b926f4449f3d5'),
           # The player's ship and its item-22 primary (Level::createGun case 2: 25 shots, magnitude 2).
           'player_factory': ('_ZN5Level12createPlayerEv', 0, 1488, 'sha256:fcebfffd4a09af510bb44e49a29a70dc4a92646389ce309a513a0ea03c36206b'),
           'weapon_factory': ('_ZN5Level9createGunEiiiiiiii', 0, 2100, 'sha256:691b3d3ecddf9ec499430d2b11da8537cab23a29b68e956ba56b89932ba009ad'),
           # The equipped launch from station 78: the -1 resets, Level(3) and Level::init, the departure.
           'cache_reset_and_state': ('_ZN10ModStation10OnTouchEndEiiPv', 0, 6536, 'sha256:5b29b2bf44b1e0a442eb14b5646a1aad12932fedee58112b028e31589316b50e'),
           'world_entry': ('_ZN5MGame12OnInitializeEv', 618, 52, 'sha256:29a43ac587e4269dfd9e685bfc6e36378806eb8285f8c54190ce64ba5b634ab4'),
           'refresh_equipment': ('_ZN6Status13departStationEP7Station', 0, 1072, 'sha256:b7432b338855a0a259aa2b3d0d678bb305ea5293e9903e68114efafe3b6170d6'),
           'equipment_departure_gate': ('_ZN10ModStation12leaveStationEv', 0, 684, 'sha256:312550b1ddc5c8aaf2d57ee470e9d8eb501690835f2699e068ebed55c62b4120')}
