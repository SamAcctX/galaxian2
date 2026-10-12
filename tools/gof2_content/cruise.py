"""Recover the ordinary forward cruise scalar from bounded declaration layouts.

Constructor and reset values must agree, and a matching displacement consumer
must call the supported forward-transform helper. No boost/steering logic is
emitted. Milliseconds and local +Z are verified semantics of these layouts.
"""
import math
import re
import struct

from .ship_models import section_bytes


def literal(value):
    return re.escape(bytes.fromhex(value))


def extract_cruise(mach):
    if mach.architecture == 'android-armv7':
        return android_cruise(mach)
    section = mach.text
    code = mach.data[section['offset']:section['offset'] + section['length']]
    base = section['address']
    origin = section['offset'] + mach.slice_offset
    if mach.architecture == 'x86_64':
        initial = literal('c783f8000000') + rb'(.{4})' + literal('4c8d35') + rb'.{4}' + literal('c783fc000000') + rb'(.{4})'
        reset = literal('554889e55350c787f8000000') + rb'(.{4})' + literal('c6878c01000000')
        step = literal('f3410f2a8d84010000f3410f598dfc000000f3410f1085f8000000f30f59c1498b7d10e8') + rb'(.{4})'
        helper = literal('554889e54156534881ec80000000f30f1145804889fb8b7314488b7b38e8') + rb'.{4}' + literal('4889c7e8') + rb'(.{4})'
        forward_getter = bytes.fromhex('554889e54883ec3048897de8f30f104708f30f104f18f30f105728')
    elif mach.architecture == 'armv7':
        import capstone
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        decoder.detail = True
        initial = rb'(.{4})' + literal('d1f800a0') + rb'(.{4})' + literal('c4f8b810c4f8bc00')
        reset = literal('90b5') + rb'.{4}(.{4}).{4}' + literal('c0f8b820794401af0c68002180f83811')
        step = literal('98ed4c0a98ed2f2afbff000698ed2e1ad8f8080040ff920d00ff910d10ee101a') + rb'(.{4})'
        helper = literal('f0b503af2ded028b99b004460d46e168e06a') + rb'.{4}' + literal('04ae01463046') + rb'(.{4})'
        forward_getter = bytes.fromhex('80b56f4682b00191019991ed020a019991ed062a019991ed0a4a10ee101a12ee102a14ee103a')
    else:
        return {}

    def matches(pattern):
        return [m for m in re.finditer(pattern, code, re.S)
                if mach.architecture == 'x86_64' or m.start() % 2 == 0]

    starts, resets, steps = matches(initial), matches(reset), matches(step)
    if len(starts) != 1 or len(resets) != 1 or len(steps) != 1:
        return {}
    start, restore, consume = starts[0], resets[0], steps[0]
    if mach.architecture == 'x86_64':
        value = struct.unpack('<f', start[1])[0]
        default_throttle = struct.unpack('<f', start[2])[0]
        restored = struct.unpack('<f', restore[1])[0]
        target = base + consume.end() + struct.unpack('<i', consume[1])[0]
    else:
        def immediate(match, group, register):
            ins = list(decoder.disasm(match[group], base + match.start(group)))
            if len(ins) != 1 or ins[0].mnemonic != 'mov.w' or ins[0].op_str.split(',')[0] != register \
                    or len(ins[0].operands) != 2 or ins[0].operands[1].type != capstone.arm.ARM_OP_IMM:
                return None
            return struct.unpack('<f', struct.pack('<I', ins[0].operands[1].imm & 0xffffffff))[0]
        default_throttle = immediate(start, 1, 'r0')
        value = immediate(start, 2, 'r1')
        restored = immediate(restore, 1, 'r2')
        branch = list(decoder.disasm(consume[1], base + consume.start(1)))
        if len(branch) != 1 or branch[0].mnemonic != 'bl':
            return {}
        target = branch[0].operands[0].imm
    if value is None or not math.isfinite(value) or not 0 < value <= 1000 \
            or value != restored or default_throttle != 1.0:
        return {}
    # Restrict the destination to file-backed text. The helper's verified layout
    # obtains the local third matrix column before normalizing and translating.
    target_data = section_bytes(mach, target, 64, b'__text')
    if target_data is None:
        return {}
    helper_match = re.match(helper, target_data[0], re.S)
    if helper_match is None:
        return {}
    if mach.architecture == 'x86_64':
        getter_address = target + helper_match.end() + struct.unpack('<i', helper_match[1])[0]
    else:
        branch = list(decoder.disasm(helper_match[1], target + helper_match.start(1)))
        if len(branch) != 1 or branch[0].mnemonic != 'bl':
            return {}
        getter_address = branch[0].operands[0].imm
    getter = section_bytes(mach, getter_address, len(forward_getter), b'__text')
    if getter is None or getter[0] != forward_getter:
        return {}
    return {'speed_units_per_millisecond': value, 'forward_axis': [0, 0, 1],
            'provenance': [{'offset': origin + m.start(), 'bytes': len(m[0])}
                           for m in (start, restore, consume)]
                          + [{'offset': target_data[1], 'bytes': len(helper_match[0])},
                             {'offset': getter[1], 'bytes': len(forward_getter)}]}


def android_cruise(lib):
    """The player's constructor declares speed and full throttle side by side,
    `stopBoost` restores the same speed, `updateManeuver` moves forward by
    elapsed ms x throttle x speed, and the move helper takes the local +Z column."""
    from capstone.arm_const import ARM_OP_IMM, ARM_OP_MEM, ARM_OP_REG
    from .android_library import callee, instructions
    constructor = instructions(lib, '_ZN9PlayerEgoC2EP6Player')
    reset = instructions(lib, '_ZN9PlayerEgo9stopBoostEv')
    consumer = instructions(lib, '_ZN9PlayerEgo14updateManeuverEv')
    helper = instructions(lib, '_ZN10AEGeometry11moveForwardEf')
    getter = instructions(lib, '_ZN11AbyssEngine6AEMath12MatrixGetDirERKNS0_6MatrixE')
    if not all((constructor, reset, consumer, helper, getter)):
        return {}

    def floats(code):
        """Each store of mov.w float immediates: (store index, field, [values], [load indexes])."""
        known, found = {}, []
        for index, ins in enumerate(code):
            ops = ins.operands
            if ins.mnemonic == 'mov.w' and len(ops) == 2 and ops[1].type == ARM_OP_IMM:
                known[ops[0].reg] = (struct.unpack('<f', struct.pack('<I', ops[1].imm & 0xffffffff))[0], index)
                continue
            if ins.mnemonic in ('str.w', 'strd') and ops[-1].type == ARM_OP_MEM and all(op.type == ARM_OP_REG for op in ops[:-1]):
                if all(op.reg in known for op in ops[:-1]):
                    found.append((index, ops[-1].mem.base, ops[-1].mem.disp,
                                  [known[op.reg][0] for op in ops[:-1]], [known[op.reg][1] for op in ops[:-1]]))
            for register in ins.regs_access()[1]:
                known.pop(register, None)
        return found

    def span(code, first, last):
        start = code[first].address
        return {'offset': lib.text['offset'] + start - lib.text['address'], 'bytes': code[last].address + code[last].size - start}

    pairs = [row for row in floats(constructor) if len(row[3]) == 2 and row[3][1] == 1.0]
    if len(pairs) != 1:
        return {}
    store, base, field, (value, default_throttle), loads = pairs[0]
    if not math.isfinite(value) or not 0 < value <= 1000:
        return {}
    restores = [row for row in floats(reset) if row[2] == field and len(row[3]) == 1]
    if len(restores) != 1 or restores[0][3][0] != value:
        return {}
    # vldr [elapsed]; vcvt; vldr [throttle]; ldr r0, [geometry]; vmul; vldr [speed]; vmul; vmov r1; call moveForward
    shape = ['vldr', 'vcvt.f32.s32', 'vldr', 'ldr', 'vmul.f32', 'vldr', 'vmul.f32', 'vmov']
    steps = [i for i in range(len(consumer) - len(shape))
             if [ins.mnemonic for ins in consumer[i:i + len(shape)]] == shape
             and consumer[i + 2].operands[1].mem.disp == field + 4 and consumer[i + 5].operands[1].mem.disp == field
             and callee(lib, consumer[i + 8]) == '_ZN10AEGeometry11moveForwardEf']
    if not steps:
        return {}
    step = steps[0]
    calls = [i for i, ins in enumerate(helper) if callee(lib, ins)]
    getter_calls = [i for i in calls if callee(lib, helper[i]) == '_ZN11AbyssEngine6AEMath12MatrixGetDirERKNS0_6MatrixE']
    # The getter returns the third matrix column (elements 2, 6, 10): local +Z.
    end = next((i for i, ins in enumerate(getter) if ins.mnemonic == 'bx'), None)
    if end is None:
        return {}
    getter = getter[:end + 1]
    columns = sorted(ins.operands[1].mem.disp for ins in getter if ins.mnemonic == 'ldr')
    if len(getter_calls) != 1 or len(calls) < 2 or getter_calls[0] != calls[1] or columns != [8, 24, 40]:
        return {}
    return {'speed_units_per_millisecond': value, 'forward_axis': [0, 0, 1],
            'provenance': [span(constructor, loads[1], loads[1]), span(constructor, loads[0], store),
                           span(reset, restores[0][4][0], restores[0][0]), span(consumer, step, step + 8),
                           span(helper, 0, getter_calls[0]), span(getter, 0, len(getter) - 1)]}
