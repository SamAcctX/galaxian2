"""Read authored opening poses and reveal gate; emit no executable behavior.

Camera vectors are source position parameters, not resolved world-view poses.
Only the recognized cursor-zero initial and first formation declarations qualify.

Android: LevelScript's constructor, on campaign mission 0, places the camera
and the player, turns the player to +Z and hides the three enemies;
LevelScript::process, on mission 0 once message 2 is over, places player,
camera and the three enemies (facing +X) and shows them.
"""
import math
import struct
from .opening_loadout import template
from .ship_models import section_bytes
from .steering import PC, code_span, shape_at

MAC_INITIAL = """
488d05
{ref_0:4}
488b38e8
{call_a:4}
85c00f85
{jump_11:4}
488b85b8f5ffff48c70000000000488b85c8f5ffffc6400100488b85d0f5ffffc68090000000004c89e7e8
{call_41:4}
4889c7be01000000e8
{call_4e:4}
4c89e7e8
{call_56:4}
488b38be01000000e8
{call_63:4}
41c6472d014c89efbe01000000e8
{call_75:4}
488d75c8c745c8
{camera_x:4}
c745cc
{camera_y:4}
c745d0
{camera_z:4}
4c89efe8
{call_96:4}
4c89e7e8
{call_9e:4}
f30f1015
{ref_a3:4}
4889c7660fefc0660fefc9e8
{call_b6:4}
4c89e7e8
{call_be:4}
488d75b8488d55a8488b7810c745b800000000c745bc00000000c745c00000803fc745a800000000c745ac0000803fc745b000000000e8
{call_f9:4}
31db4c89e7e8
{call_103:4}
488b4008488b3cd8e8
{call_110:4}
4c89e7e8
{call_118:4}
488b4008488b04d8488b781031f6e8
{call_12b:4}
4c89e7e8
{call_133:4}
488b4008488b04d8c78078010000000000004c89e7e8
{call_14d:4}
488d4b0183f903488b4008488b04d8488b4008c64060004889cb75
{jump_16c:1}
"""

MAC_FORMATION = """
498b7d20e8
{call_4:4}
4889c3498b7d20e8
{call_10:4}
4989c7498b7d20e8
{call_1c:4}
4989c4488d05
{ref_24:4}
488b38e8
{call_2e:4}
85c00f85
{jump_35:4}
488b4308488b7810e8
{call_43:4}
418b4d2884c00f84
{jump_4e:4}
85c90f85
{jump_56:4}
48899db0d0ffff4489b5c0d0ffff41c7452801000000f30f1005
{ref_72:4}
f30f100d
{ref_7a:4}
f30f1015
{ref_82:4}
4c89ff4c89bdc8d0ffffe8
{call_94:4}
498b7d18f30f100d
{ref_9d:4}
f30f1015
{ref_a5:4}
f30f1005
{ref_ad:4}
e8
{call_b5:4}
488d05
{ref_ba:4}
488b184889dfe8
{call_c7:4}
4889df89c6e8
{call_d1:4}
488d7d904889c6f30f1005
{ref_dd:4}
f30f100d
{ref_e5:4}
f30f1015
{ref_ed:4}
e8
{call_f5:4}
f30f1005
{ref_fa:4}
f30f100d
{ref_102:4}
498b442408488b38488b070f57d2ff9090000000f30f100d
{ref_11e:4}
f30f1015
{ref_126:4}
498b442408488b7808488b07f30f1005
{ref_13a:4}
ff9090000000f30f100d
{ref_148:4}
498b442408488b7810488b07f30f1005
{ref_15c:4}
f30f1015
{ref_164:4}
ff909000000031db4c8d75804c8dbd70ffffff498b442408488b04d8488b7810c745800000803fc7458400000000c7458800000000c78570ffffff00000000c78574ffffff0000803fc78578ffffff000000004c89f64c89fae8
{call_1c5:4}
498b442408488b04d8488b7810be01000000e8
{call_1dc:4}
48ffc383fb0375
{jump_1e7:1}
"""

ARM_INITIAL = """
1498cdf854b00460446016984470179880f848404046cdf85068
{call_1a:4}
0121cdf850680125
{call_26:4}
4046cdf85068
{call_30:4}
00680121cdf85068
{call_3c:4}
8af81d500121bd68cdf864a0cdf850682846
{call_52:4}
{camera_x_low:2}
0df5fd61
{camera_x_high:4}
cdf8e807
{camera_y_low:2}
{camera_y_high:4}
cdf8ec07
{camera_z_low:4}
{camera_z_high:4}
cdf8f0072846cdf85068
{call_80:4}
4046cdf85068
{call_8a:4}
{player_z_low:4}
0021
{player_z_high:4}
0022cdf85068
{call_9e:4}
4046cdf85068
{call_a8:4}
80684ff07e51cdf8dc470df5fa62cdf8e047cdf8d047cdf8d417cdf8e4170df2dc71cdf8d847cdf85068
{call_d6:4}
00254046cdf85068
{call_e2:4}
406850f82500cdf85068
{call_f0:4}
4046cdf85068
{call_fa:4}
4068002150f825008068cdf85068
{call_10c:4}
4046cdf85068
{call_116:4}
406850f82500c0f824414046cdf85068
{call_12a:4}
406850f825000135032d406880f85c40
{jump_13e:2}
"""

ARM_INITIAL_DISPATCH = """
4ff0ff364046cdf85068
{call_a:4}
0021cdf850680024
{call_16:4}
{pointer_1a:4}
{pointer_1e:4}
7844d0f800b0dbf80000cdf85068
{call_30:4}
0028
{jump_36:4}
"""

ARM_FORMATION = """
d8f80400d346cdf87cb00df5005b4ff0ff318068cbf82414
{call_18:4}
b16901284446b24608bf0029
{jump_28:4}
01201b945446caf818000df5005a4ff0ff382095
{player_y_low:4}
2194
{player_x_low:4}
caf82484
{player_z_low:4}
1d98
{player_y_high:4}
{player_x_high:4}
{player_z_high:4}
2a46
{call_62:4}
{camera_z_low:2}
2069
{camera_y_low:2}
0df5005a
{camera_z_high:4}
{camera_y_high:4}
29463346caf824849346
{call_82:4}
{pointer_86:4}
0df5005a
{pointer_8e:4}
784400680468caf824842046
{call_9e:4}
0df5005a01462046caf82484
{call_ae:4}
0df5005401462a465b46c4f82484009602ae06f50e50
{call_c8:4}
ddf87ca0
{actor_x_low:4}
{actor0_y_low:2}
0df5005e
{actor_x_high:4}
{actor0_y_high:4}
daf8040000230026006801688c6c2946cef82484a047daf80400
{actor1_y_low:2}
{actor1_z_low:4}
0df5005e
{actor1_y_high:4}
{actor1_z_high:4}
406801688c6c2946cef82484a047daf80400
{actor2_y_low:2}
0df5005e
{actor2_y_high:4}
5b46806801688c6c2946cef82484a0470df1140e4ff07e540ef5015800254ff0ff3bdaf804000df5005e50f825008068c8f81c63c8f82043c8f82843c8f82c63c8f82463c8f83063cef824b40df13c0e0ef50d510df1300e0ef50d52
{call_186:4}
daf804000df5005e012150f825008068cef824b4
{call_19e:4}
0135032d
{jump_1a6:2}
"""

ARM_UPDATE_DISPATCH = """
f0b503af2de9000dadf1400424f00f04a54604f9ed8204f9efc2adf5125d88b01e910646
{pointer_24:4}
05ac
{pointer_2a:4}
04f5015b784400681c90006822907069
{call_3e:4}
80467069
{call_46:4}
1d907069
{call_4e:4}
8246
{pointer_54:4}
{pointer_58:4}
784405682868
{call_62:4}
0446
{pointer_68:4}
{pointer_6c:4}
0df5005e7844
{literal_76:4}
00687944cef838040df5005ecef83c140df5005e
{literal_8e:4}
cef84074cbf8f4d30df1200b0bf510500df5005b41f001017944cbf84414
{call_b0:4}
002c
{jump_b6:4}
"""

ANDROID_CONSTRUCTOR = '_ZN11LevelScriptC2EP5LevelP3HudP5RadarP18TargetFollowCamera'
ANDROID_PROCESS = '_ZN11LevelScript7processEi'
GET_PLAYER, GET_ENEMIES, CURSOR = '=_ZN5Level9getPlayerEv', '=_ZN5Level10getEnemiesEv', '=_ZN6Status25getCurrentCampaignMissionEv'
SET_POSITION, SET_DIRECTION = '=_ZN9PlayerEgo11setPositionEfff', '=_ZN10AEGeometry12setDirectionERKN11AbyssEngine6AEMath6VectorES4_'
SET_VISIBLE = '=_ZN10AEGeometry10setVisibleEb'
IMM = r'#(0x[0-9a-f]+|\d+)'
LOAD_STATUS = [('ldr.w', 'r0, ' + PC), ('add', 'r0, pc'), ('ldr', r'r0, \[r0\]'), ('ldr', r'r0, \[r0\]'), ('blx', CURSOR), ('cmp', 'r0, #0')]
# r6 = 0; the constructor branches to the opening when the campaign mission is 0.
INITIAL_DISPATCH = [('movs', 'r1, #0'), ('movs', 'r6, #0'), ('blx', '=_ZN9PlayerEgo10setCollideEb')] + LOAD_STATUS + [
    ('str', r'r4, \[sp, #0x44\]'), ('beq', '#0x[0-9a-f]+')]
ENEMY = [('mov', 'r0, sl'), ('blx', GET_ENEMIES), ('ldr', r'r0, \[r0, #4\]'), ('ldr.w', r'r0, \[r0, r4, lsl #2\]')]
INITIAL = [('strd', r'r6, r6, \[r4\]'), ('ldr', r'r0, \[sp, #0x4c\]'), ('strb', r'r6, \[r0, #1\]'), ('mov', 'r0, sl'),
           ('ldr.w', r'sb, \[sp, #0x48\]'), ('strb.w', r'r6, \[sb, #0x48\]'), ('blx', GET_PLAYER), ('movs', 'r1, #1'), ('movs', 'r4, #1'),
           ('blx', '=_ZN9PlayerEgo21setComputerControlledEb'), ('mov', 'r0, sl'), ('blx', GET_PLAYER), ('ldr', r'r0, \[r0\]'),
           ('movs', 'r1, #1'), ('blx', '=_ZN6Player13setVulnerableEb'), ('mov', 'r0, fp'), ('movs', 'r1, #1'),
           ('strb.w', r'r4, \[r8, #0x21\]'), ('blx', '=_ZN18TargetFollowCamera12setLookAtCamEb'),
           # camera (19/21, 23/24, 26/27: low/high halves) by vector, player (0, 0, 33/35)
           ('movs', 'r0, ' + IMM), ('add', 'r1, sp, #0x98'), ('movt', 'r0, ' + IMM), ('str', r'r0, \[sp, #0x98\]'),
           ('movs', 'r0, ' + IMM), ('movt', 'r0, ' + IMM), ('str', r'r0, \[sp, #0x9c\]'), ('movw', 'r0, ' + IMM),
           ('movt', 'r0, ' + IMM), ('str', r'r0, \[sp, #0xa0\]'), ('mov', 'r0, fp'),
           ('blx', '=_ZN18TargetFollowCamera11setPositionERKN11AbyssEngine6AEMath6VectorE'), ('mov', 'r0, sl'), ('blx', GET_PLAYER),
           ('movw', 'r3, ' + IMM), ('movs', 'r1, #0'), ('movt', 'r3, ' + IMM), ('movs', 'r2, #0'), ('blx', SET_POSITION),
           # direction (0, 0, 1), up (0, 1, 0)
           ('mov', 'r0, sl'), ('blx', GET_PLAYER), ('ldr', r'r0, \[r0, #8\]'), ('mov.w', 'r1, #0x3f800000'),
           ('strd', r'r6, r6, \[sp, #0x98\]'), ('add', 'r2, sp, #0x5c'), ('str', r'r1, \[sp, #0xa0\]'), ('strd', r'r6, r1, \[sp, #0x5c\]'),
           ('add', 'r1, sp, #0x98'), ('str', r'r6, \[sp, #0x64\]'), ('blx', SET_DIRECTION),
           # enemies 0-2 sleep, hidden
           ('movs', 'r4, #0')] + ENEMY + [('blx', '=_ZN8KIPlayer10setToSleepEv')] + ENEMY[:3] + [('movs', 'r1, #0'), ENEMY[3],
           ('ldr', r'r0, \[r0, #8\]'), ('blx', SET_VISIBLE)] + ENEMY + [('str.w', r'r6, \[r0, #0x124\]')] + ENEMY + [
           ('adds', 'r4, #1'), ('cmp', 'r4, #3'), ('ldr', r'r0, \[r0, #4\]'), ('strb.w', r'r6, \[r0, #0x5c\]'), ('bne', '@50')]
# r6 = messages, r8 = player, fp = enemies; process branches to the opening on campaign mission 0.
UPDATE_DISPATCH = [('ldr.w', r'r0, \[sl, #0x18\]'), ('blx', '=_ZN5Level11getMessagesEv'), ('mov', 'r6, r0'),
                   ('ldr.w', r'r0, \[sl, #0x18\]'), ('blx', GET_PLAYER), ('mov', 'r8, r0'), ('ldr.w', r'r0, \[sl, #0x18\]'),
                   ('blx', GET_ENEMIES), ('mov', 'fp, r0')] + LOAD_STATUS + [('mov', 'r0, fp'), ('str', r'r0, \[sp, #0x50\]'),
                   ('str.w', r'sb, \[sp, #0x48\]'), ('beq.w', '#0x[0-9a-f]+')]
ACTOR = [('ldr', r'r1, \[r0\]'), ('ldr', r'r4, \[r1, #0x48\]'), ('mov', 'r1, r5'), ('blx', 'r4')]
FORMATION = [('ldr', r'r0, \[r6, #4\]'), ('ldr', r'r0, \[r0, #8\]'), ('blx', '=_ZN12RadioMessage6isOverEv'),
             ('ldr.w', r'r1, \[sl, #0x1c\]'), ('cmp', 'r0, #1'), ('strd', r'r6, r8, \[sp, #0x40\]'), ('it', 'eq'),
             ('cmpeq', 'r1, #0'), ('bne.w', '#0x[0-9a-f]+'),
             # player (10/15, 9/13, 11/16)
             ('movw', 'r5, ' + IMM), ('movw', 'r1, ' + IMM), ('movw', 'r3, ' + IMM), ('movs', 'r0, #1'), ('movt', 'r5, ' + IMM),
             ('str.w', r'r0, \[sl, #0x1c\]'), ('movt', 'r1, ' + IMM), ('movt', 'r3, ' + IMM), ('mov', 'r0, r8'), ('mov', 'r2, r5'),
             ('blx', SET_POSITION),
             # camera (player y, 20/23, 21/24), also the camera matrix translation
             ('movw', 'sb, ' + IMM), ('movs', 'r4, ' + IMM), ('ldr.w', r'r0, \[sl, #0x14\]'), ('movt', 'sb, ' + IMM),
             ('movt', 'r4, ' + IMM), ('mov', 'r1, r5'), ('mov', 'r2, sb'), ('mov', 'r3, r4'),
             ('blx', '=_ZN18TargetFollowCamera11setPositionEfff'), ('ldr.w', 'r0, ' + PC), ('add', 'r0, pc'),
             ('ldr', r'r0, \[r0\]'), ('ldr', r'r6, \[r0\]'), ('mov', 'r0, r6'), ('blx', '=_ZN11AbyssEngine11PaintCanvas16CameraGetCurrentEv'),
             ('mov', 'r1, r0'), ('mov', 'r0, r6'), ('blx', '=_ZN11AbyssEngine11PaintCanvas14CameraGetLocalEj'),
             ('add.w', 'r8, sp, #0x1e8'), ('mov', 'r1, r0'), ('mov', 'r2, r5'), ('mov', 'r3, sb'), ('mov', 'r0, r8'),
             ('str', r'r4, \[sp\]'), ('blx', '=_ZN11AbyssEngine6AEMath20MatrixSetTranslationERNS0_6MatrixEfff'),
             # enemies' positions through their vtable slot 0x48: x 46/48; y 47/49, 58/60, 68/69; z 0, 59/61, camera y
             ('ldr.w', r'r0, \[fp, #4\]'), ('movw', 'r5, ' + IMM), ('movs', 'r2, ' + IMM), ('movt', 'r5, ' + IMM),
             ('movt', 'r2, ' + IMM), ('movs', 'r3, #0'), ('ldr', r'r0, \[r0\]'), ('movs', 'r6, #0')] + ACTOR + [
             ('ldr.w', r'r0, \[fp, #4\]'), ('movs', 'r2, ' + IMM), ('movw', 'r3, ' + IMM), ('movt', 'r2, ' + IMM),
             ('movt', 'r3, ' + IMM), ('ldr', r'r0, \[r0, #4\]')] + ACTOR + [
             ('ldr.w', r'r0, \[fp, #4\]'), ('movs', 'r2, ' + IMM), ('movt', 'r2, ' + IMM), ('mov', 'r3, sb'),
             ('ldr', r'r0, \[r0, #8\]')] + ACTOR + [
             # each enemy faces (1, 0, 0) with up (0, 1, 0) and is shown
             ('add.w', 'sb, sp, #0x190'), ('mov.w', 'r4, #0x3f800000'), ('movs', 'r5, #0'), ('ldr.w', r'r0, \[fp, #4\]'),
             ('mov', 'r1, r8'), ('mov', 'r2, sb'), ('ldr.w', r'r0, \[r0, r5, lsl #2\]'), ('ldr', r'r0, \[r0, #8\]'),
             ('strd', r'r4, r6, \[sp, #0x1e8\]'), ('str', r'r6, \[sp, #0x1f0\]'), ('strd', r'r6, r4, \[sp, #0x190\]'),
             ('str', r'r6, \[sp, #0x198\]'), ('blx', SET_DIRECTION), ('ldr.w', r'r0, \[fp, #4\]'), ('movs', 'r1, #1'),
             ('ldr.w', r'r0, \[r0, r5, lsl #2\]'), ('ldr', r'r0, \[r0, #8\]'), ('blx', SET_VISIBLE), ('adds', 'r5, #1'),
             ('cmp', 'r5, #3'), ('bne', '@79')]


def android_staging(lib):
    from .android_library import instructions
    provenance = {}

    def block(symbol, dispatch, shape, dispatch_key, block_key):
        """The dispatch's branch target starts the block; returns (code, block index) or None."""
        code = instructions(lib, symbol)
        found = shape_at(code, dispatch, lib) if code else []
        if len(found) != 1:
            return None
        target = code[found[0] + len(dispatch) - 1].operands[0].imm
        start = next((i for i, ins in enumerate(code) if ins.address == target), None)
        if start is None or shape_at(code[start:start + len(shape)], shape, lib) != [0]:
            return None
        provenance[dispatch_key] = code_span(lib, code, found[0], found[0] + len(dispatch) - 1)
        provenance[block_key] = code_span(lib, code, start, start + len(shape) - 1)
        return code[start:]
    initial = block(ANDROID_CONSTRUCTOR, INITIAL_DISPATCH, INITIAL, 'initial_dispatch', 'initial')
    formation = block(ANDROID_PROCESS, UPDATE_DISPATCH, FORMATION, 'update_dispatch', 'formation')
    if initial is None or formation is None:
        return {}

    def number(code, low, high):
        """The float a movw/movs low half and movt high half build."""
        return struct.unpack('<f', struct.pack('<I', code[low].operands[1].imm | code[high].operands[1].imm << 16))[0]
    initial_camera = [number(initial, 19, 21), number(initial, 23, 24), number(initial, 26, 27)]
    initial_player = [0.0, 0.0, number(initial, 33, 35)]
    player = [number(formation, 10, 15), number(formation, 9, 13), number(formation, 11, 16)]
    camera = [player[1], number(formation, 20, 23), number(formation, 21, 24)]
    x = number(formation, 46, 48)
    positions = [[x, number(formation, 47, 49), 0.0], [x, number(formation, 58, 60), number(formation, 59, 61)],
                 [x, number(formation, 68, 69), camera[1]]]
    if any(not math.isfinite(v) or abs(v) > 10000000 for v in initial_player + initial_camera + player + camera + sum(positions, [])):
        return {}
    return {'initial': {'player_position': initial_player, 'player_forward': [0, 0, 1], 'player_up': [0, 1, 0],
                        'camera_position_parameter': initial_camera, 'hidden_actor_ids': [0, 1, 2]},
            'formation': {'after_event_finished': 2, 'player_position': player, 'camera_position_parameter': camera,
                          'actors': [{'actor_id': i, 'position': p, 'forward': [1, 0, 0], 'up': [0, 1, 0], 'visible': True}
                                     for i, p in enumerate(positions)]},
            'provenance': provenance}


def extract_opening_staging(mach):
    if mach.architecture == 'android-armv7':
        return android_staging(mach)
    import capstone
    mac = mach.architecture == 'x86_64'
    if not mac and mach.architecture != 'armv7': return {}
    text = mach.text
    code = mach.data[text['offset']:text['offset'] + text['length']]
    base = text['address']
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    decoder.detail = True
    provenance = {}
    def unique(name, spec):
        matches = [m for m in template(spec).finditer(code) if mac or m.start() % 2 == 0]
        if len(matches) != 1: raise ValueError('Missing or ambiguous opening staging')
        m = matches[0]
        provenance[name] = {'offset': mach.slice_offset + text['offset'] + m.start(), 'bytes': len(m[0])}
        return m
    def number(m, key): return int.from_bytes(m[key], 'little', signed=True)
    def instruction(m, key):
        ins = list(decoder.disasm(m[key], base + m.start(key)))
        if len(ins) != 1: raise ValueError('Unsupported staging instruction')
        return ins[0]
    def target(m, key, mnemonic='bl'):
        if mac: return base + m.end(key) + number(m, key)
        ins = instruction(m, key)
        if ins.mnemonic != mnemonic or len(ins.operands) != 1 or ins.operands[0].type != 2:
            raise ValueError('Unsupported staging link')
        return ins.operands[0].imm
    def helper(name, address, hex_bytes):
        raw = bytes.fromhex(hex_bytes)
        found = section_bytes(mach, address, len(raw), b'__text')
        if found is None or found[0] != raw: raise ValueError('Unrecognized staging helper')
        provenance[name] = {'offset': found[1], 'bytes': len(raw)}
    def linked(m, keys):
        addresses = [target(m, key) for key in keys]
        if len(set(addresses)) != 1: raise ValueError('Inconsistent staging helper links')
        return addresses[0]
    def value(m, key):
        found = section_bytes(mach, target(m, key), 4, b'__const')
        if found is None: raise ValueError('Unbacked staging scalar')
        provenance[('initial_' if m is initial else 'formation_') + key] = {'offset': found[1], 'bytes': 4}
        return struct.unpack('<f', found[0])[0]
    def arm_float(m, name, register):
        low, high = instruction(m, name + '_low'), instruction(m, name + '_high')
        if low.mnemonic not in ('movs', 'movw') or high.mnemonic != 'movt': raise ValueError('Unsupported pose scalar')
        for ins in [low, high]:
            if len(ins.operands) != 2 or ins.reg_name(ins.operands[0].reg) != register or ins.operands[1].type != 2:
                raise ValueError('Invalid pose scalar register')
        return struct.unpack('<f', struct.pack('<I', low.operands[1].imm | (high.operands[1].imm << 16)))[0]
    try:
        initial = unique('initial', MAC_INITIAL if mac else ARM_INITIAL)
        formation = unique('formation', MAC_FORMATION if mac else ARM_FORMATION)
        if mac:
            getter = linked(initial, ['call_41', 'call_56', 'call_9e', 'call_be'])
            if getter != target(formation, 'call_10'): raise ValueError('Player identity changed')
            helper('player_getter', getter, '554889e5488b87680100005dc3')
            getter = linked(initial, ['call_103', 'call_118', 'call_133', 'call_14d'])
            if getter != target(formation, 'call_1c'): raise ValueError('Actor identity changed')
            helper('actor_getter', getter, '554889e5488b87780100005dc3')
            helper('event_getter', target(formation, 'call_4'), '554889e5488b87b00100005dc3')
            cursor = target(initial, 'call_a')
            if cursor != target(formation, 'call_2e'): raise ValueError('Different campaign cursor')
            helper('cursor_getter', cursor, '554889e58b87780200005dc3')
            if target(initial, 'jump_16c') != base + initial.start() + 0x100 or target(formation, 'jump_1e7') != base + formation.start() + 0x17f:
                raise ValueError('Unknown staging actor loop')
            if target(formation, 'jump_4e') != target(formation, 'jump_56') or target(formation, 'jump_4e') < base + formation.end():
                raise ValueError('Unknown reveal gate')
            if target(initial, 'jump_11') < base + initial.end() or target(formation, 'jump_35') < base + formation.end():
                raise ValueError('Invalid cursor-zero dispatch')
            initial_camera = [struct.unpack('<f', initial['camera_' + axis])[0] for axis in 'xyz']
            initial_player = [0.0, 0.0, value(initial, 'ref_a3')]
            player = [value(formation, k) for k in ['ref_72', 'ref_7a', 'ref_82']]
            camera = [value(formation, k) for k in ['ref_ad', 'ref_9d', 'ref_a5']]
            if camera != [value(formation, k) for k in ['ref_dd', 'ref_e5', 'ref_ed']]: raise ValueError('Conflicting camera vectors')
            positions = [[value(formation, 'ref_fa'), value(formation, 'ref_102'), 0.0],
                         [value(formation, k) for k in ['ref_13a', 'ref_11e', 'ref_126']],
                         [value(formation, k) for k in ['ref_15c', 'ref_148', 'ref_164']]]
            visible = target(initial, 'call_12b')
            if visible != target(formation, 'call_1dc'): raise ValueError('Different visibility setter')
            helper('visibility', visible, '554889e540887758408877595dc3')
            helper('event_finished', target(formation, 'call_43'), '554889e58a473124015dc3')
            helper('camera_vector', target(initial, 'call_96'), '554889e5f30f104608f30f1016f30f104e04f30f115710f30f114f14f30f1147185dc3')
            helper('camera_components', target(formation, 'call_b5'), '554889e5f30f114710f30f114f14f30f1157185dc3')
            if target(initial, 'call_b6') != target(formation, 'call_94') or target(initial, 'call_f9') != target(formation, 'call_1c5'):
                raise ValueError('Different player pose helper')
        else:
            dispatch = unique('initial_dispatch', ARM_INITIAL_DISPATCH)
            update = unique('update_dispatch', ARM_UPDATE_DISPATCH)
            if target(dispatch, 'jump_36', 'beq.w') != base + initial.start() or target(update, 'jump_b6', 'beq.w') != base + formation.start():
                raise ValueError('Unknown opening cursor dispatch')
            cursor = target(dispatch, 'call_30')
            if cursor != target(update, 'call_62'): raise ValueError('Different campaign cursor')
            helper('cursor_getter', cursor, 'd0f8d4017047')
            getter = linked(initial, ['call_1a', 'call_30', 'call_8a', 'call_a8'])
            if getter != target(update, 'call_46') or getter != target(dispatch, 'call_a'): raise ValueError('Player identity changed')
            helper('player_getter', getter, 'd0f8f0007047')
            getter = linked(initial, ['call_e2', 'call_fa', 'call_116', 'call_12a'])
            if getter != target(update, 'call_4e'): raise ValueError('Actor identity changed')
            helper('actor_getter', getter, 'd0f8f8007047')
            helper('event_getter', target(update, 'call_3e'), 'd0f814017047')
            if target(initial, 'jump_13e', 'bne') != base + initial.start() + 0xdc or target(formation, 'jump_1a6', 'bne') != base + formation.start() + 0x14c:
                raise ValueError('Unknown staging actor loop')
            if target(formation, 'jump_28', 'bne.w') < base + formation.end(): raise ValueError('Unknown reveal gate')
            initial_camera = [arm_float(initial, 'camera_' + axis, 'r0') for axis in 'xyz']
            initial_player = [0.0, 0.0, arm_float(initial, 'player_z', 'r3')]
            player = [arm_float(formation, 'player_' + axis, reg) for axis, reg in [('x', 'r1'), ('y', 'r5'), ('z', 'r3')]]
            camera = [player[1], arm_float(formation, 'camera_y', 'r2'), arm_float(formation, 'camera_z', 'r6')]
            x = arm_float(formation, 'actor_x', 'r5')
            positions = [[x, arm_float(formation, 'actor0_y', 'r2'), 0.0],
                         [x, arm_float(formation, 'actor1_y', 'r2'), arm_float(formation, 'actor1_z', 'r3')],
                         [x, arm_float(formation, 'actor2_y', 'r2'), camera[1]]]
            visible = target(initial, 'call_10c')
            if visible != target(formation, 'call_19e'): raise ValueError('Different visibility setter')
            helper('visibility', visible, '80f8481080f849107047')
            helper('event_finished', target(formation, 'call_18'), '90f821007047')
            helper('camera_vector', target(initial, 'call_80'), '91ed000ad1ed010b80ed020ac0ed030b7047')
            helper('camera_components', target(formation, 'call_82'), '00f1080989e80e007047')
            if target(initial, 'call_9e') != target(formation, 'call_62') or target(initial, 'call_d6') != target(formation, 'call_186'):
                raise ValueError('Different player pose helper')
        # Wildcard operands remain instructions of the recognized declaration.
        # Unused side-effect helpers must still be backed by code in this image.
        for match in ([initial, formation] if mac else [initial, formation, dispatch, update]):
            for key in match.groupdict():
                if key.startswith('call_'):
                    kind = 'blx' if not mac and match is update and key == 'call_b0' else 'bl'
                    address = target(match, key, kind)
                    backed = section_bytes(mach, address, 2, b'__text')
                    # ARM exception registration calls through a file-backed
                    # Mach-O import stub; it is not part of the emitted data.
                    if backed is None and kind == 'blx':
                        backed = section_bytes(mach, address, 16, b'__picsymbolstub4')
                    if backed is None: raise ValueError('Unbacked staging call')
                elif not mac and key.startswith('pointer_'):
                    ins = instruction(match, key)
                    top = key in ('pointer_1e', 'pointer_8e', 'pointer_2a', 'pointer_58', 'pointer_6c')
                    if ins.mnemonic != ('movt' if top else 'movw') or len(ins.operands) != 2 or ins.reg_name(ins.operands[0].reg) != 'r0' or ins.operands[1].type != 2:
                        raise ValueError('Unsupported staging pointer instruction')
                elif not mac and key.startswith('literal_'):
                    ins = instruction(match, key)
                    if ins.mnemonic != 'ldr.w' or len(ins.operands) != 2 or ins.reg_name(ins.operands[0].reg) != 'r1' or ins.operands[1].type != 3 or ins.reg_name(ins.operands[1].mem.base) != 'pc':
                        raise ValueError('Unsupported staging literal instruction')
        for vector in [initial_player, initial_camera, player, camera, *positions]:
            if any(not math.isfinite(v) or abs(v) > 10000000 for v in vector): raise ValueError('Invalid opening coordinates')
        # These orientations, actor indices, boolean states and the event index are
        # literal operands in the matched declarations, not filename assumptions.
        return {'initial': {'player_position': initial_player, 'player_forward': [0, 0, 1],
                            'player_up': [0, 1, 0], 'camera_position_parameter': initial_camera,
                            'hidden_actor_ids': [0, 1, 2]},
                'formation': {'after_event_finished': 2, 'player_position': player,
                              'camera_position_parameter': camera,
                              'actors': [{'actor_id': i, 'position': p, 'forward': [1, 0, 0], 'up': [0, 1, 0], 'visible': True} for i, p in enumerate(positions)]},
                'provenance': provenance}
    except (ValueError, KeyError, IndexError, struct.error, OverflowError):
        return {}
