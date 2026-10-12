"""Text listings of synthetic Android functions and the extra Thumb encodings."""
import importlib.util
import unittest

from android_fixture import RODATA, TEXT, stub
from android_thumb import Asm, build


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidListingTests(unittest.TestCase):
    def test_encodings_decode_as_intended(self):
        import capstone
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        asm = Asm(TEXT)
        cases = [(lambda: asm.cmp(0, 0x65), 'cmp r0, #0x65'), (lambda: asm.cmp(8, 4), 'cmp.w r8, #4'),
                 (lambda: asm.cmp_reg(6, 0), 'cmp r6, r0'), (lambda: asm.add_imm(8, 8, 1), 'add.w r8, r8, #1'),
                 (lambda: asm.sub_imm(1, 2, 0x200), 'sub.w r1, r2, #0x200'), (lambda: asm.adds8(6, 1), 'adds r6, #1'),
                 (lambda: asm.add_reg(0, 0, 2, 4), 'add.w r0, r0, r2, lsl #4'), (lambda: asm.add_reg(0, 10, 6), 'add.w r0, sl, r6'),
                 (lambda: asm.add_low(1, 9), 'add r1, sb'), (lambda: asm.ldr_w(2, 11), 'ldr.w r2, [fp]'),
                 (lambda: asm.ldr_w(4, 5, 0xf8), 'ldr.w r4, [r5, #0xf8]'), (lambda: asm.ldr_w(4, 5, -8), 'ldr r4, [r5, #-0x8]'),
                 (lambda: asm.str_neg(8, 0, 4), 'str r8, [r0, #-0x4]'), (lambda: asm.ldr_index(4, 0, 8), 'ldr.w r4, [r0, r8, lsl #2]'),
                 (lambda: asm.ldrh_index(1, 1, 9), 'ldrh.w r1, [r1, sb, lsl #1]'), (lambda: asm.ldrb(1, 5, 3), 'ldrb r1, [r5, #3]'),
                 (lambda: asm.ldrh(1, 5, 6), 'ldrh r1, [r5, #6]'), (lambda: asm.uxth(1, 4), 'uxth r1, r4'),
                 (lambda: asm.uxtb(1, 4), 'uxtb r1, r4'), (lambda: asm.orrs(0, 1), 'orrs r0, r1'), (lambda: asm.lsls(1, 1, 2), 'lsls r1, r1, #2'),
                 (lambda: asm.strb_w(8, 5, 6), 'strb.w r8, [r5, #6]'), (lambda: asm.strh_w(8, 5, 4), 'strh.w r8, [r5, #4]'),
                 (lambda: asm.str_sp_w(9, 0x104), 'str.w sb, [sp, #0x104]'), (lambda: asm.ldr_sp_w(9, 0x104), 'ldr.w sb, [sp, #0x104]'),
                 (lambda: asm.vstr(20, 13, 4), 'vstr s20, [sp, #4]'), (lambda: asm.vstr(1, 0, 0), 'vstr s1, [r0]'),
                 (lambda: asm.vmov_imm(16, 0x34), 'vmov.f32 s16, #2.000000e+01'), (lambda: asm.vmov_imm(1, 0x70), 'vmov.f32 s1, #1.000000e+00'),
                 (lambda: asm.vmov_from(2, 0), 'vmov s2, r0'), (lambda: asm.vmov_from(3, 9), 'vmov s3, sb'),
                 (lambda: asm.vadd(20, 20, 16), 'vadd.f32 s20, s20, s16'), (lambda: asm.vdiv(1, 3, 2), 'vdiv.f32 s1, s3, s2'),
                 (lambda: asm.vcvt_u(0, 1), 'vcvt.f32.u32 s0, s1')]
        for emit, expected in cases:
            start = len(asm.code)
            emit()
            decoded = list(decoder.disasm(bytes(asm.code[start:]), TEXT + start))
            self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoded], [expected])
        asm = Asm(TEXT).it('gt').movs(0, 1).it('ne').movs(1, 0)
        self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoder.disasm(asm.finish(), TEXT)][:4],
                         ['it gt', 'movgt r0, #1', 'it ne', 'movne r1, #0'])
        asm = Asm(TEXT).label('top').branch('ne', 'end').branch(None, 'end').branch('lt', 'top', wide=True)
        asm.branch(None, 'top', wide=True).cbz(3, 'end', nonzero=True).branch('ge', 'end', wide=True).nop().label('end')
        asm.vldr_pc(5, 0x3f800000).ldr_pc(9, 0x12345678).nop()
        code = asm.finish()
        decoded = list(decoder.disasm(code, TEXT))
        end = asm.labels['end']
        self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoded][:9],
                         ['bne #%#x' % end, 'b #%#x' % end, 'blt.w #%#x' % TEXT, 'b.w #%#x' % TEXT, 'cbnz r3, #%#x' % end,
                          'bge.w #%#x' % end, 'nop ', 'vldr s5, [pc, #8]', 'ldr.w sb, [pc, #8]'])
        self.assertEqual(code[-8:], bytes.fromhex('0000803f78563412'))

    def test_listing_renders_calls_literals_and_addresses(self):
        from gof2_content.android_listing import Listing, number, word_float
        asm = Asm(TEXT + 0x100).push().address_of(0, RODATA + 0x40).ldr(1, 0, 0)
        asm.call(stub('_Znwj')).call_to('_Z1gv').vldr_pc(0, 0x40490fdb)
        asm.address_of(2, RODATA)
        asm.labels['join'] = asm.here() - 2  # the `add r2, pc`
        asm.address_of(3, RODATA + 8).branch('ne', 'join').pop()
        lib = build({'_Z1fv': asm, '_Z1gv': Asm(TEXT + 0x400).ret()})
        listing = Listing(lib, '_Z1fv')
        self.assertEqual(listing.lines[1:8], ['ldr r0, =%#x' % ((RODATA + 0x40 - (TEXT + 0x104 + 4)) & 0xffffffff),
                                              'adr r0, %#x' % (RODATA + 0x40), 'ldr r1, [r0]', 'call _Znwj', 'call _Z1gv',
                                              'vldr s0, =0x40490fdb', listing.lines[7]])
        # A branch target ends the straight-line code: the add after it stays unresolved.
        self.assertEqual(listing.lines[8:12], ['add r2, pc', 'ldr r3, =%#x' % ((RODATA + 8 - (asm.labels['join'] + 4 + 4)) & 0xffffffff),
                                               'adr r3, %#x' % (RODATA + 8), 'bne #%#x' % asm.labels['join']])
        self.assertEqual(word_float(0x40490fdb), 3.1415927410125732)
        self.assertEqual([number(t) for t in ('#0x65', '#-3', '0xb2da8', '#2.000000e+01', '#8')], [0x65, -3, 0xb2da8, 20.0, 8])
        found = listing.find(r'call (?P<f>\w+)\ncall (?P<g>\w+)\n')
        self.assertEqual([(m['f'], m['g']) for m in found], [('_Znwj', '_Z1gv')])
        self.assertEqual(listing.find(r'all _Znwj\n'), [])
        self.assertEqual((listing.index(found[0]), listing.index(found[0], 'g'), listing.last(found[0])), (4, 5, 5))
        self.assertEqual(listing.match_span(found[0]), {'offset': TEXT + 0x108, 'bytes': 8})
        self.assertEqual((listing.definition(3, 'r0'), listing.definition(3, 'r1'), listing.definition(1, 'r0')), (2, None, None))
        self.assertEqual((listing.at(TEXT + 0x108), listing.at(TEXT + 0x109)), (4, None))
        self.assertFalse(Listing(lib, '_Z1hv'))

    def test_literals_need_their_pool_and_their_register(self):
        from gof2_content.android_listing import Listing
        # A double literal, a load whose pool lies past .text, and a literal overwritten before its add.
        asm = Asm(TEXT + 0x4f00).vldr_pc(1, 0x4049000000000000, double=True).half(0xf8df, 0x0ff0).ldr_address(0, RODATA)
        asm.mov(0, 1).add_pc(0).ret()
        listing = Listing(build({'_Z1fv': asm}), '_Z1fv')
        self.assertEqual(listing.lines[:2], ['vldr d1, =0x4049000000000000', 'ldr.w r0, [pc, #0xff0]'])
        self.assertEqual([line.split(' =')[0] for line in listing.lines[2:5]], ['ldr r0,', 'mov r0, r1', 'add r0, pc'])


if __name__ == '__main__':
    unittest.main()
