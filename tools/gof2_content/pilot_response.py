"""Recover constants for the ordinary elapsed-time pilot response path.

This does not recover mouse-capture response, ship/equipment modifiers, input
preferences or special control-state selection. No executable logic is emitted.
"""
import math
import re
import struct
from .steering import PC, code_span, lit, shape_at, pool_float


def quantizer(q, h, negated):
    """q = int(command s16 x gain (pool float) x handling h) / 63 (r1 = 0x82082083); the
    interleaved `vneg.f32 s4` comes after the move when q is s4 itself."""
    body = [('vmul.f32', f'{q}, s16, {q}'), ('vmul.f32', f'{q}, {q}, {h}'), ('vcvt.s32.f32', f'{q}, {q}'), ('vmov', 'r0, ' + q)]
    vneg = [('vneg.f32', 's4, ' + negated)]
    return ([('vldr', f'{q}, {PC}'), ('movw', 'r1, #0x2083'), ('movt', 'r1, #0x8208')] + (body + vneg if q == 's4' else vneg + body)
            + [('smmla', 'r0, r1, r0, r0'), ('asrs', 'r1, r0, #5'), ('add.w', 'r0, r1, r0, lsr #31')])


# bias (pool float) - sensitivity (yaw: options +0x14 or +0x18), x scale (vmov.f32 s12); elapsed r5 x handling / that.
YAW_RAMP = [('vldr', 's6, ' + PC), ('vmov.f32', 's12, #.+'), ('add', 'r0, pc'), ('ldr', r'r0, \[r0\]'), ('add.w', 'r2, r0, #0x18'),
            ('ldrb', r'r1, \[r0, #0x11\]'), ('cmp', 'r1, #0'), ('it', 'ne'), ('addne.w', 'r2, r0, #0x14'), ('vldr', r's10, \[r2\]'),
            ('vcvt.f32.s32', 's8, s8'), ('vsub.f32', 's6, s6, s10'), ('vmul.f32', 's2, s8, s2'), ('vmul.f32', 's6, s6, s12'),
            ('vdiv.f32', 's2, s2, s6')]
# Pitch: the sensitivity is options +0x14, or +0x18 x a per-direction factor (up an immediate, down a pool float).
PITCH_RAMP = [('add', 'r0, pc'), ('ldr', r'r0, \[r0\]'), ('vldr', r's10, \[r0, #0x18\]'), ('vldr', r's8, \[r0, #0x14\]'),
              ('ldrb', r'r0, \[r0, #0x11\]'), ('vmul.f32', 's6, s10, s6'), ('vmov', 's10, r5'), ('cmp', 'r0, #0'), ('it', 'ne'),
              ('vmovne.f32', 's6, s8'), ('vldr', 's8, ' + PC), ('vcvt.f32.s32', 's10, s10'), ('vsub.f32', 's6, s8, s6'),
              ('vmul.f32', 's0, s10, s0'), ('vmul.f32', 's6, s6, s12'), ('vdiv.f32', 's0, s0, s6')]
UP_RAMP = [('vmov.f32', 's6, #.+'), ('vmov.f32', 's12, #.+')] + PITCH_RAMP
DOWN_RAMP = [('vmov.f32', 's12, #.+'), ('vldr', 's6, ' + PC)] + PITCH_RAMP
# symbol: (gain sign, quantizer, ramp, index of the bias load and of the scale in the ramp)
ANDROID_TURNS = {'_ZN9PlayerEgo5rightEif': (-1, quantizer('s4', 's2', 's0'), YAW_RAMP, 0, 1),
                 '_ZN9PlayerEgo4leftEif': (1, quantizer('s0', 's2', 's16'), YAW_RAMP, 0, 1),
                 '_ZN9PlayerEgo2upEif': (-1, quantizer('s2', 's0', 's16'), UP_RAMP, 12, 1),
                 '_ZN9PlayerEgo4downEif': (1, quantizer('s2', 's0', 's0'), DOWN_RAMP, 12, 0)}
ANDROID_UPDATE = '_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi'
# elapsed r8 x handling / +-divisor, added to the pitch or yaw rate.
NEUTRAL = [('vmov', 's2, r8'), ('vcvt.f32.s32', 's2, s2'), ('vldr', r's4, \[sb, #0x154\]'), ('vmul.f32', 's2, s2, s4'),
           ('vldr', 's4, ' + PC), ('vdiv.f32', 's2, s2, s4'), ('vadd.f32', 's0, s0, s2')]


def android_response(lib):
    from .android_library import instructions
    spans, gains, biases, scales = [], [], [], []
    for symbol, (sign, target, ramp, bias, scale) in ANDROID_TURNS.items():
        code = instructions(lib, symbol)
        q, r = shape_at(code, target), shape_at(code, ramp)
        if len(q) != 1 or len(r) != 1:
            return {}
        gain, bias = pool_float(lib, symbol, code[q[0]]), pool_float(lib, symbol, code[r[0] + bias])
        if gain is None or bias is None or gain[1] * sign <= 0:
            return {}
        spans += [code_span(lib, code, q[0], q[0] + len(target) - 1), code_span(lib, code, r[0], r[0] + len(ramp) - 1)]
        gains.append(gain)
        biases.append(bias)
        # A VFP immediate (|value| 0.125-31): the ramp span holds it.
        scales.append(code[r[0] + scale].operands[1].fp)
    code = instructions(lib, ANDROID_UPDATE)
    neutrals = shape_at(code, NEUTRAL)
    if len(neutrals) != 4:
        return {}
    returns = [pool_float(lib, ANDROID_UPDATE, code[i + 4]) for i in neutrals]
    if None in returns:
        return {}
    gain, bias, scale, divisor = abs(gains[0][1]), biases[0][1], scales[0], abs(returns[0][1])
    # Every direction agrees; the four neutral returns differ only in sign.
    if ({abs(v) for _, v in gains} != {gain} or {v for _, v in biases} != {bias} or set(scales) != {scale}
            or {abs(v) for _, v in returns} != {divisor} or min(v for _, v in returns) >= 0 or max(v for _, v in returns) <= 0):
        return {}
    if not 0 < gain <= 1000000 or not 0 < bias <= 10 or not 0 < scale or not 0 < divisor <= 10000:
        return {}
    provenance = spans[0::2] + spans[1::2] + [code_span(lib, code, i, i + len(NEUTRAL) - 1) for i in neutrals]
    provenance += [{'offset': o, 'bytes': 4} for o, _ in gains + biases + returns]
    return {'target_gain': gain, 'target_divisor': 63, 'ramp_bias': bias, 'ramp_scale': scale,
            'neutral_divisor': divisor, 'mode': 'elapsed', 'command_curve': 'signed_square',
            'provenance': provenance}


def extract_pilot_response(mach, rotation):
    if not rotation:
        return {}
    if mach.architecture == 'android-armv7':
        return android_response(mach)
    text = mach.text
    code = mach.data[text['offset']:text['offset'] + text['length']]
    base = text['address']
    mac = mach.architecture == 'x86_64'
    if mac:
        quantizer = lit('f30f100d') + rb'(.{4})' + lit('f30f59c8f30f59cdf30f2cc14863c0f30f1183040300004869c88320088248c1e92001c889c1c1e91fc1f80501c8')
        ramp = lit('f30f1025') + rb'(.{4})' + lit('f30f5c20f30f5925') + rb'(.{4})' + lit('f3410f2adef30f59ddf30f5edc')
        neutral = lit('0f57c9f3410f2accf3410f598ea4010000f30f5e0d') + rb'(.{4})' + lit('0f57d2f30f58c1')
    elif mach.architecture == 'armv7':
        import capstone
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        decoder.detail = True
        quantizer = rb'(.{4})' + lit('42f28301c8f20821b9ff811748ff120d40ff900d84ed961a84ed998abbff202712ee100a94ed9e2a51fb0000411101ebd070')
        ramp = rb'(.{4}).{4}' + lit('45ec305b7844fbff2006') + rb'(.{4})' + lit('006800f1180200ff900d417c002918bf00f1140292ed004a63ef044d04ffb23d80ee030a')
        neutral = lit('46ec306b9bed541afbff2006') + rb'(.{4})' + lit('00ff911d81ee021a00ef010d')
    else:
        return {}
    def matches(pattern):
        return [m for m in re.finditer(pattern, code, re.S) if mac or m.start() % 2 == 0]
    quantizers, ramps, neutrals = matches(quantizer), matches(ramp), matches(neutral)
    # The four signed pitch/yaw return paths must agree on the magnitude.
    if len(quantizers) != 1 or len(ramps) != (2 if mac else 1) or len(neutrals) != 4:
        return {}
    q, r = quantizers[0], ramps[0]
    provenance = []
    for m in [q, *ramps, *neutrals]:
        provenance.append({'offset': mach.slice_offset + text['offset'] + m.start(), 'bytes': len(m[0])})
    def constant(match, group, register=None):
        address = base + match.start(group)
        if mac:
            target = address + 4 + struct.unpack('<i', match[group])[0]
        else:
            ins = list(decoder.disasm(match[group], address))
            if len(ins) != 1 or ins[0].mnemonic != 'vldr' or len(ins[0].operands) != 2 \
                    or ins[0].op_str.split(',')[0] != register \
                    or ins[0].operands[1].type != capstone.arm.ARM_OP_MEM \
                    or ins[0].operands[1].mem.base != capstone.arm.ARM_REG_PC:
                return None
            target = ((address + 4) & ~3) + ins[0].operands[1].mem.disp
        sections = [s for s in mach.sections if s['segment'] == b'__TEXT' and s['offset'] > 0
                    and s['address'] <= target and target + 4 <= s['address'] + s['length']]
        if len(sections) != 1:
            return None
        s = sections[0]; offset = s['offset'] + target - s['address']
        if offset + 4 > len(mach.data): return None
        value = struct.unpack_from('<f', mach.data, offset)[0]
        if not math.isfinite(value): return None
        provenance.append({'offset': offset + mach.slice_offset, 'bytes': 4})
        return value
    gain = constant(q, 1, 's4')
    bias = constant(r, 1, 's6')
    if mac:
        scale = constant(r, 2)
        if constant(ramps[1], 1) != bias or constant(ramps[1], 2) != scale:
            return {}
    else:
        ins = list(decoder.disasm(r[2], base + r.start(2)))
        if len(ins) != 1 or ins[0].mnemonic != 'vmov.f32' or ins[0].op_str.split(',')[0] != 'd18' \
                or len(ins[0].operands) != 2 or ins[0].operands[1].type != capstone.arm.ARM_OP_FP:
            return {}
        scale = ins[0].operands[1].fp
        provenance.append({'offset': mach.slice_offset + text['offset'] + r.start(2), 'bytes': 4})
    returns = [constant(n, 1, 's4') for n in neutrals]
    if gain is None or bias is None or scale is None or any(v is None for v in returns): return {}
    if not -1000000 <= gain < 0 or not 0 < bias <= 10 or not 0 < scale <= 10000: return {}
    if not all(0 < abs(v) <= 10000 for v in returns) or len({abs(v) for v in returns}) != 1 \
            or not any(v < 0 for v in returns) or not any(v > 0 for v in returns):
        return {}
    # The recognized signed integer-division template encodes division by 63.
    return {'target_gain': -gain, 'target_divisor': 63, 'ramp_bias': bias, 'ramp_scale': scale,
            'neutral_divisor': abs(returns[0]), 'mode': 'elapsed', 'command_curve': 'signed_square',
            'provenance': provenance}
