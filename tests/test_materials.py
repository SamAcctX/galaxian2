"""Synthetic constant declarations and adversarial linkage, no original content."""
import importlib.util
import json
import struct
import unittest

from test_bindings import executable, wide, PATH
from gof2_content.registrations import MachO, extract
from gof2_content.materials import extract_materials


def arm_wide(value, reg=1, top=False):
    first, second = struct.unpack('<2H', wide(value, top))
    return struct.pack('<2H', first, (second & ~0xf00) | (reg << 8))


def with_code(code, edition):
    data = bytearray(executable(edition))
    at = 32 + 72 + 40 if edition == 'mac-full-hd' else 28 + 56 + 36
    struct.pack_into('<Q' if edition == 'mac-full-hd' else '<I', data, at, len(code))
    assert len(code) <= 512
    data[512:512 + len(code)] = code
    return bytes(data)


def mac_material():
    return (bytes.fromhex('bf 30 00 00 00 e8 00 00 00 00 c7 40 10') + struct.pack('<I', 28)
            + bytes.fromhex('48 c7 40 18 00 00 00 00 c7 40 20') + struct.pack('<I', 0)
            + bytes.fromhex('c7 40 24') + struct.pack('<I', 0xc1200000)
            + bytes.fromhex('c7 40 28 00 00 00 00 c7 40 2c 00 00 00 00')
            + bytes.fromhex('48 c7 40 08 ff ff ff ff 48 c7 00 ff ff ff ff')
            + bytes.fromhex('66 c7 00') + struct.pack('<H', 71)
            + bytes.fromhex('66 c7 40 02') + struct.pack('<H', 72)
            + bytes.fromhex('66 c7 03') + struct.pack('<H', 99)
            + bytes.fromhex('c7 43 04 06 00 00 00 c7 43 08 ff ff ff ff 48 89 43 10'))


def ios_material():
    load = bytes.fromhex('d5 f8 40 20')
    return (bytes.fromhex('28 20 00 f0 00 e8 0b ad 1c 22 00 23 4f f0 ff 36 d5 f8 40 10 02 61 00 22')
            + arm_wide(0xc120, 2, True) + bytes.fromhex('43 61 83 61 c2 61')
            + arm_wide(71, 2) + arm_wide(72, 2, True)
            + bytes.fromhex('03 62 43 62') + arm_wide(99, 3)
            + bytes.fromhex('c6 60 86 60 46 60 06 60 02 60') + load
            + bytes.fromhex('13 80 06 23') + load + bytes.fromhex('53 60')
            + load + bytes.fromhex('96 60') + load + bytes.fromhex('d0 60'))


def ios_mesh(changed_slot=False):
    code = bytes.fromhex('08 20 00 f0 00 e8 6e 46 70 60 70 68') + arm_wide(99)
    code += bytes.fromhex('81 80 71 68 00 22 8a 71')
    displacement = 0x3000 - (0x2000 + len(code) + 12)
    code += arm_wide(displacement, 0) + arm_wide(0, 0, True) + bytes.fromhex('78 44')
    code += bytes.fromhex('00 f0 00 f8 01 30 00 f0 00 e8 6e 46')
    prefix_length = len(code)
    original = executable('ios-hd')
    length = struct.unpack_from('<I', original, 28 + 56 + 36)[0]
    tail = bytearray(original[512:512 + length])
    displacement = 0x3000 - 0x2000 - prefix_length - 8 - 12
    tail[8:16] = wide(displacement) + wide(0, True)
    if changed_slot:
        tail[4:8] = bytes.fromhex('d6 f8 08 20')
        # Keep registration footer coherent so only metadata aliasing fails.
        at = tail.rfind(bytes.fromhex('d6 f8 04 20'))
        tail[at:at + 4] = bytes.fromhex('d6 f8 08 20')
    return with_code(code + tail, 'ios-hd')


class MaterialTests(unittest.TestCase):
    def test_mac_mesh_metadata_repeats_the_same_resource_path(self):
        prefix = (bytes.fromhex('66 41 c7 44 24 08') + struct.pack('<H', 99)
                  + bytes.fromhex('41 c6 44 24 0a 00 48 8d 3d') + struct.pack('<i', 0x1000 - 21)
                  + bytes.fromhex('e8 00 00 00 00 89 c3 ff c3 48 89 df e8 00 00 00 00'))
        original = executable()
        length = struct.unpack_from('<Q', original, 32 + 72 + 40)[0]
        tail = bytearray(original[512:512 + length])
        struct.pack_into('<i', tail, 7, 0x1000 - len(prefix) - 11)
        row = extract(with_code(prefix + tail, 'mac-full-hd'), 'mac-full-hd')['registrations'][0]
        self.assertEqual((row['material_id'], row['mesh_flags']), (99, 0))
        bad = bytearray(prefix)
        bad[17] += 1
        row = extract(with_code(bad + tail, 'mac-full-hd'), 'mac-full-hd')['registrations'][0]
        self.assertNotIn('material_id', row)

    def test_mac_complete_descriptor_and_payload_identity(self):
        code = mac_material()
        rows = extract_materials(MachO(with_code(code, 'mac-full-hd'), 'mac-full-hd'))
        self.assertEqual(rows[0]['texture_ids'], [71, 72] + [65535] * 6)
        self.assertEqual(rows[0]['parameter_bits'], [0, 0xc1200000, 0, 0])
        for changed in (code[:-1], code[:-1] + b'\x18', code.replace(b'\xc7\x43\x04\x06', b'\xc7\x43\x04\x07')):
            self.assertEqual(extract_materials(MachO(with_code(changed, 'mac-full-hd'), 'mac-full-hd')), [])

    @unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
    def test_cross_architecture_constant_data_and_rejection(self):
        mac = extract_materials(MachO(with_code(mac_material(), 'mac-full-hd'), 'mac-full-hd'))[0]
        code = ios_material()
        ios = extract_materials(MachO(with_code(code, 'ios-hd'), 'ios-hd'))[0]
        self.assertEqual(mac, ios)
        json.dumps(ios)  # No instruction bytes, pointers or decoder objects escape.
        alternate = code.replace(bytes.fromhex('4f f0 ff 36'), bytes.fromhex('4f f0 ff 34'))
        for old, new in [('c660', 'c460'), ('8660', '8460'), ('4660', '4460'), ('0660', '0460'), ('9660', '9460')]:
            alternate = alternate.replace(bytes.fromhex(old), bytes.fromhex(new))
        self.assertEqual(extract_materials(MachO(with_code(alternate, 'ios-hd'), 'ios-hd'))[0], ios)
        for changed in (code[:-2], code.replace(b'\x03\x62', b'\x00\xbf'),
                        code.replace(b'\x03\x62', b'\x00\xe0'),
                        code[:-2] + bytes.fromhex('d1 60'),
                        code.replace(b'\x43\x61', b'\x42\x61')):
            self.assertEqual(extract_materials(MachO(with_code(changed, 'ios-hd'), 'ios-hd')), [])

    @unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
    def test_mesh_metadata_requires_same_allocated_payload(self):
        row = extract(ios_mesh(), 'ios-hd')['registrations'][0]
        self.assertEqual((row['material_id'], row['mesh_flags']), (99, 0))
        self.assertEqual(row['resource'], 'resources/' + PATH)
        broken = extract(ios_mesh(True), 'ios-hd')['registrations'][0]
        self.assertNotIn('material_id', broken)


BUILD = '_Z17BuildResourceListPN11AbyssEngine6EngineE'
LOW = '_Z27loadLowTexturesAndMaterialsPN11AbyssEngine6EngineE'


def android_material(asm, identifier=99, kind=6, sentinel=-1, sizes=(16, 40), pointer=0, field=4, source=8, extra=None, calls=None):
    """One material in BuildResourceList's shape: record and payload allocations,
    the payload's constant stores (one -1 texture pair goes from `source` to `field`, None: not stored),
    then the record's id (None: an unknown register), type/sentinel pair and payload pointer.
    `calls` collects the payload allocation call addresses."""
    from android_fixture import stub
    asm.movs(0, sizes[0]).call(stub('_Znwj')).mov(4, 0).movs(0, sizes[1])
    if calls is not None:
        calls.append(asm.here())
    asm.call(stub('_Znwj'))
    asm.movs(5, 28).mov_imm(6, pointer).movw(11, 0).movt(11, 0xc120).mov_imm(9, 0)
    asm.strd(5, 6, 0, 0x10).strd(9, 11, 0, 0x18).strd(9, 9, 0, 0x20).minus_one(8)
    asm.str_w(8, 0, 0xc).str_w(8, 0, 8)
    if field is not None:
        asm.str_w(source, 0, field)
    asm.movw(1, 71).strh(1, 0, 0).movw(1, 72).strh(1, 0, 2)
    if extra:
        extra(asm)
    (asm.mov(1, 7) if identifier is None else asm.movw(1, identifier)).strh(1, 4, 0).mov_imm(9, kind)
    (asm.minus_one(8) if sentinel == -1 else asm.mov_imm(8, sentinel)).strd(9, 8, 4, 4).str(0, 4, 12)
    return asm


def android_library(bodies, misaligned=False):
    """Functions {name: [material options]}, each also declaring one texture."""
    from android_fixture import RODATA, TEXT, Thumb, library, registration
    from gof2_content.android_library import AndroidLibrary
    functions = []
    for index, (name, materials) in enumerate(bodies.items()):
        asm = Thumb(TEXT + 0x100 + 0x800 * index).push()
        registration(asm, 70 + index, 2, RODATA + 0x10, ('texture', 1))
        for options in materials:
            android_material(asm, **options)
        if misaligned:
            # ldr r0, [pc] whose `add r0, pc` is the second half of `movw r4, #0x478`.
            asm.literals.append((len(asm.code), lambda add: (RODATA + 0x10 - (add + 2 + 4)) & 0xffffffff))
            asm.half(0x4800).movw(4, 0x478)
        functions.append((name, asm.pop().finish(), asm.address))
    return AndroidLibrary(library(functions, {RODATA + 0x10: 'data/textures/a.aei'}))


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidMaterialTests(unittest.TestCase):
    def test_fixture_encodings(self):
        import capstone
        from android_fixture import TEXT, Thumb
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        code = Thumb(TEXT).strd(9, 11, 0, 0x18).mov_imm(9, 6).movt(11, 0xc120).mov_imm(6, 0).half(0x4800).movw(4, 0x478).half(0xed80, 0x0a00).finish()
        self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoder.disasm(code, TEXT)][:7],
                         ['strd sb, fp, [r0, #0x18]', 'mov.w sb, #6', 'movt fp, #0xc120', 'mov.w r6, #0', 'ldr r0, [pc, #0]',
                          'movw r4, #0x478', 'vstr s0, [r0]'])

    def test_named_functions_give_the_mac_material(self):
        calls = []
        lib = android_library({BUILD: [dict(calls=calls), dict(identifier=100, calls=calls)], '_Z5otherv': [dict(identifier=101, calls=calls)],
                               LOW: [dict(identifier=98, calls=calls)]})
        rows = extract_materials(lib)
        mac = extract_materials(MachO(with_code(mac_material(), 'mac-full-hd'), 'mac-full-hd'))[0]
        del mac['source_offset']
        self.assertEqual([{**row, 'id': 99} for row in rows], [{**mac, 'source_offset': row['source_offset']} for row in rows])
        self.assertEqual([row['id'] for row in rows], [98, 99, 100])
        # Offsets of the payload allocation calls (none from the unnamed function).
        self.assertEqual([row['source_offset'] for row in rows], [calls[3], calls[0], calls[1]])
        self.assertEqual([row['id'] for row in extract_materials(android_library({LOW: [{}]}))], [99])
        self.assertEqual(extract_materials(android_library({BUILD: [{}]}, misaligned=True)), [])

    def test_each_broken_declaration_is_rejected(self):
        cases = {'record size': dict(sizes=(20, 40)), 'payload size': dict(sizes=(16, 44)), 'type': dict(kind=4),
                 'sentinel': dict(sentinel=0), 'pointer': dict(pointer=1), 'missing store': dict(field=None),
                 'outside': dict(field=0x28), 'overlap': dict(extra=lambda asm: asm.movs(1, 0).strh(1, 0, 0)),
                 'vector store': dict(extra=lambda asm: asm.half(0xed80, 0x0a00)), 'unknown value': dict(source=7),
                 'unknown id': dict(identifier=None),
                 'record field': dict(extra=lambda asm: asm.movs(1, 0).str(1, 4, 16)),
                 'record overlap': dict(extra=lambda asm: asm.movs(1, 0).str(1, 4, 0)),
                 'payload offset': dict(extra=lambda asm: asm.adds(0, 0, 4))}
        for name, options in cases.items():
            self.assertEqual(extract_materials(android_library({BUILD: [options]})), [], name)
        self.assertEqual(extract_materials(android_library({'_Z5otherv': [{}]})), [])


if __name__ == '__main__':
    unittest.main()
