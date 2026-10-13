"""Optional Mac mission placement declarations, without executable runtime code.

Android: LevelScript::process places the cursor-4 pirate once at cursor 5 at
the player + (5000, 0, 30000), turned by pi, and wakes it through slots 18
(PlayerFighter::setPosition) and 3 (PlayerFighter::awake) of PlayerFighter's
vtable; slot 2 (PlayerFighter::setShipGroup -> KIPlayer::setShipGroup) banks
its model under the flight geometry.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes, vtable_proof

def extract_full_hold_appearance(mach,arrival,story,death):
    if mach.architecture == 'android-armv7':
        try:
            if story['scope'] != 'full_hold_mining_story' or death['scope'] != 'full_hold_pirate_destruction': return {}
        except (KeyError, TypeError): return {}
        proof, slots = recognize_symbols(mach, ANDROID), vtable_proof(mach, ANDROID_VTABLES)
        return dict(VALUES, provenance={**proof, **slots}) if proof and slots is not None else {}
    if mach.architecture!='x86_64':return {}
    try:
        if story['scope']!='full_hold_mining_story' or death['scope']!='full_hold_pirate_destruction':return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts,reader=declaration_bytes)
        if not proof:return {}
        values=VALUES
        result=copy.deepcopy(values);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'full_hold_pirate_appearance',
 'campaign_cursor': 4,
 'trigger_cursor': 5,
 'actor_id': 0,
 'actor_kind': 8,
 'hull_catalogue_id': 2,
 'subtype': 0,
 'once_per_flight': True,
 'offset': [5000, 0, 30000],
 'offset_space': 'world',
 'yaw_radians': 3.1415927410125732,
 'actor_mode': 1,
 'active': True,
 'model_draw_enabled': True,
 'node_draw_requested': True,
 'bank_child': True,
 'statistics_before_yaw': True,
 'preserve_hull': True,
 'preserve_cargo': True,
 'preserve_guidance': True,
 'preserve_bank_history': True,
 'preserve_effect_clocks': True,
 'preserve_cleanup_clock': True,
 'dead_actor_reenters_death': True,
 'repeat_death_counters': True}

LAYOUTS = {'mission_controller': [138688,
                        93478,
                        '__text',
                        'sha256:7d5903c3306c9e77eda72db8f17ae7b1b91b9dac866c4610cab470406bf7cd5e'],
 'activation': [630538,
                82,
                '__text',
                '554889e553504889fbc783bc00000001000000488b7b08be01000000e8c3a1feff4889dfbe01000000e8eaaeffffc6834101000001488b7b184885ff7504488b7b10be010000004883c4085b5de9805aebff'],
 'placement': [609228,
               176,
               '__text',
               '554889e54156534883ec20f30f1155d4f30f114dd8f30f1145dc4889fbf30f118380000000f30f118b84000000f30f119388000000488b7b10e894a7ebff4c8db3c0010000488d75e0f30f1045dcf30f1145e0f30f1045d8f30f1145e4f30f1045d4f30f1145e84c89f7e86fda0600488bbbb80100004885ff7410f3410f104e08f3410f7e06e8cdc704004c8b7308488b7b10e8b0a6ebff4983c6084c89f74889c6e8879609004883c4205b415e5dc3'],
 'visibility': [609826,
                78,
                '__text',
                '554889e5535089f3488b47104885c07436488b4f184885c974288b711c83feff7425488d0547ed1b00488b38e8377c08000fb6f34889c74883c4085b5de926ad07008b701cebd64883c4085b5dc3'],
 'model_install': [-79336,
                   272,
                   '__text',
                   '554889e54156534889fb8993b00000004885f6746980f10184c97562488973184c8b73104d85f67527bfe8000000e8e1b718004989c6488d053d712600488b304c89f7e88a25f6ff4c897310488b73188b76144c89f7e87927f6ff488b4b10488b43188b491489482ceb384889c34c89f7e892b718004889dfe8c6b71800488973104c8b73184d85f674104c89f7e8ad26f6ff4c89f7e86db7180048c7431800000000f30f109388000000f30f108b84000000f30f108380000000488b7b10e8c228f6ff4c8b7308488b7b10e82b28f6ff4983c6084c89f74889c6e802181400488b7b184885ff750a5b415e5dc3e978ffffff488b5b084883c308e8fc27f6ff4889df4889c65b415e5de9c318140090'],
 'actor_factory': [77944,
                   3478,
                   '__text',
                   'sha256:9b9cfd3e564cc131a926a3f0704be2479fa2ee4dcf4c291e129e904aeb57b6cb'],
 'matrix_setter': [-724186, 24, '__text', '554889e54889f08b7714488b7f384889c25de95dcf1c0090'],
 'position_setter': [-724066,
                     68,
                     '__text',
                     '554889e54883ec50f30f1155bcf30f114db8f30f1145b48b7714488b7f38e8f9d01c00488d7dc04889c6f30f1045b4f30f104db8f30f1055bce81e101e004883c4505dc3'],
 'euler_addition': [-723090,
                    140,
                    '__text',
                    '554889e5534881ec880000004889fbf30f584340f30f114340f30f584b44f30f114b44f30f585348f30f1153488b7314488b7b38e813cd1c00488d7db88b535cf30f105348f30f104340f30f104b444889c6e8e5ff1d008b7314488b7b38e8e9cc1c00488dbd78fffffff30f105354f30f10434cf30f104b504889c6e8ab0a1e004881c4880000005b5dc390'],
 'effect_trigger': [-681366,
                    484,
                    '__text',
                    '554889e54157415641554154534883ec784989d74989f64989fc498b7c2408e8be58ffff488d05fda02f00488b38498b4424088b7014e8e52f1c00c6800d01000001498b4424088b701c83feff7416488d05d2a02f00488b38e8c22f1c00c6800d01000001498b7c24104885ff74264c89f6e86b58ffff488d05aaa02f00488b38498b4424108b7014e8922f1c00c6800d01000001418b042483f80b746e83c0f883f8020f87b7000000488d1d97a02f00488b3bbe450c0000e822801b00f30f2ad0f30f5e158e262200498d74243c488d7d980f57c00f57c9e8825a1d00488b3bbe28000000e8f57f1b000f57c0f30f2ac0f30f59054e262200f30f58055a2622004c89e7e88ef7ffffeb55498b7c2408c7458800000000c7458c0000803fc7459000000000488d55884c89fee84658ffff488d9578ffffff498b7c2410c78578ffffff00000000c7857cffffff0000803fc74580000000004c89fee81758ffff498b4424184885c07441833800743c31db4c8d2daf9f2f00488b40084c8b3cd84c89ff4c89f6e85657ffff418b7714498b7d00e8872e1c0048ffc3c6800d01000001498b4424183b1872cd41c644243001418b4608898570ffffff498b0648898568ffffff488db568ffffff4c89e7e863fcffff4883c4785b415c415d415e415f5dc3'],
 'activation_virtual': [2399714, 8, '__const', '201f150001000000'],
 'model_install_virtual': [2399706, 8, '__const', '98cb140001000000'],
 'offset_x': [1545990, 4, '__const', '00409c45'],
 'offset_z': [1545586, 4, '__const', '0060ea46'],
 'yaw': [1546070, 4, '__const', 'db0f4940']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'mission_controller': [138688,
                        93490,
                        '__text',
                        'sha256:e8859bf243afd08613994a0243deed7b8e74fe123e678ab3b1a50044070847f8'],
 'activation': [631086,
                82,
                '__text',
                '554889e553504889fbc783bc00000001000000488b7b08be01000000e8b7a1feff4889dfbe01000000e8eaaeffffc6834101000001488b7b184885ff7504488b7b10be010000004883c4085b5de95441ebff'],
 'placement': [609776,
               176,
               '__text',
               '554889e54156534883ec20f30f1155d4f30f114dd8f30f1145dc4889fbf30f118380000000f30f118b84000000f30f119388000000488b7b10e8688eebff4c8db3c0010000488d75e0f30f1045dcf30f1145e0f30f1045d8f30f1145e4f30f1045d4f30f1145e84c89f7e823db0600488bbbb80100004885ff7410f3410f104e08f3410f7e06e87dc804004c8b7308488b7b10e8848debff4983c6084c89f74889c6e8db7709004883c4205b415e5dc3'],
 'visibility': [610374,
                78,
                '__text',
                '554889e5535089f3488b47104885c07436488b4f184885c974288b711c83feff7425488d05fb921b00488b38e88b6f08000fb6f34889c74883c4085b5de9caa907008b701cebd64883c4085b5dc3'],
 'model_install': [-79336,
                   272,
                   '__text',
                   '554889e54156534889fb8993b00000004885f6746980f10184c97562488973184c8b73104d85f67527bfe8000000e82d5618004989c6488d0515192600488b304c89f7e8820ef6ff4c897310488b73188b76144c89f7e87110f6ff488b4b10488b43188b491489482ceb384889c34c89f7e8de5518004889dfe812561800488973104c8b73184d85f674104c89f7e8a50ff6ff4c89f7e8b955180048c7431800000000f30f109388000000f30f108b84000000f30f108380000000488b7b10e8ba11f6ff4c8b7308488b7b10e82311f6ff4983c6084c89f74889c6e87afb1300488b7b184885ff750a5b415e5dc3e978ffffff488b5b084883c308e8f410f6ff4889df4889c65b415e5de93bfc130090'],
 'actor_factory': [77944, 3478, '__text', 'sha256:1edb599619eeabcc4601e757d01307eba28fc1a7bfb5ea74ea86ef4b365fcbf3'],
 'matrix_setter': [-730082, 24, '__text', '554889e54889f08b7714488b7f384889c25de9cddb1c0090'],
 'position_setter': [-729962,
                     68,
                     '__text',
                     '554889e54883ec50f30f1155bcf30f114db8f30f1145b48b7714488b7f38e869dd1c00488d7dc04889c6f30f1045b4f30f104db8f30f1055bce82e0b1e004883c4505dc3'],
 'euler_addition': [-728986,
                    140,
                    '__text',
                    '554889e5534881ec880000004889fbf30f584340f30f114340f30f584b44f30f114b44f30f585348f30f1153488b7314488b7b38e883d91c00488d7db88b535cf30f105348f30f104340f30f104b444889c6e805fb1d008b7314488b7b38e859d91c00488dbd78fffffff30f105354f30f10434cf30f104b504889c6e8bb051e004881c4880000005b5dc390'],
 'effect_trigger': [-687254,
                    484,
                    '__text',
                    '554889e54157415641554154534883ec784989d74989f64989fc498b7c2408e8b658ffff488d05d55f2f00488b38498b4424088b7014e85d3c1c00c6800d01000001498b4424088b701c83feff7416488d05aa5f2f00488b38e83a3c1c00c6800d01000001498b7c24104885ff74264c89f6e86358ffff488d05825f2f00488b38498b4424108b7014e80a3c1c00c6800d01000001418b042483f80b746e83c0f883f8020f87b7000000488d1d6f5f2f00488b3bbe450c0000e8fa941b00f30f2ad0f30f5e15e6db2100498d74243c488d7d980f57c00f57c9e89a551d00488b3bbe28000000e8cd941b000f57c0f30f2ac0f30f5905a6db2100f30f5805b2db21004c89e7e88ef7ffffeb55498b7c2408c7458800000000c7458c0000803fc7459000000000488d55884c89fee83e58ffff488d9578ffffff498b7c2410c78578ffffff00000000c7857cffffff0000803fc74580000000004c89fee80f58ffff498b4424184885c07441833800743c31db4c8d2d875e2f00488b40084c8b3cd84c89ff4c89f6e84e57ffff418b7714498b7d00e8ff3a1c0048ffc3c6800d01000001498b4424183b1872cd41c644243001418b4608898570ffffff498b0648898568ffffff488db568ffffff4c89e7e863fcffff4883c4785b415c415d415e415f5dc3'],
 'activation_virtual': [2377146, 8, '__const', '6c39150001000000'],
 'model_install_virtual': [2377138, 8, '__const', 'e4e5140001000000'],
 'offset_x': [1520974, 4, '__const', '00409c45'],
 'offset_z': [1520570, 4, '__const', '0060ea46'],
 'yaw': [1521054, 4, '__const', 'db0f4940']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# LevelScript::process: once at cursor 5 (phase 0 -> 1) the pirate appears at the player + (5000, 0,
           # 30000) in world space, turned by pi, and wakes (PlayerFighter::awake: mode 1, active, visible).
           'mission_controller': ('_ZN11LevelScript7processEi', 0, 59076, 'sha256:fc48a0891a46a9391ae3fe50b9ad196d3c917dbd5cd6c3b58c4d2c9cdc2aa5ca'),
           'offsets': ('_ZN11LevelScript7processEi', 408, 8, '00409c450060ea46'),
           'yaw': ('_ZN11LevelScript7processEi', 1172, 8, '40f6db72c4f24902'),
           # The fighter: activation, placement, exhaust visibility and its banked model (KIPlayer::setShipGroup
           # under PlayerFighter::setShipGroup), built by Level::createShip; AEGeometry and Explosion helpers.
           'activation': ('_ZN13PlayerFighter5awakeEv', 0, 48, 'sha256:616faca6c49e0b1debbcee2f7669636c9d29c359be12269b86f53e65061712de'),
           'placement': ('_ZN13PlayerFighter11setPositionEfff', 0, 120, 'sha256:84b11cc073cadac276caa21eb0eef09b9016bb682c15fad91054bd0e74a4dbe8'),
           'visibility': ('_ZN13PlayerFighter17setExhaustVisibleEb', 0, 68, 'sha256:2426d18894020f756342842c77b504144571bf20e2ba79ad3b3f09f8c17270dd'),
           'model_install_entry': ('_ZN13PlayerFighter12setShipGroupEP10AEGeometryib', 0, 4, 'e8f00abd'),
           'model_install': ('_ZN8KIPlayer12setShipGroupEP10AEGeometryib', 0, 160, 'sha256:249560a0c9fbb1d950cae0becb50f84c6bfd58ac4c548ad7c56e38a098148570'),
           'actor_factory': ('_ZN5Level10createShipEiiiP8Waypointbb', 0, 3112, 'sha256:678eef9996991343994b4360f4e6ce25dc05eb2aab54b3b5f09e665f7f83d91c'),
           'matrix_setter': ('_ZN10AEGeometry9setMatrixERKN11AbyssEngine6AEMath6MatrixE', 0, 10, '0a46c168c06a27f1ffbe'),
           'position_setter': ('_ZN10AEGeometry11setPositionEfff', 0, 76, 'sha256:fdaa786a2e39b20ca9b4f87c24ca1ab881add82b775e8bca70c695fa82b9a154'),
           'euler_addition': ('_ZN10AEGeometry6rotateEfff', 0, 156, 'sha256:3cb10368bf260dbddd4cb9987882f5ae54c6cc0a85219993b72dcf1b32da66af'),
           'effect_trigger': ('_ZN9Explosion5startERKN11AbyssEngine6AEMath6VectorES4_', 0, 424, 'sha256:1c46779e818994b2397ab5e986aaef2a0ca7a0d86e012700190e6939b6bf8985')}
# PlayerFighter's vtable: slots 2 (setShipGroup), 3 (awake) and 18 (setPosition(float, float, float)).
ANDROID_VTABLES = {'model_install_virtual': ('_ZTV13PlayerFighter', 2, ['_ZN13PlayerFighter12setShipGroupEP10AEGeometryib', '_ZN13PlayerFighter5awakeEv']),
                   'placement_virtual': ('_ZTV13PlayerFighter', 18, ['_ZN13PlayerFighter11setPositionEfff'])}
