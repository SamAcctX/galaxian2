"""Read manual angular-unit constants; no input-response logic is exported.

Android: PlayerEgo::handleShip scales both rotation fields by the angle unit,
2 pi, the elapsed milliseconds and the time scale (three literal-pool floats)
and passes them to AEMath::MatrixSetRotation(Matrix&, float, float, float).
"""
import math
import re
import struct
from .ship_models import section_bytes
from .opening_loadout import template

MAC_HELPERS = (
    '554889e54883ec504889f848ba3c00000000000000488975f8f30f1145f4f30f114df0f30f1155ecf30f5a45f4',
    '554889e54883ec404889f8488975f8f30f1145f4f30f114df0f30f1155ecf30f5a45f4',
)


def lit(value):
    return re.escape(bytes.fromhex(value))


def shape_at(code, shape):
    """Indexes where `code` holds the instructions of `shape`: (mnemonic, operand-text regex) pairs."""
    return [i for i in range(len(code) - len(shape) + 1)
            if all(ins.mnemonic == m and re.fullmatch(o, ins.op_str) for ins, (m, o) in zip(code[i:], shape))]


def pool_float(lib, symbol, ins):
    """(file offset, value) of the float a pc-relative vldr loads from the named function's own pool."""
    start, size = lib.symbols[symbol]
    address = ((ins.address + 4) & ~3) + ins.operands[1].mem.disp
    if not start <= address <= start + size - 4:
        return None
    offset = lib.text['offset'] + address - lib.text['address']
    return offset, struct.unpack_from('<f', lib.data, offset)[0]


def code_span(lib, code, first, last):
    """Provenance of code[first..last] inclusive."""
    start = code[first].address
    return {'offset': lib.text['offset'] + start - lib.text['address'], 'bytes': code[last].address + code[last].size - start}


PC = r'\[pc, #-?0x[0-9a-f]+\]'  # a pc-relative literal
ANDROID_HANDLER = '_ZN9PlayerEgo10handleShipEi'
ANDROID_HELPER = '_ZN11AbyssEngine6AEMath17MatrixSetRotationERNS0_6MatrixEfff'
# Both rotation fields x angle unit x 2 pi x elapsed (s16) x time scale -> MatrixSetRotation x, y.
ANDROID_STEP = [('vldr', 's0, ' + PC), ('vldr', r's2, \[fp, #0x278\]'), ('vldr', r's4, \[fp, #0x27c\]'),
                ('vcvt.f32.s32', 's16, s6'), ('vmul.f32', 's2, s2, s0'), ('str.w', r'sb, \[sp\]'), ('vmul.f32', 's0, s4, s0'),
                ('vldr', 's4, ' + PC), ('vmul.f32', 's2, s2, s4'), ('vmul.f32', 's0, s0, s4'),
                ('vldr', 's4, ' + PC), ('vmul.f32', 's2, s16, s2'), ('vmul.f32', 's0, s16, s0'),
                ('vmul.f32', 's2, s2, s4'), ('vmul.f32', 's0, s0, s4'), ('vmov', 'r2, s2'), ('vmov', 'r3, s0'), ('blx', '.*')]


def android_rotation(lib):
    from .android_library import callee, instructions
    code = instructions(lib, ANDROID_HANDLER)
    if not code or ANDROID_HELPER not in lib.symbols:
        return {}
    steps = shape_at(code, ANDROID_STEP)
    if len(steps) != 1 or callee(lib, code[steps[0] + 17]) != ANDROID_HELPER:
        return {}
    step = steps[0]
    constants = [pool_float(lib, ANDROID_HANDLER, code[step + i]) for i in (0, 7, 10)]
    if None in constants:
        return {}
    values = [value for _, value in constants]
    if not all(math.isfinite(v) and v > 0 for v in values) or values[0] > 1 or values[1] > 10 or values[2] > 1:
        return {}
    start, size = lib.symbols[ANDROID_HELPER]
    helper = {'offset': lib.text['offset'] + start - lib.text['address'], 'bytes': size}
    return dict(zip(('angle_unit_scale', 'radians_per_turn', 'time_scale'), values), rotation_order='local_x_y',
                provenance=[code_span(lib, code, step, step + 17)] + [{'offset': o, 'bytes': 4} for o, _ in constants] + [helper])


def extract_manual_rotation(mach, cruise):
    if not cruise:
        return {}
    if mach.architecture == 'android-armv7':
        return android_rotation(mach)
    text = mach.text
    code = mach.data[text['offset']:text['offset'] + text['length']]
    base = text['address']
    if mach.architecture == 'x86_64':
        consumer = lit('f3410f10842414030000f30f59c1f30f59c3f30f59c4f30f59c2f3410f598c2418030000f30f59cbf30f59ccf30f59caf3410f10104c89f6e8') + rb'(.{4})'
        helper = MAC_HELPERS
    elif mach.architecture == 'armv7':
        import capstone
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        decoder.detail = True
        consumer = (rb'(.{4})' + lit('94ed9d1a94ed9e2a') + rb'.{4}' + lit('41ff104d') + rb'.{4}'
                    + lit('42ff102d') + rb'(.{4})' + lit('784444ff900d006842ff902d') + rb'(.{4})'
                    + lit('48ff300d48ff322d00ff901d02ff900d11ee102a10ee103a90ed000a28a88ded000a20ef1001') + rb'(.{4})')
        helper = ('80b56f468eb043ec103bb0ee402a42ec102bb0ee404a97ed026a3c22',)
    else:
        return {}
    matches = [m for m in re.finditer(consumer, code, re.S)
               if mach.architecture == 'x86_64' or m.start() % 2 == 0]
    if len(matches) != 1:
        return {}
    match = matches[0]
    regions = []
    def extent(at, length):
        return {'offset': mach.slice_offset + text['offset'] + at, 'bytes': length}
    if mach.architecture == 'x86_64':
        loads = list(re.finditer(lit('f30f1015') + rb'(.{4})' + lit('f30f101d') + rb'(.{4})' + lit('f30f100d') + rb'(.{4})',
                                 code[max(0, match.start() - 512):match.start()], re.S))
        if len(loads) != 1:
            return {}
        load = loads[0]
        at = max(0, match.start() - 512) + load.start()
        # The three inputs are time scale, radians/turn, then source angle units.
        addresses = [base + at + i * 8 + 8 + struct.unpack('<i', load[i + 1])[0] for i in range(3)]
        addresses.reverse()
        target = base + match.end() + struct.unpack('<i', match[1])[0]
        regions.append(extent(at, len(load[0])))
    else:
        addresses = []
        for group in (1, 2, 3):
            ins = list(decoder.disasm(match[group], base + match.start(group)))
            if len(ins) != 1 or ins[0].mnemonic != 'vldr' or len(ins[0].operands) != 2 \
                    or ins[0].operands[0].reg != capstone.arm.ARM_REG_S0 \
                    or ins[0].operands[1].type != capstone.arm.ARM_OP_MEM \
                    or ins[0].operands[1].mem.base != capstone.arm.ARM_REG_PC:
                return {}
            addresses.append(((ins[0].address + 4) & ~3) + ins[0].operands[1].mem.disp)
        branch = list(decoder.disasm(match[4], base + match.start(4)))
        if len(branch) != 1 or branch[0].mnemonic != 'bl':
            return {}
        target = branch[0].operands[0].imm
    regions.append(extent(match.start(), len(match[0])))
    values = []
    for address in addresses:
        sections = [s for s in mach.sections if s['segment'] == b'__TEXT' and s['offset'] > 0
                    and s['address'] <= address and address + 4 <= s['address'] + s['length']]
        if len(sections) != 1:
            return {}
        s = sections[0]
        offset = s['offset'] + address - s['address']
        if offset + 4 > len(mach.data):
            return {}
        value = struct.unpack_from('<f', mach.data, offset)[0]
        if not math.isfinite(value) or value <= 0:
            return {}
        values.append(value)
        regions.append({'offset': offset + mach.slice_offset, 'bytes': 4})
    if values[0] > 1 or values[1] > 10 or values[2] > 1:
        return {}
    helpers = [found for spec in helper
               if (found := section_bytes(mach, target, len(bytes.fromhex(spec)), b'__text'))
               and template(spec).fullmatch(found[0])]
    if len(helpers) != 1:
        return {}
    found = helpers[0]
    regions.append({'offset': found[1], 'bytes': len(found[0])})
    return dict(zip(('angle_unit_scale', 'radians_per_turn', 'time_scale'), values),
                rotation_order='local_x_y', provenance=regions)
