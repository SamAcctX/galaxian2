"""Import edition-local scenery effect pairs and the fresh scale/speed rule.

Recognizes bounded constructor and setter layouts, not executable behavior. The
native clock owns time and lifecycle; AEM readers own authored animation ranges.
Only identifiers, numeric declarations and source extents leave this reader.

Android: Level::createAsteroids builds each PlayerAsteroid with the model and
kind of the scenery_resources model lookup; the constructor creates
Explosion(kind + 2) and calls Explosion::setScaling(scale). Explosion's tbh
switch sends type 2 to the ordinary pair and types 3-5 to the void, ice and
magma pairs; setScaling sets Transform::SetAnimationSpeed.
"""
import re
import struct
from .opening_loadout import template
from .ship_models import section_bytes
from .scenery_population import import_symbol


def extract_scenery_effects(mach, resources):
    if mach.architecture == 'android-armv7':
        ids = (resources or {}).get('model_ids', [])
        return android_effects(mach, ids) if len(set(ids)) == 4 else {}
    if not resources or mach.architecture not in ('x86_64', 'armv7'):
        return {}
    import capstone
    mac = mach.architecture == 'x86_64'
    prefix = 'MAC_' if mac else 'ARM_'
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    decoder.detail = True
    text = mach.text
    code = mach.data[text['offset']:text['offset'] + text['length']]
    file_base = mach.slice_offset + text['offset']
    base = text['address']
    proof = {}

    def require(condition):
        if not condition:
            raise ValueError('Unsupported scenery effect declaration layout')

    def instruction(match, key, at):
        rows = list(decoder.disasm(match[key], at + match.start(key)))
        require(len(rows) == 1 and rows[0].size == len(match[key]))
        return rows[0]

    def check_fields(match, at):
        if mac:
            return
        for key in match.groupdict():
            ins = instruction(match, key, at)
            if key.startswith(('bl_', 'blx_')):
                require(ins.mnemonic == key.split('_')[0] and ins.operands[0].type == capstone.arm.ARM_OP_IMM)
            elif key.startswith('branch_'):
                require(ins.mnemonic.replace('.', '_') == key[7:].rsplit('_', 1)[0] and ins.operands[0].type == capstone.arm.ARM_OP_IMM)
            elif key.startswith(('movw_', 'movt_')):
                mnemonic, register, _ = key.split('_')
                require(ins.mnemonic == mnemonic and ins.reg_name(ins.operands[0].reg) == register)
            elif key.startswith('model'):
                require(ins.mnemonic == 'movw' and ins.reg_name(ins.operands[0].reg) == 'r1')
            else:
                register = {'threshold': 'd8', 'speed_base': 'd16', 'speed_scale': 'd18'}[key]
                require(ins.mnemonic == 'vmov.f32' and ins.reg_name(ins.operands[0].reg) == register and ins.operands[1].type == capstone.arm.ARM_OP_FP)

    def target(match, key, at):
        if mac:
            return at + match.end(key) + int.from_bytes(match[key], 'little', signed=True)
        return instruction(match, key, at).operands[0].imm

    def read(key, at):
        spec = globals()[prefix + key.upper()]
        size = sum(int(token.split(':')[1][:-1]) if token.startswith('{') else len(bytes.fromhex(token)) for token in spec.split())
        row = section_bytes(mach, at, size, b'__text')
        require(row is not None and len(row[0]) == size)
        match = template(spec).fullmatch(row[0])
        require(match is not None)
        check_fields(match, at)
        proof[key] = {'offset': row[1], 'bytes': size}
        return match

    def extent(key, at, size, section):
        row = section_bytes(mach, at, size, section)
        require(row is not None and len(row[0]) == size)
        proof[key] = {'offset': row[1], 'bytes': size}
        return row[0]

    try:
        ids = resources['model_ids']
        require(isinstance(ids, list) and len(ids) == 4 and len(set(ids)) == 4 and all(type(v) is int and 0 <= v <= 65535 for v in ids))
        origin = resources['provenance']['models']
        low = origin['offset'] + origin['bytes'] - file_base
        require(0 <= low < len(code))
        matches = [m for m in template(globals()[prefix + 'OUTER']).finditer(code, low, min(len(code), low + 4096 - origin['bytes'])) if mac or m.start() % 2 == 0]
        require(len(matches) == 1)
        outer_at = base + matches[0].start()
        outer = read('outer', outer_at)
        wrapper_at = target(outer, 'call_39' if mac else 'bl_26', outer_at)
        wrapper = read('actor_wrapper', wrapper_at)
        actor_at = target(wrapper, 'branch_5' if mac else 'bl_26', wrapper_at)
        actor = read('actor', actor_at)
        wrapper_at = target(actor, 'call_19b' if mac else 'bl_1ba', actor_at)
        wrapper = read('effect_wrapper', wrapper_at)
        constructor_at = target(wrapper, 'branch_5' if mac else 'bl_6', wrapper_at)
        constructor = read('constructor', constructor_at)
        switch_at = target(constructor, 'ref_9d', constructor_at) if mac else constructor_at + 136
        raw = extent('switch', switch_at, 52 if mac else 26, b'__text')
        table = struct.unpack('<13i' if mac else '<13H', raw)
        branches = [switch_at + table[index] * (1 if mac else 2) for index in range(2, 6)]
        require(branches[0] == target(constructor, 'branch_94' if mac else 'branch_bhi_82', constructor_at))
        default = read('default', branches[0])
        ordinary_at = target(default, 'branch_1b' if mac else 'branch_bne_22', branches[0])
        locations = [ordinary_at] + branches[1:]
        variants = []
        model_calls = []
        for index, (key, at) in enumerate(zip(('ordinary', 'void', 'ice', 'magma'), locations)):
            match = read(key, at)
            models = [int.from_bytes(match[name], 'little') if mac else instruction(match, name, at).operands[1].imm for name in ('model0', 'model1')]
            require(all(0 <= value <= 65535 for value in models) and models[0] != models[1])
            calls = ('call_a', 'call_34') if mac and index == 0 else ('call_21', 'call_4b') if mac else ('bl_c', 'bl_34') if index == 0 else ('bl_2c', 'bl_54')
            model_calls.extend(target(match, name, at) for name in calls)
            if mac and index != 1:
                require(target(match, 'branch_39' if index == 0 else 'branch_50', at) == branches[1] + 80)
            if not mac and index:
                require(target(match, 'branch_b_5a', at) == ordinary_at + 58)
            variants.append({'base_model_id': ids[index], 'effect_type': index + 2, 'model_ids': models})
        require(len(set(model_calls)) == 1)
        scale_at = target(actor, 'call_1b0' if mac else 'bl_1d0', actor_at)
        scale = read('scale', scale_at)
        calls = ('call_d7', 'call_ff', 'call_136') if mac else ('bl_c4', 'bl_d8', 'bl_fc')
        setters = [target(scale, key, scale_at) for key in calls]
        require(len(set(setters)) == 1)
        read('speed_setter', setters[0])
        if mac:
            threshold_at = target(scale, 'ref_45', scale_at)
            require(threshold_at == target(scale, 'ref_53', scale_at))
            threshold = struct.unpack('<f', extent('threshold', threshold_at, 4, b'__const'))[0]
            speed_base = threshold
            speed_scale = struct.unpack('<f', extent('speed_scale', target(scale, 'ref_63', scale_at), 4, b'__const'))[0]
        else:
            threshold, speed_base, speed_scale = [instruction(scale, key, scale_at).operands[1].fp for key in ('threshold', 'speed_base', 'speed_scale')]
            require(import_symbol(mach, target(scale, 'blx_110', scale_at)) == b'___floatdisf')
            require(import_symbol(mach, target(scale, 'blx_120', scale_at)) == b'___fixsfdi')
        require((threshold, speed_base, speed_scale) == (1.0, 1.0, 3.0))
        spans = sorted((row['offset'], row['offset'] + row['bytes']) for row in proof.values())
        require(all(a[1] <= b[0] for a, b in zip(spans, spans[1:])))
        return {'variants': variants, 'speed_threshold': threshold, 'speed_base': speed_base, 'speed_scale': speed_scale, 'provenance': proof}
    except (ValueError, TypeError, KeyError, IndexError, OverflowError, struct.error):
        return {}


# Android: the PlayerAsteroid and Explosion constructors have no wrapper (C1 = C2)
# and setScaling's speed constants are VFP immediates: no wrapper or constant spans.
# The model lookup (scenery_resources) keeps its kind and model in two stack slots...
ANDROID_KIND = r"""ands r0, r4
str (?P=kind), \[sp, #(?P<kind_slot>\w+)\]
add r4, sp, #0x68
str r1, \[sp, #(?P<model_slot>\w+)\]
"""
# ...that the asteroid constructor receives as its first (model) and third (kind) ints.
ANDROID_OUTER = r"""mov\.w r0, #0x16c
call _Znwj
mov (?P<object>\w+), r0
add r0, sp, #\w+
ldr r1, \[sp, #(?P<model_slot>\w+)\]
ldr r3, \[sp, #(?P<kind_slot>\w+)\]
mov r2, \w+
str \w+, \[sp, #0xc\]
vstr s\d+, \[sp, #8\]
str r0, \[sp, #4\]
ldr r0, \[sp, #\w+\]
str r0, \[sp\]
mov r0, (?P=object)
call _ZN14PlayerAsteroidC1EiP10AEGeometryiiRKN11AbyssEngine6AEMath6VectorEfi
"""
ACTOR = '_ZN14PlayerAsteroidC1EiP10AEGeometryiiRKN11AbyssEngine6AEMath6VectorEfi'
# PlayerAsteroid: Explosion(kind + 2), then Explosion::setScaling(scale).
ANDROID_ACTOR = r"""movs r0, #0x68
call _Znwj
mov (?P<effect>\w+), r0
add\.w r1, (?P<kind>\w+), #2
mov r0, (?P=effect)
call _ZN9ExplosionC1Ei
vmov (?P<scaling>\w+), (?P<scale>s\d+)
str\.w (?P=effect), \[r4, #0x128\]
mov r0, (?P=effect)
mov r1, (?P=scaling)
call _ZN9Explosion10setScalingEf
"""
EXPLOSION = '_ZN9ExplosionC1Ei'
# Explosion(type): types above 12 to the default block, else a 13-entry tbh table.
ANDROID_CONSTRUCTOR = r"""push \{r4, r5, r6, r7, lr\}
add r7, sp, #0xc
sub sp, #4
vmov\.i32 q9, #0
mov r6, r1
mov r4, r0
addw r0, pc, #\w+
add\.w r1, r4, #0x30
vld1\.64 \{d16, d17\}, \[r0:0x80\]
mov\.w r0, #0x3f800000
cmp r6, #0xc
str r0, \[r4, #0x2c\]
vst1\.32 \{d18, d19\}, \[r1\]
add\.w r1, r4, #0x44
str r0, \[r4, #0x40\]
vst1\.32 \{d18, d19\}, \[r1\]
add\.w r1, r4, #0x54
vst1\.32 \{d16, d17\}, \[r1\]
str r0, \[r4, #0x64\]
str r0, \[r4, #0x24\]
mov\.w r0, #0
strd r0, r0, \[r4, #8\]
strd r6, r0, \[r4\]
bhi #(?P<default>\w+)
tbh \[pc, r6, lsl #1\]
"""
# Each geometry: new AEGeometry(model, canvas); the first goes to this+4, the second to this+8.
NEW = 'movs r0, #0xc0\ncall _Znwj\nmov r5, r0\n'
CANVAS = 'ldr r0, =\\w+\nadr r0, \\w+\nldr r0, \\[r0\\]\nldr r2, \\[r0\\]\n'
GEOMETRY = 'mov r0, r5\nmovw r1, #(?P<model%d>\\w+)\nmovs r3, #0\ncall _ZN10AEGeometryC1EtPN11AbyssEngine11PaintCanvasEb\n'
SECOND = 'movs r0, #0xc0\nstr r5, \\[r4, #4\\]\ncall _Znwj\nmov r5, r0\n' + CANVAS + GEOMETRY % 1
# Type 2 and types above 13: the ordinary pair.
ANDROID_DEFAULT = NEW + r"""ldr r0, =\w+
cmp r6, #0xd
adr r0, \w+
ldr r0, \[r0\]
ldr r2, \[r0\]
bne\.w #(?P<ordinary>\w+)
"""
ANDROID_ORDINARY = GEOMETRY % 0 + SECOND + 'str r5, \\[r4, #8\\]\n'
ANDROID_VARIANT = NEW + CANVAS + GEOMETRY % 0 + SECOND + 'b #(?P<join>\\w+)\n'
# speed = 1.0, or (1.0 - scale) * 3.0 + 1.0 below scale 1.0; type 11 halves it and
# types 8-10 draw it; the remaining duration is divided by it.
ANDROID_SCALE = r"""push\.w \{r4, r5, r6, r7, r8, lr\}
add r7, sp, #0xc
vpush \{d8, d9\}
mov r5, r1
mov r8, r0
str\.w r5, \[r8, #0x24\]
mov r2, r5
ldr\.w r0, \[r8, #4\]
mov r3, r5
call _ZN10AEGeometry10setScalingEfff
ldr\.w r0, \[r8, #8\]
vmov s18, r5
cbz r0, #@0x32
mov r1, r5
mov r2, r5
mov r3, r5
call _ZN10AEGeometry10setScalingEfff
vmov\.f32 s16, #(?P<threshold>\S+)
vcmpe\.f32 s18, s16
vmrs apsr_nzcv, fpscr
bpl #@0x54
vmov\.f32 s0, #(?P<speed_base>\S+)
vmov\.f32 s2, #(?P<speed_scale>\S+)
vsub\.f32 s4, s0, s18
vmul\.f32 s2, s4, s2
vadd\.f32 s16, s2, s0
vmov\.f32 s0, #5\.000000e\-01
ldr\.w r0, \[r8\]
cmp r0, #0xb
sub\.w r0, r0, #8
vmul\.f32 s0, s16, s0
it eq
vmoveq\.f32 s16, s0
cmp r0, #2
bhi #@0x96
ldr r0, =\w+
movs r1, #0x3c
adr r0, \w+
ldr r0, \[r0\]
ldr r0, \[r0\]
call _ZN11AbyssEngine8AERandom7nextIntEi
vmov s0, r0
vldr s2, =0x3c23d70a
vcvt\.f32\.s32 s0, s0
vmul\.f32 s0, s0, s2
vldr s2, =0x3f333333
vadd\.f32 s16, s0, s2
ldr r0, =\w+
ldr\.w r1, \[r8, #4\]
adr r0, \w+
ldr r0, \[r0\]
ldr r1, \[r1, #0xc\]
ldr r0, \[r0\]
call _ZN11AbyssEngine11PaintCanvas21TransformGetTransformEj
vmov r5, s16
mov r1, r5
call _ZN11AbyssEngine9Transform17SetAnimationSpeedEf
ldr\.w r0, \[r8, #8\]
cbz r0, #@0xcc
ldr r1, =\w+
adr r1, \w+
ldr r2, \[r1\]
ldr r1, \[r0, #0xc\]
ldr r0, \[r2\]
call _ZN11AbyssEngine11PaintCanvas21TransformGetTransformEj
mov r1, r5
call _ZN11AbyssEngine9Transform17SetAnimationSpeedEf
ldr\.w r0, \[r8, #0xc\]
cbz r0, #@0xfe
ldr r1, \[r0\]
cbz r1, #@0xfe
ldr r1, =\w+
movs r6, #0
adr r1, \w+
ldr r4, \[r1\]
ldr r0, \[r0, #4\]
ldr\.w r0, \[r0, r6, lsl #2\]
ldr r1, \[r0, #0xc\]
ldr r0, \[r4\]
call _ZN11AbyssEngine11PaintCanvas21TransformGetTransformEj
mov r1, r5
call _ZN11AbyssEngine9Transform17SetAnimationSpeedEf
ldr\.w r0, \[r8, #0xc\]
adds r6, #1
ldr r1, \[r0\]
cmp r6, r1
blo #@0xde
ldrd r0, r1, \[r8, #0x10\]
call __aeabi_l2f
vmov s0, r0
vdiv\.f32 s0, s0, s16
vmov r0, s0
call __aeabi_f2lz
strd r0, r1, \[r8, #0x10\]
vpop \{d8, d9\}
pop\.w \{r4, r5, r6, r7, r8, pc\}
"""
# Transform::SetAnimationSpeed stores the speed.
ANDROID_SPEED_SETTER = r"""str\.w r1, \[r0, #0xf0\]
bx lr
"""


def android_effects(lib, ids):
    from .android_listing import Listing, number
    from .scenery_population import android_body
    from .scenery_resources import ANDROID_MODELS
    scene, actor, explosion = Listing(lib, '_ZN5Level15createAsteroidsEv'), Listing(lib, ACTOR), Listing(lib, EXPLOSION)
    kinds, outers, effects = scene.find(ANDROID_MODELS + ANDROID_KIND), scene.find(ANDROID_OUTER), actor.find(ANDROID_ACTOR)
    constructor = re.match(ANDROID_CONSTRUCTOR, explosion.text)
    if (len(kinds) != 1 or len(outers) != 1 or len(effects) != 1 or not constructor
            or (kinds[0]['kind_slot'], kinds[0]['model_slot']) != (outers[0]['kind_slot'], outers[0]['model_slot'])
            or not re.match(r'push\.w \{r4, r5, r6, r7, r8, sb, sl, fp, lr\}\nadd r7, sp, #0xc\n', actor.text)):
        return {}
    effect = effects[0]
    # The kind is the third int argument (r3) and the scale the float on the stack (r7 + 0x20).
    kind = actor.definition(actor.index(effect, 'kind'), effect['kind'])
    scale = actor.definition(actor.index(effect, 'scaling'), effect['scale'])
    if (kind is None or actor.lines[kind] != 'mov %s, r3' % effect['kind']
            or scale is None or actor.lines[scale] != 'vldr %s, [r7, #0x20]' % effect['scale']):
        return {}
    last = explosion.last(constructor)
    table_at = explosion.code[last].address + 4
    table = lib.text['offset'] + table_at - lib.text['address']
    cases = [table_at + 2 * entry for entry in struct.unpack_from('<13H', lib.data, table)]

    def block(address, shape):
        """The shape matched from the instruction at `address`: (match, span, address of its last line)."""
        index = explosion.at(address)
        match = re.match(shape, explosion.text[explosion.starts[index]:]) if index is not None else None
        if not match:
            return None, None, None
        last = index + match[0].count('\n') - 1
        return match, explosion.span(index, last), explosion.code[last].address
    default, default_span, _ = block(cases[2], ANDROID_DEFAULT)
    if number(constructor['default']) != cases[2] or not default:
        return {}
    blocks = [block(number(default['ordinary']), ANDROID_ORDINARY)] + [block(at, ANDROID_VARIANT) for at in cases[3:6]]
    # void, ice and magma store their second geometry through the ordinary pair's last store.
    if not all(match for match, _, _ in blocks) or any(number(match['join']) != blocks[0][2] for match, _, _ in blocks[1:]):
        return {}
    variants = []
    for index, (match, _, _) in enumerate(blocks):
        models = [number(match['model0']), number(match['model1'])]
        if models[0] == models[1]:
            return {}
        variants.append({'base_model_id': ids[index], 'effect_type': index + 2, 'model_ids': models})
    scaled, scaled_listing = android_body(lib, '_ZN9Explosion10setScalingEf', ANDROID_SCALE)
    setter, setter_listing = android_body(lib, '_ZN11AbyssEngine9Transform17SetAnimationSpeedEf', ANDROID_SPEED_SETTER)
    if not scaled or not setter:
        return {}
    threshold, speed_base, speed_scale = (number(scaled[key]) for key in ('threshold', 'speed_base', 'speed_scale'))
    if (threshold, speed_base, speed_scale) != (1.0, 1.0, 3.0):
        return {}
    proof = {'outer': scene.match_span(outers[0]), 'actor': actor.span(0, actor.last(effect)),
             'constructor': explosion.span(0, last), 'switch': {'offset': table, 'bytes': 26}, 'default': default_span}
    proof.update(zip(('ordinary', 'void', 'ice', 'magma'), (span for _, span, _ in blocks)))
    proof['scale'] = scaled_listing.span(0, scaled_listing.last(scaled))
    proof['speed_setter'] = setter_listing.span(0, setter_listing.last(setter))
    return {'variants': variants, 'speed_threshold': threshold, 'speed_base': speed_base, 'speed_scale': speed_scale, 'provenance': proof}


# Compiler-layout recognizers. Captures are relocation operands or declarations;
# templates are import-time guards and are never copied to content packs.
MAC_OUTER = 'bfc8010000e8 {call_5:4} 4989c5891c244c89ef4489f6488b9550ffffff8b8d10ffffff448bb514ffffff4589f04c8d4db0f30f108544ffffffe8 {call_39:4}'
MAC_ACTOR_WRAPPER = '554889e55de9 {branch_5:4}'
MAC_ACTOR = '554889e54157415641554154534883ec48f30f1145a44c89cb44894590894d944989d64189f54989fcbf28010000e8 {call_2e:4} 4989c74c89ffbedc050000ba1e00000031c94531c04531c9e8 {call_4b:4} f30f105308f30f1003f30f104b0448895d984c89e74489eebaffffffff4c89f94d89f04531c9e8 {call_76:4} 488d05 {ref_7b:4} 4989042441c78424900100000000000041c78424940100000000000041c78424980100000000000041c78424bc0100000000000041c78424c00100000000000041c78424c401000000000000498b7c24084c89e6e8 {call_d6:4} 448b7d108b4590418984247401000041c684247001000000f30f1045a4f3410f118424880100004589bc24a0010000498b5c2408418b7614488d05 {ref_113:4} 488b38e8 {call_11d:4} f30f108000010000f30f5945a4f30f5905 {ref_12f:4} f30f2cf04889dfe8 {call_13e:4} 498b7c2408f30f1005 {ref_148:4} f30f5945a4f30f5805 {ref_155:4} f30f2cf0e8 {call_161:4} 498b7c2408e8 {call_16b:4} 41898424b00100004183ff03410f9f84248c010000bf78000000e8 {call_18a:4} 4889c38b759483c6024889dfe8 {call_19b:4} 49899c24780100004889dff30f1045a4e8 {call_1b0:4}'
MAC_EFFECT_WRAPPER = '554889e55de9 {branch_5:4}'
MAC_CONSTRUCTOR = '554889e5415741564154534189f74989fe41c7463c0000803f49c746480000000049c746400000000041c746500000803f49c7465c0000000049c746540000000041c746640000803f41c746680000000041c7466c0000803f4d8d66084183ff0c41c746700000803f41c746740000803f41c746340000803f49c746180000000049c746100000000049c746080000000045893e0f87 {branch_94:4} 4489f8488d0d {ref_9d:4} 486304814801c8ffe0'
MAC_DEFAULT = 'bfe8000000e8 {call_5:4} 4889c3488d05 {ref_d:4} 488b104183ff0d75 {branch_1b:1}'
MAC_ORDINARY = '4889dfbe {model0:4} 31c9e8 {call_a:4} 49891c24bfe8000000e8 {call_18:4} 4889c3488d05 {ref_20:4} 488b104889dfbe {model1:4} 31c9e8 {call_34:4} e9 {branch_39:4}'
MAC_VOID = 'bfe8000000e8 {call_5:4} 4889c3488d05 {ref_d:4} 488b104889dfbe {model0:4} 31c9e8 {call_21:4} 49891c24bfe8000000e8 {call_2f:4} 4889c3488d05 {ref_37:4} 488b104889dfbe {model1:4} 31c9e8 {call_4b:4} 49895e10e9 {branch_54:4}'
MAC_ICE = 'bfe8000000e8 {call_5:4} 4889c3488d05 {ref_d:4} 488b104889dfbe {model0:4} 31c9e8 {call_21:4} 49891c24bfe8000000e8 {call_2f:4} 4889c3488d05 {ref_37:4} 488b104889dfbe {model1:4} 31c9e8 {call_4b:4} eb {branch_50:1}'
MAC_MAGMA = 'bfe8000000e8 {call_5:4} 4889c3488d05 {ref_d:4} 488b104889dfbe {model0:4} 31c9e8 {call_21:4} 49891c24bfe8000000e8 {call_2f:4} 4889c3488d05 {ref_37:4} 488b104889dfbe {model1:4} 31c9e8 {call_4b:4} e9 {branch_50:4}'
MAC_SCALE = '554889e54157415653500f28d0f30f1155e44989fef3410f115634498b7e080f28cae8 {call_22:4} 498b7e104885ff7415f30f1055e4f30f1155e40f28c20f28cae8 {call_40:4} f30f100d {ref_45:4} 0f2e4de4761cf30f1005 {ref_53:4} 0f28c8f30f5c4de4f30f590d {ref_63:4} f30f58c8418b0683f80b750af30f590d {ref_77:4} eb3383c0f883f802772b488d05 {ref_89:4} 488b38be3c000000e8 {call_98:4} 0f57c9f30f2ac8f30f590d {ref_a4:4} f30f580d {ref_ac:4} f30f114de4488d05 {ref_b9:4} 488b38498b46088b7014e8 {call_ca:4} 4889c7f30f1045e4e8 {call_d7:4} 498b46104885c0741f8b7014488d05 {ref_e8:4} 488b38e8 {call_f2:4} 4889c7f30f1045e4e8 {call_ff:4} 498b46184885c07439833800743431db4c8d3d {ref_114:4} 488b4008488b04d88b7014498b3fe8 {call_129:4} 4889c7f30f1045e4e8 {call_136:4} 48ffc3498b46183b1872d5f3490f2a4620f30f5e45e4f3480f2cc0498946204883c4085b415e415f5dc3'
MAC_SPEED_SETTER = '554889e548897df8f30f1145f4488b7df8f30f1045f4f30f1187100100005dc3'
ARM_OUTER = '4ff4b670 {blx_4:4} 05212c902c982e91119b22a9039522468ded029a01915146009620ef1001 {bl_26:4}'
ARM_ACTOR_WRAPPER = '90b501af84b004467869d7f8089097ed040a039020468ded020ad7f80cc08de8001220ef1001 {bl_26:4} 204604b090bd'
ARM_ACTOR = 'f0b503af2de9000dadf1400424f00f04a54604f9ed8204f9efc2a4b014904ff48a7008930a920991 {blx_28:4} {movw_r1_2c:4} dff84424 {movt_r1_34:4} 15907944159c17a87a44096800251d91dff848141e9241f001011f977944cdf884d0209101211891 {blx_60:4} 2046 {movw_r1_66:4} 1e22002300950195 {bl_72:4} f8680025159b4ff0ff32149c90ed000a90ed012a90ed024a4ff0ff30189009990a9804958ded022a8ded034a8ded010a0090204620ef1001 {bl_ae:4} 1498 {movw_r1_b4:4} {movt_r1_b8:4} 794408310160149802210990c0f83c511498c0f840511498c0f844511498c0f860511498c0f864511498c0f868511498406818912146 {bl_f2:4} 1499b86897ed048ac1f82401002114987b6980f820111498 {movw_r1_10e:4} {movt_r1_112:4} 794480ed4d8a14980a68c0f84c31149b0a98c16810685a680a920322189220ef1001 {bl_138:4} 90ed380a04209fedce1a40ff180d189040ff910dbbff200710ee101a0a98 {bl_15a:4} 9fedc80ac3ef1e0f1498052248ff102d4068189242efa00dbbff200710ee101a {bl_17e:4} 1498062140681891 {bl_18a:4} 14997a69c1f8540100211498032ac8bf012180f83811072018906820 {blx_1aa:4} 082116901698189108990231 {bl_1ba:4} 18ee101a0a911698149ac2f8280109221892 {bl_1d0:4}'
ARM_EFFECT_WRAPPER = '90b5044601af {bl_6:4} 204690bd'
ARM_CONSTRUCTOR = 'f0b503af2de9000dadf1400424f00f04a54604f9ed8204f9efc2a0b0c0ef50000546 {movw_r0_22:4} 05f13003 {movt_r0_2a:4} 4ff07e5278440c46dff8c015ea6243f98f0a05f1440379442a6443f98f0a002300686a65ab65ea652a666a666a626b60ab60eb602c60199013a81a91dff890151b9741f00101cdf874d079441c91 {blx_7c:4} 0c2c {branch_bhi_82:2} dfe814f0'
ARM_DEFAULT = '4ff0ff3001951490c020 {blx_a:4} {movw_r1_e:4} 0d2c {movt_r1_14:4} 11907944096800910a68 {branch_bne_22:2}'
ARM_ORDINARY = '122111981491 {model0:4} 0023 {bl_c:4} 1198019948604ff0ff301490c020 {blx_1e:4} 1290129800990a6813211491 {model1:4} 0023 {bl_34:4} 1298019eb060 {branch_b_3e:2}'
ARM_VOID = '4ff0ff3001951490c020 {blx_a:4} {movw_r1_e:4} {movt_r1_12:4} 049079440968009104980a6804211491 {model0:4} 0023 {bl_2c:4} 0498019948604ff0ff301490c020 {blx_3e:4} 0590059800990a6805211491 {model1:4} 0023 {bl_54:4} 0598 {branch_b_5a:2}'
ARM_ICE = '4ff0ff3001951490c020 {blx_a:4} {movw_r1_e:4} {movt_r1_12:4} 069079440968009106980a6806211491 {model0:4} 0023 {bl_2c:4} 0698019948604ff0ff301490c020 {blx_3e:4} 0790079800990a6807211491 {model1:4} 0023 {bl_54:4} 0798 {branch_b_5a:2}'
ARM_MAGMA = '4ff0ff3001951490c020 {blx_a:4} {movw_r1_e:4} {movt_r1_12:4} 089079440968009108980a6808211491 {model0:4} 0023 {bl_2c:4} 0898019948604ff0ff301490c020 {blx_3e:4} 0990099800990a6809211491 {model1:4} 0023 {bl_54:4} 0998 {branch_b_5a:2}'
ARM_SCALE = 'f0b503af4df8048dadf1100424f00f04a5460d46804604f9ef8a2a462b46c8f82450d8f80400 {bl_26:4} d8f8080045ec195b28b119ee101a0a460b46 {bl_3c:4} {threshold:4} b4eec89af1ee10fa09d5 {speed_base:4} {speed_scale:4} 60ef894d44ffb22d02efa08dd8f800000b2804d1c6ef100f08ff308d18e00838022815d8 {movw_r0_7a:4} 3c21 {movt_r0_80:4} 784400680068 {bl_8a:4} 40ec300b9fed2a0afbff20069fed291a40ff900d00ef818d {movw_r0_a6:4} {movt_r0_aa:4} d8f8041078440668c9683068 {bl_ba:4} 18ee105a2946 {bl_c4:4} d8f8080030b1c1683068 {bl_d2:4} 2946 {bl_d8:4} d8f80c0000281cbf0168002910d00024406850f824103068c968 {bl_f6:4} 2946 {bl_fc:4} d8f80c00013401688c42efd3d8e90401 {blx_110:4} 40ec100b80ee080a10ee100a {blx_120:4} c8e904016c4624f9ef8aa7f11004a5465df8048bf0bd'
ARM_SPEED_SETTER = '82b041ec101bb0ee402a01908ded002a01989ded002a80ed3c2a02b07047'
