"""Synthetic ARM shared objects for the Android declaration reader. Never executed.

`Thumb` assembles the few Thumb-2 encodings the registration templates use;
`library` lays out a 32-bit ARM ELF with .dynsym/.dynstr, verified PLT stubs,
.text and .rodata at addresses equal to their file offsets.
"""
import struct

IMPORTS = ('_Znwj', '_Znaj', '__aeabi_memcpy', 'strlen', 'puts')
PLT = 0x1000
TEXT = 0x2000
RODATA = 0x8000
GOT = 0xa000


def stub(name):
    return PLT + 20 + 12 * IMPORTS.index(name)


def branch_fields(offset, link):
    """J1/J2/S fields of a Thumb-2 32-bit branch with an even byte offset."""
    value = offset >> 1
    sign = 1 if offset < 0 else 0
    i1, i2 = value >> 22 & 1, value >> 21 & 1
    j1, j2 = (1 - i1) ^ sign, (1 - i2) ^ sign
    return sign, j1, j2, value


class Thumb:
    def __init__(self, address):
        self.address = address
        self.code = bytearray()
        self.literals = []  # (ldr position, value function of the add address)
        self.fixups = []  # (position, kind, label)
        self.labels = {}

    def here(self):
        return self.address + len(self.code)

    def half(self, *values):
        for value in values:
            self.code += struct.pack('<H', value)
        return self

    def label(self, name):
        self.labels[name] = self.here()
        return self

    def movs(self, rd, imm): return self.half(0x2000 | rd << 8 | imm)

    def movw(self, rd, imm, top=0xf240):
        return self.half(top | (imm >> 12 & 15) | (imm >> 11 & 1) << 10, (imm >> 8 & 7) << 12 | rd << 8 | imm & 255)

    def movt(self, rd, imm): return self.movw(rd, imm, 0xf2c0)

    def minus_one(self, rd): return self.half(0xf04f, 3 << 12 | rd << 8 | 0xff)  # mov.w rd, #-1

    def mov(self, rd, rm): return self.half(0x4600 | (rd >> 3) << 7 | rm << 3 | rd & 7)

    def addw(self, rd, rn, imm, top=0xf200):
        return self.half(top | (imm >> 11 & 1) << 10 | rn, (imm >> 8 & 7) << 12 | rd << 8 | imm & 255)

    def subw(self, rd, rn, imm): return self.addw(rd, rn, imm, 0xf2a0)

    def adds(self, rd, rn, imm): return self.half(0x1c00 | imm << 6 | rn << 3 | rd)

    def strh(self, rt, rn, offset): return self.half(0x8000 | (offset // 2) << 6 | rn << 3 | rt)

    def str(self, rt, rn, offset): return self.half(0x6000 | (offset // 4) << 6 | rn << 3 | rt)

    def strb(self, rt, rn, offset): return self.half(0x7000 | offset << 6 | rn << 3 | rt)

    def str_sp(self, rt, offset): return self.half(0x9000 | rt << 8 | offset // 4)

    def ldr_sp(self, rt, offset): return self.half(0x9800 | rt << 8 | offset // 4)

    def add_sp(self, rd, offset): return self.half(0xa800 | rd << 8 | offset // 4)  # add rd, sp, #offset

    def str_indexed(self, rt, rn, rm): return self.half(0x5000 | rm << 6 | rn << 3 | rt)  # str rt, [rn, rm]

    def ret(self): return self.half(0x4770)  # bx lr

    def stm(self, rn, *registers): return self.half(0xc000 | rn << 8 | sum(1 << r for r in registers))

    def it_eq(self): return self.half(0xbf08)

    def push(self): return self.half(0xb5f0)  # push {r4-r7, lr}

    def pop(self): return self.half(0xbdf0)  # pop {r4-r7, pc}

    def nop(self): return self.half(0xbf00)

    def mov_imm(self, rd, value):  # mov.w rd, #value (Thumb modified immediate)
        value &= 0xffffffff
        if value < 256:
            imm12 = value
        else:
            imm12 = next(rotation << 7 | rotated & 0x7f for rotation in range(8, 32)
                         for rotated in [(value << rotation | value >> (32 - rotation)) & 0xffffffff]
                         if rotated < 256 and rotated & 0x80)
        return self.half(0xf04f | (imm12 >> 11) << 10, (imm12 >> 8 & 7) << 12 | rd << 8 | imm12 & 255)

    def strd(self, rt, rt2, rn, offset): return self.half(0xe9c0 | rn, rt << 12 | rt2 << 8 | offset // 4)

    def str_w(self, rt, rn, offset): return self.half(0xf8c0 | rn, rt << 12 | offset)

    def ldr(self, rt, rn, offset): return self.half(0x6800 | (offset // 4) << 6 | rn << 3 | rt)

    def vldr(self, sd, rn, offset): return self.half(0xed90 | (sd & 1) << 6 | rn, (sd >> 1) << 12 | 0xa00 | offset // 4)

    def vcvt(self, sd, sm): return self.half(0xeeb8 | (sd & 1) << 6, (sd >> 1) << 12 | 0xac0 | (sm & 1) << 5 | sm >> 1)

    def vmul(self, sd, sn, sm):
        return self.half(0xee20 | (sd & 1) << 6 | sn >> 1, (sd >> 1) << 12 | 0xa00 | (sn & 1) << 7 | (sm & 1) << 5 | sm >> 1)

    def vmov_core(self, rt, sn): return self.half(0xee10 | sn >> 1, rt << 12 | 0xa10 | (sn & 1) << 7)

    def address_of(self, rd, address):
        """ldr rd, [pc, #k] ; add rd, pc  ->  rd = address."""
        self.literals.append((len(self.code), lambda add, target=address: (target - (add + 4)) & 0xffffffff))
        return self.half(0x4800 | rd << 8, 0x4478 | rd)

    def call(self, target, exchange=True):
        """bl/blx with an immediate target (blx switches to the ARM PLT stub)."""
        here = self.here()
        base = (here + 4) & ~3 if exchange else here + 4
        sign, j1, j2, value = branch_fields(target - base, True)
        low = value & 0x7ff
        second = (0xc000 if exchange else 0xd000) | j1 << 13 | j2 << 11 | (low & ~1 if exchange else low)
        return self.half(0xf000 | sign << 10 | value >> 11 & 0x3ff, second)

    def jump(self, label):  # b.w label
        self.fixups.append((len(self.code), 'b.w', label))
        return self.half(0, 0)

    def beq(self, label):  # beq label (16-bit, forward)
        self.fixups.append((len(self.code), 'beq', label))
        return self.half(0)

    def data(self, *words):
        for word in words:
            self.code += struct.pack('<I', word)
        return self

    def finish(self):
        for at, kind, name in self.fixups:
            source = self.address + at
            offset = self.labels[name] - (source + 4)
            if kind == 'beq':
                struct.pack_into('<H', self.code, at, 0xd000 | (offset >> 1) & 255)
            else:
                sign, j1, j2, value = branch_fields(offset, False)
                struct.pack_into('<2H', self.code, at, 0xf000 | sign << 10 | value >> 11 & 0x3ff,
                                 0x9000 | j1 << 13 | j2 << 11 | value & 0x7ff)
        if len(self.code) % 4:
            self.nop()
        pool = len(self.code)
        for index, (at, value) in enumerate(self.literals):
            word = pool + 4 * index
            pc = (self.address + at + 4) & ~3
            struct.pack_into('<H', self.code, at, struct.unpack_from('<H', self.code, at)[0] | (self.address + word - pc) // 4)
            self.code += struct.pack('<I', value(self.address + at + 2))
        return bytes(self.code)


def registration(asm, identifier, kind, path, payload=None, *, record=5, holder=6, before_fields=None,
                 sizes=(16, 8), sentinel=True, material_slot=None):
    """One record in the compiler's shape: record/payload allocation, string copy, fields.

    `identifier` is an int, or (register, delta) for an id derived from a base register.
    `payload` is ('texture', bits), ('mesh', material, flags) or None. `before_fields`
    may emit code between the string copy and the record's field stores; `sizes`
    and `sentinel` vary the record/payload allocations and the record's -1 field;
    `material_slot` reloads the mesh material from that sp offset instead.
    """
    asm.movs(0, sizes[0]).call(stub('_Znwj')).mov(record, 0)
    asm.movs(0, sizes[1]).call(stub('_Znwj')).mov(holder, 0)
    if payload and payload[0] == 'texture':
        asm.movs(0, payload[1]).str(0, holder, 4)
    elif payload and payload[0] == 'mesh':
        (asm.ldr_sp(1, material_slot) if material_slot is not None else asm.movw(1, payload[1])).strh(1, holder, 4)
        asm.movs(1, payload[2]).strb(1, holder, 6)
    asm.address_of(0, path).call(stub('strlen')).adds(4, 0, 1).mov(0, 4).call(stub('_Znaj')).str(0, holder, 0)
    asm.address_of(1, path).mov(2, 4).call(stub('__aeabi_memcpy'))
    if before_fields:
        before_fields(asm)
    if isinstance(identifier, tuple):
        register, delta = identifier
        (asm.addw if delta >= 0 else asm.subw)(0, register, abs(delta))
    else:
        asm.movw(0, identifier)
    asm.strh(0, record, 0).movs(0, kind)
    (asm.minus_one(1) if sentinel else asm.movs(1, 0)).adds(2, record, 4).stm(2, 0, 1, holder)
    return asm


def section(name, kind, address, offset, size, link=0, info=0, align=4, entry=0):
    return (name, kind, 2, address, offset, size, link, info, align, entry)


def library(functions, strings, *, plt_slots=None, machine=40, text_size=0x5000, rodata=RODATA, got=GOT):
    """functions: [(name, Thumb.finish() bytes, address)]; strings: {address: text or bytes} within .rodata.

    Larger fixtures pass a bigger `text_size` with `rodata`/`got` moved past it.
    """
    rodata_size = 0x1000 if rodata == RODATA else max(0x1000, max((a + len(t) + 1 - rodata for a, t in strings.items()), default=0))
    image_rodata = bytearray(rodata_size)
    for address, text in strings.items():
        encoded = text if isinstance(text, bytes) else text.encode() + b'\0'
        image_rodata[address - rodata:address - rodata + len(encoded)] = encoded
    text = bytearray(text_size)
    for _, code, address in functions:
        text[address - TEXT:address - TEXT + len(code)] = code
    names = bytearray(b'\0')
    def name(value):
        names.extend(value.encode() + b'\0')
        return len(names) - len(value) - 1
    symbols = [bytes(16)]
    for value in IMPORTS:
        symbols.append(struct.pack('<IIIBBH', name(value), 0, 0, 0x12, 0, 0))
    for label, code, address in functions:
        symbols.append(struct.pack('<IIIBBH', name(label), address | 1, len(code), 0x12, 0, 5))
    relocations = b''.join(struct.pack('<II', (plt_slots or {}).get(n, got + 4 * i), (i + 1) << 8 | 22)
                           for i, n in enumerate(IMPORTS))
    stubs = bytearray(20)
    for index in range(len(IMPORTS)):
        entry = PLT + 20 + 12 * index
        total = got + 4 * index - (entry + 8)
        stubs += struct.pack('<3I', 0xe28fc600 | total >> 20 & 255, 0xe28cca00 | total >> 12 & 255, 0xe5bcf000 | total & 0xfff)
    # File layout: header, then blobs at offsets equal to their addresses.
    blobs = {0x200: b''.join(symbols), 0x600: bytes(names), 0x800: relocations, PLT: bytes(stubs),
             TEXT: bytes(text), rodata: bytes(image_rodata)}
    shstr = b'\0.dynsym\0.dynstr\0.rel.plt\0.plt\0.text\0.rodata\0.shstrtab\0'
    def at(label): return shstr.index(label.encode() + b'\0')
    tail = max(0x9000, rodata + rodata_size, got + 0x1000)
    sections = [(0,) * 10,
                section(at('.dynsym'), 11, 0x200, 0x200, len(blobs[0x200]), 2, 1, entry=16),
                section(at('.dynstr'), 3, 0x600, 0x600, len(names)),
                section(at('.rel.plt'), 9, 0x800, 0x800, len(relocations), 1, 4, entry=8),
                section(at('.plt'), 1, PLT, PLT, len(stubs)),
                section(at('.text'), 1, TEXT, TEXT, len(text)),
                section(at('.rodata'), 1, rodata, rodata, len(image_rodata)),
                section(at('.shstrtab'), 3, 0, tail, len(shstr))]
    image = bytearray(tail + len(shstr) + 40 * len(sections))
    for offset, blob in blobs.items():
        image[offset:offset + len(blob)] = blob
    image[tail:tail + len(shstr)] = shstr
    table = tail + len(shstr)
    for index, row in enumerate(sections):
        struct.pack_into('<10I', image, table + 40 * index, *row)
    image[:16] = b'\x7fELF\x01\x01\x01' + bytes(9)
    struct.pack_into('<HHI', image, 16, 3, machine, 1)
    struct.pack_into('<I', image, 32, table)
    struct.pack_into('<HHH', image, 46, 40, len(sections), len(sections) - 1)
    return bytes(image)


def layout_library(layout, shift=0):
    """A synthetic library holding every span of a symbol-anchored proof layout.

    Each span gets distinct synthetic bytes (never original code); a 'literal'
    entry gets an `ldr rN, [pc]; add rN, pc` pair at its delta that addresses
    a synthetic table in .rodata holding its bytes at its start. Returns (library bytes, the layout rewritten
    with the synthetic proofs, {symbol: function address}).
    """
    import hashlib
    extent = {}
    for rule in layout.values():
        end = rule[1] + (12 if len(rule) == 6 else rule[2])
        extent[rule[0]] = max(extent.get(rule[0], 0), end)
    starts, address = {}, TEXT + 0x100 + shift
    for symbol, end in extent.items():
        starts[symbol] = address
        address += (end + 15) & ~15
    code = {symbol: bytearray(b'\x00\xbf' * ((end + 1) // 2)) for symbol, end in extent.items()}
    for index, (key, rule) in enumerate(layout.items()):
        if len(rule) == 4:
            symbol, delta, size = rule[:3]
            code[symbol][delta:delta + size] = bytes((17 * index + 3 * i + 1) % 251 + 1 for i in range(size))
    rodata = (address + 0xfff) & ~0xfff
    data, at, used = {}, rodata, {}
    for index, (key, rule) in enumerate(layout.items()):
        if len(rule) == 6:
            symbol, delta, size = rule[:3]
            here = starts[symbol] + delta
            pool = ((here + 4) & ~3) + 4 - starts[symbol]  # ldr r0, [pc, #4] ; add r0, pc
            assert all(not (d - 12 < delta < d + 12) for d in used.get(symbol, [])), 'synthetic literal pairs overlap'
            used.setdefault(symbol, []).append(delta)
            struct.pack_into('<HH', code[symbol], delta, 0x4801, 0x4478)
            struct.pack_into('<I', code[symbol], pool, (at - (here + 2 + 4)) & 0xffffffff)
            data[at] = bytes(rule[5]) + bytes((29 * index + 5 * i + 2) % 251 + 1 for i in range(size))
            at = (at + rule[5] + size + 15) & ~15
    patched = {}
    for key, rule in layout.items():
        symbol, delta, size, expected = rule[:4]
        raw = data[word_target(code[symbol], delta, starts[symbol])][rule[5]:] if len(rule) == 6 else bytes(code[symbol][delta:delta + size])
        patched[key] = (symbol, delta, size, 'sha256:' + hashlib.sha256(raw).hexdigest() if expected.startswith('sha256:') else raw.hex(), *rule[4:])
    functions = [(symbol, bytes(body), starts[symbol]) for symbol, body in code.items()]
    image = library(functions, data, text_size=rodata - TEXT, rodata=rodata, got=(at + 0xfff) & ~0xfff)
    return image, patched, starts


def word_target(body, delta, start):
    """Data address of the synthetic literal pair at body[delta]."""
    half, = struct.unpack_from('<H', body, delta)
    here = start + delta
    pool = ((here + 4) & ~3) + (half & 255) * 4 - start
    word, = struct.unpack_from('<I', body, pool)
    return (word + here + 2 + 4) & 0xffffffff


def verify_android_proof(test, reader, extract, layout='ANDROID', values='ANDROID_VALUES'):
    """Acceptance, relocation and every span's corruption boundary for a symbol-anchored module.

    `extract(lib)` runs the module against a library; it must return the module's
    values (or (values, proof)) for the synthetic library, and nothing once any
    proven byte changes.
    """
    import copy
    from unittest.mock import patch
    from gof2_content.android_library import AndroidLibrary
    expected = getattr(reader, values)
    for shift in (0, 0x1000):
        image, patched, _ = layout_library(getattr(reader, layout), shift)
        with patch.object(reader, layout, patched):
            lib = AndroidLibrary(image)
            result = extract(lib)
            found = result[0] if isinstance(result, tuple) else {k: v for k, v in result.items() if k != 'provenance'}
            proof = result[1] if isinstance(result, tuple) else result['provenance']
            test.assertEqual(found, expected)
            test.assertEqual(set(proof), set(patched))
            for key, span in proof.items():
                test.assertEqual(span['offset'] - span['anchor'], patched[key][5] if len(patched[key]) == 6 else patched[key][1], key)
            # The result is a copy: changing it leaves the module's values intact.
            json_copy = copy.deepcopy(expected)
            found.clear()
            test.assertEqual(getattr(reader, values), json_copy)
            if shift:
                continue
            for key, span in proof.items():
                for index in {0, span['bytes'] - 1}:
                    raw = bytearray(image)
                    raw[span['offset'] + index] ^= 0xff
                    broken = extract(AndroidLibrary(bytes(raw)))
                    test.assertFalse(broken[0] if isinstance(broken, tuple) else broken, (key, index))


def assert_native_android(test, reader, definitions, values='ANDROID_VALUES', layout='ANDROID'):
    """The game's copy of a module's Android values and span rules equals the importer's."""
    import json
    import re
    from pathlib import Path
    source = (Path(__file__).resolve().parents[1] / 'game/src/content' / definitions).read_text()
    spans = {k: [v[5] if len(v) == 6 else v[1], v[2]] for k, v in getattr(reader, layout).items()}
    for name, value in [(values, getattr(reader, values)), (layout + '_SPANS', spans)]:
        found = re.findall(r'^const ' + name + r' :?= (.+)$', source, re.MULTILINE)
        test.assertEqual(len(found), 1, name)
        test.assertEqual(json.loads(found[0]), value, name)
