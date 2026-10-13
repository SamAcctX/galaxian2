"""Optional Mac ordinary weapon model mappings for the training encounter.

Android: Level::createGun gives the player's item 0 (20 shots) and item 22
(25 shots, kind 2) their projectile models 6754 and 6798 from its model table
and Level::assignGuns the NPC items 19 and 25 their models 6795 and 6802;
Gun::setIndex takes each item's impact model from its table (14600, 14605,
14606, 14606) and stores random flips that no Gun or ObjectGun function
reads. Gun::shootAt captures the firing matrix's up vector
(AEMath::MatrixGetUp) into the gun, and ObjectGun::render orients player
shots (Gun::isPlayerGun) by it. Values equal the Mac ones.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes


def extract_combat_training_visuals(mach, arrival, weapons, staging):
    if mach.architecture == 'android-armv7':
        try:
            if weapons['scope'] != 'combat_training_ordinary_weapons': return {}
            if not staging['projectile_visuals'] or not staging['projectile_impacts']: return {}
        except (KeyError, TypeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(copy.deepcopy(VALUES), provenance=proof) if proof else {}
    if mach.architecture != 'x86_64':
        return {}
    try:
        if weapons.get('scope') != 'combat_training_ordinary_weapons':
            return {}
        if not staging['projectile_visuals'] or not staging['projectile_impacts']:
            return {}
        if mach.architecture!='x86_64':return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],'sha256:'+v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts,reader=declaration_bytes)
        if not proof:return {}
        values=VALUES
        result=copy.deepcopy(values);result['provenance']=proof
        return result
    except (KeyError, TypeError, ValueError, IndexError, OverflowError):
        return {}


VALUES = {'scope': 'combat_training_ordinary_visuals',
 'campaign_cursor': 7,
 'weapons': [{'owner': 'player',
              'actor_ids': [],
              'item_id': 0,
              'kind': 0,
              'capacity': 20,
              'projectile_model_id': 6754,
              'projectile_resource': 'resources/data/assets/main/3d/meshes/fx/projectile_000_anim_add.aem',
              'impact_model_id': 14600,
              'impact_resource': 'resources/data/assets/main/3d/meshes/fx/impact_000_lookat_anim_add.aem'},
             {'owner': 'player',
              'actor_ids': [],
              'item_id': 22,
              'kind': 2,
              'capacity': 25,
              'projectile_model_id': 6798,
              'projectile_resource': 'resources/data/assets/main/3d/meshes/fx/projectile_022_anim_add.aem',
              'impact_model_id': 14606,
              'impact_resource': 'resources/data/assets/main/3d/meshes/fx/impact_006_lookat_anim_add.aem'},
             {'owner': 'npc',
              'actor_ids': [0, 1, 2],
              'item_id': 19,
              'kind': 1,
              'capacity': 4,
              'projectile_model_id': 6795,
              'projectile_resource': 'resources/data/assets/main/3d/meshes/fx/projectile_019_anim_add.aem',
              'impact_model_id': 14605,
              'impact_resource': 'resources/data/assets/main/3d/meshes/fx/impact_005_lookat_anim_add.aem'},
             {'owner': 'npc',
              'actor_ids': [3],
              'item_id': 25,
              'kind': 0,
              'capacity': 4,
              'projectile_model_id': 6802,
              'projectile_resource': 'resources/data/assets/main/3d/meshes/fx/projectile_026_anim_add.aem',
              'impact_model_id': 14606,
              'impact_resource': 'resources/data/assets/main/3d/meshes/fx/impact_006_lookat_anim_add.aem'}],
 'player_effect_setup_before_field_seed': True,
 'player_impact_assignments': 1,
 'impact_random_flip_used': False}

LAYOUTS = {'wrapper_default': [475185,
                     6,
                     '__text',
                     'f14ae3be6b76e78dd58bc5fa7949d2e1b7bc01db4e86f1d085cb21464a2e0270'],
 'captured_up_draw': [479454,
                      55,
                      '__text',
                      '133471d491c02b536b4bfc5795c3e4f93144d323ac7da78f8d750cfd9bcbeca7'],
 'captured_up_launch': [-186411,
                        59,
                        '__text',
                        '07c737c5bb22c816baabe42ff63b156d8c52706fc79e3f0b8c205cecb7c86168'],
 'matrix_up': [1241222,
               15,
               '__text',
               'b786e38224ecb3139b2bf7e734bd7d0048ca7a64bd68e95f64e3ccc055bafb9d'],
 'player_flag': [-187812,
                 14,
                 '__text',
                 '84a110a2d5d1a9f1e1342afe8dd9c22d4961fd8e1b386c8a096d305d27472d47'],
 'impact_0': [1572842,
              4,
              '__const',
              '2f71717123e07e2e209cc0dc807e9d1e48dd2e9d0cddb9e5238afa837b209770'],
 'impact_19': [1572918,
               4,
               '__const',
               'ba68c0bc07a4ca462026f5108537fb3a023f3095f79c0d4c205fde3e86089e80'],
 'impact_22': [1572930,
               4,
               '__const',
               'b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720'],
 'impact_25': [1572942,
               4,
               '__const',
               'b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720'],
 'projectile_0': [1576458,
                  4,
                  '__const',
                  '36984f0f9871e85edea08d3492809d05459229f43a3e948d05df70451e7ad6b3'],
 'projectile_22': [1576546,
                   4,
                   '__const',
                   'e7a31085b22247cc08bcdbd23fb51854506464a75e14e65185a301f27b7e704b']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'wrapper_default': [475711, 6, '__text', 'f14ae3be6b76e78dd58bc5fa7949d2e1b7bc01db4e86f1d085cb21464a2e0270'],
 'captured_up_draw': [479980, 55, '__text', '0e2746c9660d0b41543e0b66026a8524c7455bfdc9fa6f9b91742a5eef5b98b0'],
 'captured_up_launch': [-186903, 59, '__text', 'ad4b0687c921df40a0dcb47d104ee5f08120fb67611f2d303b5e354111de8595'],
 'matrix_up': [1234014, 15, '__text', 'b786e38224ecb3139b2bf7e734bd7d0048ca7a64bd68e95f64e3ccc055bafb9d'],
 'player_flag': [-188304, 14, '__text', '84a110a2d5d1a9f1e1342afe8dd9c22d4961fd8e1b386c8a096d305d27472d47'],
 'impact_0': [1547906, 4, '__const', '2f71717123e07e2e209cc0dc807e9d1e48dd2e9d0cddb9e5238afa837b209770'],
 'impact_19': [1547982, 4, '__const', 'ba68c0bc07a4ca462026f5108537fb3a023f3095f79c0d4c205fde3e86089e80'],
 'impact_22': [1547994, 4, '__const', 'b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720'],
 'impact_25': [1548006, 4, '__const', 'b18cc146d20e56ff0808059bc8ddf272dc008ee143402c5d32424175d3b54720'],
 'projectile_0': [1551522, 4, '__const', '36984f0f9871e85edea08d3492809d05459229f43a3e948d05df70451e7ad6b3'],
 'projectile_22': [1551610, 4, '__const', 'e7a31085b22247cc08bcdbd23fb51854506464a75e14e65185a301f27b7e704b']}

# Android spans inside named functions and tables; the values are VALUES.
ANDROID = {# ObjectGun's constructor, the player-shot orientation in ObjectGun::render and the captured up vector.
           'wrapper_default': ('_ZN9ObjectGunC2EiP3GunijP5Level', 0, 604, 'sha256:059e8672e3ec017b0c0f36b8ed8037e25955fe837a1c21003b4adc5f3e19a17a'),
           'captured_up_draw': ('_ZN9ObjectGun6renderEv', 390, 52, 'sha256:7d29186e425ad07217e83187fec219544fe4bf8bf9cf085852c6cf7891136293'),
           'captured_up_launch': ('_ZN3Gun7shootAtEN11AbyssEngine6AEMath6MatrixEiP6Playerb', 1362, 36, 'sha256:cd7086d3779cb2115314d0d5d3e96a0a78d8177ca285514118aa93cbe47231ae'),
           'matrix_up': ('_ZN11AbyssEngine6AEMath11MatrixGetUpERKNS0_6MatrixE', 0, 14, '4b694a68496ac0e9002381607047'),
           'player_flag': ('_ZN3Gun11isPlayerGunEv', 0, 6, '90f8f0007047'),
           'player_flag_setter': ('_ZN3Gun12setPlayerGunEb', 0, 6, '80f8f0107047'),
           # Impact models of items 0..25 (Gun::setIndex), projectile models of player items 0..22
           # (Level::createGun) and the NPC guns (Level::assignGuns).
           'impact_setter': ('_ZN3Gun8setIndexEi', 0, 280, 'sha256:49874dec0a3b669f6555df7804296846b7a92559002168440a630d4b0ea50c92'),
           'impact_models': ('_ZN3Gun8setIndexEi', 56, 104, '08390000083900000839000009390000093900000a3900000a3900000b3900000b390000083900000b3900000a390000093900000939000009390000093900000c3900000c3900000c3900000d3900000d3900000d3900000e3900000e3900000e3900000e390000', 'literal', 0),
           'player_weapons': ('_ZN5Level9createGunEiiiiiiii', 0, 2100, 'sha256:691b3d3ecddf9ec499430d2b11da8537cab23a29b68e956ba56b89932ba009ad'),
           'projectile_models': ('_ZN5Level9createGunEiiiiiiii', 118, 92, '621a0000631a0000641a0000681a0000691a00006a1a00006b1a00006c1a00006d1a0000ffffffffffffffffffffffff841a0000851a0000861a0000871a0000881a0000891a00008a1a00008b1a00008c1a00008d1a00008e1a0000', 'literal', 0),
           'npc_weapons': ('_ZN5Level10assignGunsEv', 0, 3320, 'sha256:2d4c9a0a16410a8459ff79a6c70158b826a10813a8dee82ee37fe387abbcec55')}
