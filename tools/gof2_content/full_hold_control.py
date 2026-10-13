"""Mac second-trip NPC control declarations; no original runtime code is emitted.

Android: PlayerFighter::update and the PlayerFighter constructor control the
pirate; Level::init with Player::setEnemies / addEnemies give it the player
as target; the PlayerEgo constructor, PlayerEgo::isInRocketControl /
getTargetFollowCamera, TargetFollowCamera::getTarget, AEGeometry's
constructor, getPosition, setVisible and render, and Player::isDead /
isActive / doesNeverAttack are the helpers the control reads.
"""
import copy
from .declaration_layouts import recognize, recognize_symbols
from .station_exterior import declaration_bytes

def extract_full_hold_control(mach,arrival,pirate,actors):
    if mach.architecture == 'android-armv7':
        try:
            if pirate['scope'] != 'full_hold_pirate_combat': return {}
            npc = actors['npc_initialization']
            if not all(npc.get(k) for k in ['guidance', 'flight', 'holding', 'routes', 'construction', 'hostility']): return {}
        except (KeyError, TypeError, AttributeError): return {}
        proof = recognize_symbols(mach, ANDROID)
        return dict(VALUES, provenance=proof) if proof else {}
    if mach.architecture!='x86_64':return {}
    try:
        if pirate['scope']!='full_hold_pirate_combat':return {}
        npc=actors['npc_initialization']
        if not all(npc.get(k) for k in ['guidance','flight','holding','routes','construction','hostility']):return {}
        origin=arrival['provenance']['actor']
        if origin['bytes']!=315:return {}
        layouts=[{k:[v[2],v[0],v[1],v[3]] for k,v in rows.items()} for rows in [LAYOUTS,MAC_ALTERNATE]]
        proof=recognize(mach,origin['offset'],layouts,reader=declaration_bytes)
        if not proof:return {}
        values=VALUES
        result=copy.deepcopy(values);result['provenance']=proof
        return result
    except (KeyError,TypeError,ValueError,IndexError,OverflowError):return {}

VALUES = {'scope': 'full_hold_pirate_control',
 'campaign_cursor': 4,
 'actor_id': 0,
 'actor_kind': 8,
 'hull_catalogue_id': 2,
 'player_ship_id': 0,
 'player_target_count': 1,
 'retains_generated_route': True,
 'holding_selects_player': True,
 'initial_model_draw_enabled': True,
 'initial_node_draw_requested': True,
 'held_node_draw_requested': False,
 'active_node_draw_requested': True,
 'activation_world_flag': False,
 'proximity_before_mode_dispatch': True,
 'target_activation_defers_flight': True,
 'alternate_player_position_for_proximity': True,
 'proximity_replaces_same_pass_steering_vector': True,
 'firing_range_uses_target_statistics': True}

LAYOUTS = {'npc_update': [610766,
                17180,
                '__text',
                'sha256:ebf68b2b6ca047e083dacda1f7f7b6c9bd44140189540f8b670a9489112ee495'],
 'npc_constructor': [605172,
                     2562,
                     '__text',
                     'sha256:9872cce6e7b565f4b3dbeb762598ade1997e62a1d03100f33cfc538edab0800b'],
 'membership': [59038,
                2050,
                '__text',
                'sha256:4833480cd77d57fc971f51b26224e7efefb74b6b8a57d1c39189d721590857b4'],
 'merge_targets': [536398,
                   334,
                   '__text',
                   '554889e5415741564155415453504989f74989fe49837e78000f8415010000bf18000000e8b5520f004989c4bf08000000e8a2520f00498944240841c74424100100000048c7000000000041c7042400000000498b4e7831f6833900743e31db488b49084c8b2cd9ffc6418974241048c1e6034889c7e877530f00498944240848ffc3418b0c244c892cc8418b74241041893424498b4e783b1972c441833f00743b31db498b4f084c8b2cd9ffc6418974241048c1e6034889c7e833530f00498944240848ffc3418b0c244c892cc8418b74241041893424413b1f72c74c89f74c89e6e878fdffff4d85e47425498b7c24084885ff7405e8d0510f004c89e74883c4085b415c415d415e415f5de9c0510f004883c4085b415c415d415e415f5dc34989c64c89e7e8a6510f004c89f7e8da510f004c89f74c89fe4883c4085b415c415d415e415f5de913fdffff90'],
 'assign_targets': [535982,
                    246,
                    '__text',
                    '554889e5415741564154534989f64989fc4d8b7c24784d85ff7416498b7f084885ff7405e843540f004c89ffe841540f0049c7442478000000004d85f67441bf18000000e835540f004989c7bf08000000e822540f004989470841c747100100000048c7000000000041c707000000004d897c24784c89f74c89fee8b4250000498b04244885c07451833800744c4531f64d63fe488b48084a8b0cf94885c9743131db833900742a488b4908488b3cd94885ff740e498b742478e8fbf2f4ff498b0424488b48084a8b0cf948ffc33b1972d641ffc6443b3072b75b415c415e415f5dc34889c34c89ffe884530f004889dfe8b8530f00'],
 'player_constructor': [549940,
                        3862,
                        '__text',
                        'sha256:371a2b68bd0f8fe679486e63a980898adec8d0747b424f98de0bb63ee2b525db'],
 'alternate_body_test': [558742, 18, '__text', '554889e54883bf00020000000f95c05dc390'],
 'alternate_body': [604878, 14, '__text', '554889e5488b87b80000005dc390'],
 'alternate_model': [905094, 10, '__text', '554889e5488b47085dc3'],
 'model_position': [-724356, 26, '__text', '554889e58b7714488b7f38e82ed21c004889c75de9a5fe1d0090'],
 'model_constructor': [-725444,
                       430,
                       '__text',
                       '554889e5415741564154534189cc4989d64189f74889fbc783a000000000000000c783a400000000000000c783a800000000000000c783ac0000000000803f48c783b80000000000000048c783b000000000000000c783c00000000000803f488d732048c783cc0000000000000048c783c400000000000000c783d40000000000803fc783d800000000000000c783dc0000000000803fc783e00000000000803fc783e40000000000803f6644897b104c897338c7431400000000c74320000000004c89f7e824cd1c00488d5324410fb6cc4c89f74489fee8d1991c008b73208b53244c89f7e8c3d01c00c7434800000000c7434400000000c7434000000000c743540000803fc743500000803fc7434c0000803fc6435801c6435901c7435c0000000048c7839800000000000000c743300000000048c783880000000000000048c783800000000000000048c743780000000048c743700000000048c74368000000008b7320897314c74328ffffffffc7431cffffffffc74318ffffffffc7432cffffffff4c89f7e8f0d41c00488dbbac0000004889c6e821f31d0048c74308000000005b415c415e415f5dc3'],
 'model_request': [-722468, 14, '__text', '554889e540887758408877595dc3'],
 'model_submission': [-722442, 28, '__text', '554889e5f647580175025dc38b7714488b7f3831d25de9a9801c0090'],
 'target_alive': [540880, 16, '__text', '554889e583bf80000000000f9ec05dc3'],
 'target_activity': [540924, 14, '__text', '554889e58a87c800000024015dc3'],
 'force_route': [535610, 14, '__text', '554889e58a87fa00000024015dc3']}

# Complete independently verified alternate Mac layout.
MAC_ALTERNATE = {'npc_update': [611314, 17180, '__text', 'sha256:e6a3db4e2bdaf51990eddaec2e03514db9eb5bb8a89976338b28605117681d20'],
 'npc_constructor': [605720, 2562, '__text', 'sha256:69ffded45ed01c0720d4524c45cb78a5be444af55b84ea7c93f85df3bf003325'],
 'membership': [59038, 2050, '__text', 'sha256:5cec2a39970c6bba7be2beaa7f36316ff243a1f731629df566750696ea854d8c'],
 'merge_targets': [536934,
                   334,
                   '__text',
                   '554889e5415741564155415453504989f74989fe49837e78000f8415010000bf18000000e8e9ee0e004989c4bf08000000e8d6ee0e00498944240841c74424100100000048c7000000000041c7042400000000498b4e7831f6833900743e31db488b49084c8b2cd9ffc6418974241048c1e6034889c7e8abef0e00498944240848ffc3418b0c244c892cc8418b74241041893424498b4e783b1972c441833f00743b31db498b4f084c8b2cd9ffc6418974241048c1e6034889c7e867ef0e00498944240848ffc3418b0c244c892cc8418b74241041893424413b1f72c74c89f74c89e6e878fdffff4d85e47425498b7c24084885ff7405e804ee0e004c89e74883c4085b415c415d415e415f5de9f4ed0e004883c4085b415c415d415e415f5dc34989c64c89e7e8daed0e004c89f7e80eee0e004c89f74c89fe4883c4085b415c415d415e415f5de913fdffff90'],
 'assign_targets': [536518,
                    246,
                    '__text',
                    '554889e5415741564154534989f64989fc4d8b7c24784d85ff7416498b7f084885ff7405e877f00e004c89ffe875f00e0049c7442478000000004d85f67441bf18000000e869f00e004989c7bf08000000e856f00e004989470841c747100100000048c7000000000041c707000000004d897c24784c89f74c89fee8b4250000498b04244885c07451833800744c4531f64d63fe488b48084a8b0cf94885c9743131db833900742a488b4908488b3cd94885ff740e498b742478e8f7eef4ff498b0424488b48084a8b0cf948ffc33b1972d641ffc6443b3072b75b415c415e415f5dc34889c34c89ffe8b8ef0e004889dfe8ecef0e00'],
 'player_constructor': [550476,
                        3862,
                        '__text',
                        'sha256:289fd4c3fd181835b86546bd64ac04a88648b04f2e5cc587dd6aa9acbffbb88d'],
 'alternate_body_test': [559278, 18, '__text', '554889e54883bf00020000000f95c05dc390'],
 'alternate_body': [605426, 14, '__text', '554889e5488b87b80000005dc390'],
 'alternate_model': [905726, 10, '__text', '554889e5488b47085dc3'],
 'model_position': [-730252, 26, '__text', '554889e58b7714488b7f38e89ede1c004889c75de985f91d0090'],
 'model_constructor': [-731340,
                       430,
                       '__text',
                       '554889e5415741564154534189cc4989d64189f74889fbc783a000000000000000c783a400000000000000c783a800000000000000c783ac0000000000803f48c783b80000000000000048c783b000000000000000c783c00000000000803f488d732048c783cc0000000000000048c783c400000000000000c783d40000000000803fc783d800000000000000c783dc0000000000803fc783e00000000000803fc783e40000000000803f6644897b104c897338c7431400000000c74320000000004c89f7e8b4d91c00488d5324410fb6cc4c89f74489fee8b1a81c008b73208b53244c89f7e843dd1c00c7434800000000c7434400000000c7434000000000c743540000803fc743500000803fc7434c0000803fc6435801c6435901c7435c0000000048c7839800000000000000c743300000000048c783880000000000000048c783800000000000000048c743780000000048c743700000000048c74368000000008b7320897314c74328ffffffffc7431cffffffffc74318ffffffffc7432cffffffff4c89f7e860e11c00488dbbac0000004889c6e8a1ed1d0048c74308000000005b415c415e415f5dc3'],
 'model_request': [-728364, 14, '__text', '554889e540887758408877595dc3'],
 'model_submission': [-728338, 28, '__text', '554889e5f647580175025dc38b7714488b7f3831d25de999901c0090'],
 'target_alive': [541416, 16, '__text', '554889e583bf80000000000f9ec05dc3'],
 'target_activity': [541460, 14, '__text', '554889e58a87c800000024015dc3'],
 'force_route': [536146, 14, '__text', '554889e58a87fa00000024015dc3']}

# Android spans inside named functions; the values are VALUES.
ANDROID = {# PlayerFighter::update and its constructor steer, hold, fire and wake the pirate; Level::init and
           # Player::setEnemies / addEnemies give it the player as its one target.
           'npc_update': ('_ZN13PlayerFighter6updateEi', 0, 10528, 'sha256:fb79b3bde0fb27a45861c89450940e96ec313695cb5d4b4c290220c25ef78d9e'),
           'npc_constructor': ('_ZN13PlayerFighterC2EiiP6PlayerP10AEGeometryfffb', 0, 1668, 'sha256:9722fa1dff717e74e4f5d93a1ee0e2af195659b26021723e8d5632f5ba9eaf91'),
           'membership': ('_ZN5Level4initEv', 0, 1792, 'sha256:fceec130c720743b341b16f0e8ce63d43a1382808e075533d391370c9949a244'),
           'merge_targets': ('_ZN6Player10addEnemiesEP5ArrayIPS_E', 0, 208, 'sha256:fa30dc0eba400e6524939de373cba3e539ef454ec48aa8eccad4d8abeb4400b4'),
           'assign_targets': ('_ZN6Player10setEnemiesEP5ArrayIPS_E', 0, 174, 'sha256:d18a42da79a8fc28097c1369f9ddca9c072d2821e985b1b539e4e02c0495c43f'),
           # The player and its alternate body (rocket control: the camera target), model drawing and the
           # target predicates.
           'player_constructor': ('_ZN9PlayerEgoC2EP6Player', 0, 2256, 'sha256:32e47e8e7a4022ce6a08268493b8fcf1ad21866a22aa6cc97fd1cb530435f7bc'),
           'alternate_body_test': ('_ZN9PlayerEgo17isInRocketControlEv', 0, 12, 'd0f89401002818bf01207047'),
           'alternate_body': ('_ZN9PlayerEgo21getTargetFollowCameraEv', 0, 6, 'd0f888007047'),
           'alternate_model': ('_ZN18TargetFollowCamera9getTargetEv', 0, 4, '40687047'),
           'model_position': ('_ZN10AEGeometry11getPositionEv', 0, 26, 'sha256:b9c206761276e9c203fbee1b2dbbde7151babe54fc1343e0edc216c8b9c0e609'),
           'model_constructor': ('_ZN10AEGeometryC2EtPN11AbyssEngine11PaintCanvasEb', 0, 256, 'sha256:445381dc0cac413fa861ce74ac9422ae16ed2c8660e9ae7a6f9334c0d9a82f99'),
           'model_request': ('_ZN10AEGeometry10setVisibleEb', 0, 10, '80f8481080f849107047'),
           'model_submission': ('_ZN10AEGeometry6renderEv', 0, 18, '90f8481021b1c1680022c06a27f192bc7047'),
           'target_alive': ('_ZN6Player6isDeadEv', 0, 12, '816f00200129b8bf01207047'),
           'target_activity': ('_ZN6Player8isActiveEv', 0, 6, '90f8c0007047'),
           'force_route': ('_ZN6Player15doesNeverAttackEv', 0, 6, '90f8ee007047')}
