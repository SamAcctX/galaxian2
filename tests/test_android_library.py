"""Synthetic Android libraries: ELF layout, PLT stubs and resource registration records."""
import importlib.util
import struct
import unittest
from android_fixture import GOT, IMPORTS, RODATA, TEXT, Thumb, library, registration, stub
from gof2_content.android_library import AndroidLibrary, android_records
from gof2_content.formats import ContentError
from gof2_content.registrations import extract

PATHS = {RODATA + 0x10: 'data/textures/a.aei', RODATA + 0x30: 'data/meshes/b.aem', RODATA + 0x50: 'data/meshes/c.aem',
         RODATA + 0x70: 'data/textures/d.aei', RODATA + 0x90: 'data/meshes/e.aem', RODATA + 0xb0: 'data/notes.txt',
         RODATA + 0xd0: 'data/../escape.aei'}
A, B, C, D, E, NOTE, UNSAFE = PATHS


def build(body, address=TEXT + 0x100, **options):
    asm = Thumb(address).push()
    body(asm)
    code = asm.pop().finish()
    return AndroidLibrary(library([('_Z5buildv', code, address)], PATHS, **options))


def read(body, **options):
    return android_records(build(body, **options), lambda *_: None)


def row(identifier, kind, path, offset, **extra):
    return dict(id=identifier, registration_type=kind, kind='texture' if path.endswith('.aei') else 'mesh',
                resource='resources/' + path, source_path=path, source_offset=offset, **extra)


def mark(asm, starts):
    starts.append(asm.here() + 2)  # The record's allocation call follows `movs r0, #16`.
    return asm


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidLibraryTests(unittest.TestCase):
    def test_fixture_encodings_decode_as_intended(self):
        import capstone
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        decoder.detail = True
        asm = Thumb(TEXT)
        cases = [(lambda: asm.movs(0, 16), 'movs r0, #0x10'), (lambda: asm.movw(9, 0x84fa), 'movw sb, #0x84fa'),
                 (lambda: asm.movt(9, 0x12), 'movt sb, #0x12'), (lambda: asm.minus_one(1), 'mov.w r1, #-1'),
                 (lambda: asm.mov(6, 0), 'mov r6, r0'), (lambda: asm.addw(0, 9, 5), 'addw r0, sb, #5'),
                 (lambda: asm.subw(0, 9, 0x2a), 'subw r0, sb, #0x2a'), (lambda: asm.adds(2, 5, 4), 'adds r2, r5, #4'),
                 (lambda: asm.strh(0, 5, 0), 'strh r0, [r5]'), (lambda: asm.str(0, 6, 4), 'str r0, [r6, #4]'),
                 (lambda: asm.strb(1, 6, 6), 'strb r1, [r6, #6]'), (lambda: asm.stm(2, 0, 1, 6), 'stm r2!, {r0, r1, r6}'),
                 (lambda: asm.str_sp(0, 8), 'str r0, [sp, #8]'), (lambda: asm.ldr_sp(0, 8), 'ldr r0, [sp, #8]'),
                 (lambda: asm.call(stub('_Znwj')), 'blx #0x%x' % stub('_Znwj'))]
        for emit, expected in cases:
            start = len(asm.code)
            emit()
            decoded = list(decoder.disasm(bytes(asm.code[start:]), TEXT + start))
            self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoded], [expected])
        asm = Thumb(TEXT).beq('end').jump('end').address_of(3, RODATA + 0x10).nop().label('end')
        code = asm.finish()
        decoded = list(decoder.disasm(code[:12], TEXT))
        self.assertEqual([i.mnemonic for i in decoded], ['beq', 'b.w', 'ldr', 'add', 'nop'])
        self.assertEqual(decoded[0].operands[0].imm, asm.labels['end'])
        self.assertEqual(decoded[1].operands[0].imm, asm.labels['end'])
        pool = ((TEXT + 6 + 4) & ~3) + decoded[2].operands[1].mem.disp
        self.assertEqual((struct.unpack_from('<I', code, pool - TEXT)[0] + TEXT + 8 + 4) & 0xffffffff, RODATA + 0x10)

    def test_elf_layout_and_verified_imports(self):
        lib = build(lambda asm: registration(asm, 1, 2, A, ('texture', 1)))
        self.assertEqual((lib.architecture, lib.edition, lib.slice_offset), ('armv7', 'android-hd', 0))
        self.assertEqual(lib.imports, {stub(name): name for name in IMPORTS})
        self.assertEqual([(s['segment'], s['name']) for s in lib.sections],
                         [(b'__TEXT', b'__text'), (b'__TEXT', b'__cstring'), (b'__TEXT', b'__const'), (b'__TEXT', b'__picsymbolstub4')])
        self.assertEqual((lib.text['address'], lib.cstring['address']), (TEXT, RODATA))
        self.assertEqual([(start, name) for start, _, name in lib.functions], [(TEXT + 0x100, '_Z5buildv')])
        self.assertEqual(lib.resource_string(A), 'data/textures/a.aei')
        for address in (A + 1, NOTE, RODATA - 4, RODATA + 0x1000):
            self.assertIsNone(lib.resource_string(address))
        with self.assertRaises(ContentError):
            lib.resource_string(UNSAFE)

    def test_reads_each_payload_shape_and_derived_ids(self):
        starts = []
        def body(asm):
            asm.movw(9, 0x8000)
            registration(mark(asm, starts), 1000, 2, A, ('texture', 7))
            registration(mark(asm, starts), 2000, 4, B, ('mesh', 300, 1))
            registration(mark(asm, starts), 2001, 6, C, ('mesh', 301, 0))
            registration(mark(asm, starts), (9, -0x2a), 2, D, ('texture', 0))
            registration(mark(asm, starts), (9, 5), 4, E, ('mesh', 65535, 0))
            registration(mark(asm, starts), 3000, 4, A, ('mesh', 5, 1))  # A texture path with mesh fields: no metadata.
            registration(mark(asm, starts), 3001, 4, D, ('texture', 9))  # Texture bits belong to kind 2 only.
            asm.movw(10, 0x10)
            registration(mark(asm, starts), (10, -0x20), 2, A)  # The u16 store keeps the low half of -16.
        self.assertEqual(read(body), [
            row(1000, 2, 'data/textures/a.aei', starts[0], texture_parameter_bits=7),
            row(2000, 4, 'data/meshes/b.aem', starts[1], material_id=300, mesh_flags=1),
            row(2001, 6, 'data/meshes/c.aem', starts[2], _payload={'material_id': 301, 'mesh_flags': 0}),
            row(0x7fd6, 2, 'data/textures/d.aei', starts[3], texture_parameter_bits=0),
            row(0x8005, 4, 'data/meshes/e.aem', starts[4], material_id=65535, mesh_flags=0),
            row(3000, 4, 'data/textures/a.aei', starts[5]),
            row(3001, 4, 'data/textures/d.aei', starts[6]),
            row(0xfff0, 2, 'data/textures/a.aei', starts[7])])

    def test_values_never_cross_a_branch_target(self):
        def base_across_label(asm):
            asm.movw(9, 0x100).beq('later').nop().label('later')
            registration(asm, (9, 1), 2, A, ('texture', 1))
            registration(asm, 77, 2, D, ('texture', 1))
        self.assertEqual([r['id'] for r in read(base_across_label)], [77])
        def base_without_label(asm):
            asm.movw(9, 0x100).nop()
            registration(asm, (9, 1), 2, A, ('texture', 1))
        self.assertEqual([r['id'] for r in read(base_without_label)], [0x101])
        def record_split_by_label(asm):
            asm.beq('middle')
            registration(asm, 5, 2, A, ('texture', 1), before_fields=lambda a: a.label('middle'))
            registration(asm, 6, 2, D, ('texture', 1))
        self.assertEqual([r['id'] for r in read(record_split_by_label)], [6])
        def after_unconditional_branch(asm):
            asm.movw(9, 0x100).jump('else')
            registration(asm, 7, 2, A, ('texture', 1))  # Unreachable linear code still declares its own constants.
            asm.label('else')
            registration(asm, (9, 2), 2, D, ('texture', 1))  # Reached only by the branch: the base is unknown.
        self.assertEqual([r['id'] for r in read(after_unconditional_branch)], [7])
        def dead_code_after_branch(asm):
            asm.movw(9, 0x100).jump('end')
            registration(asm, (9, 3), 2, A, ('texture', 1))  # Not a branch target: entered from nowhere known.
            asm.label('end')
        self.assertEqual(read(dead_code_after_branch), [])

    def test_pool_islands_are_skipped_only_by_an_unconditional_branch(self):
        def island(conditional):
            def body(asm):
                registration(asm, 1, 2, A, ('texture', 1))
                (asm.beq if conditional else asm.jump)('after')
                asm.half(0xf000)  # Half of a 32-bit branch: decoding through it misaligns.
                asm.label('after')
                registration(asm, 2, 2, D, ('texture', 1))
            return body
        self.assertEqual([r['id'] for r in read(island(False))], [1, 2])
        self.assertNotIn(2, [r['id'] for r in read(island(True))])

    def test_conditional_repeated_or_extra_stores_reject_the_record(self):
        def guarded(asm):
            registration(asm, 1, 2, A, ('texture', 1)).it_eq().strh(0, 5, 0)
            registration(asm, 2, 2, D, ('texture', 1))
        self.assertEqual([r['id'] for r in read(guarded)], [2])
        def guarded_value(asm):
            asm.movw(9, 0x100).it_eq().movs(1, 0)  # r1 is only maybe zero; r9 stays known.
            registration(asm, (9, 4), 2, A, ('texture', 1), before_fields=lambda a: a.movw(4, 0))
            asm.it_eq().mov(9, 1)
            registration(asm, (9, 5), 2, D, ('texture', 1))
        self.assertEqual([r['id'] for r in read(guarded_value)], [0x104])
        def repeated(asm):
            registration(asm, 1, 2, A, ('texture', 1)).movs(0, 9).strh(0, 5, 0)
        self.assertEqual(read(repeated), [])
        def extra(asm):
            registration(asm, 1, 2, A, ('texture', 1)).str(0, 6, 8)  # The 8-byte payload has no third field.
        self.assertEqual(read(extra), [])
        def unknown_layout(asm):
            registration(asm, 1, 2, A).movs(0, 1).strh(0, 6, 6)  # In bounds, but no known payload has it.
        self.assertEqual(read(unknown_layout), [])
        def conditional_payload(asm):
            registration(asm, 1, 2, A, ('texture', 1)).it_eq().str(0, 6, 4)
        self.assertEqual(read(conditional_payload), [])

    def test_stack_spills_follow_the_frame(self):
        local = TEXT + 0x80
        def spilled(between, slot=8):
            def body(asm):
                asm.movw(0, 300).str_sp(0, slot)
                between(asm)
                registration(asm, 1, 4, B, ('mesh', None, 0), material_slot=slot)
            code = Thumb(TEXT + 0x100).push()
            body(code)
            helper = Thumb(local).ret().finish()
            lib = AndroidLibrary(library([('_Z5localv', helper, local), ('_Z5buildv', code.pop().finish(), TEXT + 0x100)], PATHS))
            return [(r['id'], r.get('material_id')) for r in android_records(lib, lambda *_: None)]
        call = lambda asm: asm.call(local, exchange=False)
        self.assertEqual(spilled(lambda asm: None), [(1, 300)])
        self.assertEqual(spilled(call), [(1, 300)])  # No frame address ever leaves the function.
        self.assertEqual(spilled(lambda asm: call(asm.add_sp(0, 4))), [])  # The callee may write sp+4 and up.
        self.assertEqual(spilled(lambda asm: call(asm.add_sp(0, 4)), slot=0), [(1, 300)])  # Below what it can reach.
        self.assertEqual(spilled(lambda asm: call(asm.add_sp(4, 4).str(0, 4, 0))), [(1, 300)])  # Only a store base.
        self.assertEqual(spilled(lambda asm: call(asm.add_sp(3, 4).str(0, 3, 0))), [])  # r3 is an argument.
        self.assertEqual(spilled(lambda asm: asm.add_sp(3, 4).str(0, 3, 0)), [(1, 300)])  # Writes slot 4 only.
        self.assertEqual(spilled(lambda asm: asm.add_sp(3, 8).strh(0, 3, 2)), [])  # A half-word inside the slot.
        self.assertEqual(spilled(lambda asm: asm.str(0, 7, 0)), [])  # Through the frame pointer.
        self.assertEqual(spilled(lambda asm: asm.movs(2, 0x40).add_sp(3, 0).str_indexed(0, 3, 2)), [(1, 300)])
        self.assertEqual(spilled(lambda asm: asm.add_sp(4, 0).str_indexed(0, 4, 2)), [])  # Unknown index.
        self.assertEqual(spilled(lambda asm: asm.movs(2, 8).add_sp(3, 0).str_indexed(1, 3, 2)), [])  # Index hits it.
        def pushed(asm):
            asm.movw(0, 300).str_sp(0, 8).push()  # sp moves down 20 bytes: the slot is now sp+28.
            registration(asm, 1, 4, B, ('mesh', None, 0), material_slot=28)
            registration(asm, 2, 4, C, ('mesh', None, 0), material_slot=8)
        self.assertEqual([(r['id'], r.get('material_id')) for r in read(pushed)], [(1, 300)])

    def test_record_shape_is_exact(self):
        for options in (dict(sizes=(20, 8)), dict(sizes=(16, 12)), dict(sentinel=False)):
            self.assertEqual(read(lambda asm: registration(asm, 1, 2, A, ('texture', 1), **options)), [], options)
        self.assertEqual(len(read(lambda asm: registration(asm, 1, 2, A, ('texture', 1)))), 1)

    def test_other_heap_records_are_not_resource_declarations(self):
        def body(asm):
            # A 40-byte material payload and a 4-byte image-region payload.
            for size in (40, 4):
                asm.movs(0, 16).call(stub('_Znwj')).mov(5, 0).movs(0, size).call(stub('_Znwj')).mov(6, 0)
                asm.movw(0, 500 + size).strh(0, 5, 0).movs(0, 2).minus_one(1).adds(2, 5, 4).stm(2, 0, 1, 6)
            registration(asm, 9, 2, NOTE, ('texture', 1))  # Copied from a non-resource string.
            registration(asm, 10, 2, A, ('texture', 1))
        self.assertEqual([r['id'] for r in read(body)], [10])

    def test_alternatives_with_one_id_are_kept(self):
        def body(asm):
            asm.beq('other')
            registration(asm, 11635, 2, A, ('texture', 1)).jump('done')
            asm.label('other')
            registration(asm, 11635, 2, D, ('texture', 1))
            asm.label('done')
        self.assertEqual([(r['id'], r['source_path']) for r in read(body)],
                         [(11635, 'data/textures/a.aei'), (11635, 'data/textures/d.aei')])

    def test_stubs_must_load_their_own_relocation_slot(self):
        body = lambda asm: registration(asm, 1, 2, A, ('texture', 1))
        lib = build(body, plt_slots={'_Znwj': GOT + 0x100})
        self.assertNotIn(stub('_Znwj'), lib.imports)
        self.assertEqual(android_records(lib, lambda *_: None), [])
        self.assertEqual(len(read(body)), 1)

    def test_rejects_other_elf_layouts(self):
        image = library([], PATHS)
        AndroidLibrary(image)
        for damaged in (b'\x7fELF\x02' + image[5:], image[:18] + b'\x3e\x00' + image[20:], image[:-8],
                        image.replace(b'.text\0', b'.txet\0'), image[:51]):
            with self.assertRaises(ContentError):
                AndroidLibrary(damaged)

    def test_extract_reads_the_android_edition(self):
        def body(asm):
            registration(asm, 2000, 4, B, ('mesh', 300, 1))
            registration(asm, 1000, 2, A, ('texture', 7))
        source = build(body).data
        declarations = extract(source, 'android-hd')
        self.assertEqual(declarations['architecture'], 'armv7')
        self.assertEqual([(r['id'], r['source_path']) for r in declarations['registrations']],
                         [(1000, 'data/textures/a.aei'), (2000, 'data/meshes/b.aem')])
        with self.assertRaises(ContentError):
            extract(source, 'android-hd', ship_count=61)
        with self.assertRaisesRegex(ContentError, 'No supported resource declaration'):
            extract(build(lambda asm: asm.nop()).data, 'android-hd')


if __name__ == '__main__':
    unittest.main()
