"""Synthetic relocated LOD tables, independently changed distances and detail data."""
import struct
import unittest
from types import SimpleNamespace
from gof2_content import ship_lod as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac, relocation=0):
    count=61 if mac else 64; base=0x100000+relocation; data=bytearray(13000); blocks={}
    text={'segment':b'__TEXT','name':b'__text','address':base,'offset':256,'length':8000}
    const={'segment':b'__TEXT','name':b'__const','address':base+9000,'offset':9000,'length':4000}
    m=SimpleNamespace(architecture='x86_64' if mac else 'armv7',text=text,sections=[text,const],slice_offset=0)
    locations={'body':64,'fill':264,'step':464,'child':664,'child_copy':864,'limit':1064,'square':3200,'cull':3500,'select':3640}
    if mac: locations['detail']=3544
    prefix='MAC_' if mac else 'ARM_'
    for key,at in locations.items():
        body,fields=expand(getattr(reader,prefix+key.upper()))
        for field,(off,size) in fields.items():
            site=base+at+off
            if field.startswith('call'):
                target=base+({'step':3000,'limit':3300}.get(key,7000))
                raw=struct.pack('<i',target-site-size) if mac else branch(((site+4)&~3)-4 if key=='select' else site,target)
                if not mac and key=='select': raw=raw[:3]+bytes([raw[3]&~0x10])
            elif field.startswith('ref'):
                target=base+({'body':9000,'fill':9000,'child':10000,'child_copy':10000}.get(key,11000))
                if key=='detail': target=base+{'ref_0':11000,'ref_15':11008,'ref_1f':11004,'ref_30':11012}[field]
                raw=struct.pack('<i',target-site-size)
            elif mac: raw=struct.pack('<i',{'fill':321,'step':700,'limit':50000}[key])
            else:
                meta=reader.ARM_FIELDS[prefix+key.upper()][field]; high=meta['kind']=='movt';value=1
                if key=='body' and field in ['word_0','word_8']: value=(base+9000)-(base+at+16+4);value=value>>16 if high else value&65535
                elif key=='child' and field in ['word_0','word_6']: value=(base+10000)-(base+at+12+4);value=value>>16 if high else value&65535
                elif (key,field) in [('body','word_c'),('child','word_e')]: value=65535
                elif (key,field)==('fill','word_c'): value=321
                elif key=='limit': value=0 if high else 50000
                if meta['kind']=='add.w': raw=bytes.fromhex('04f5fa54')
                else: raw=arm_wide(value,int(meta['register'][1:]),high)
            body[off:off+size]=raw
        data[256+at:256+at+len(body)]=body;blocks[key]=(at,body,fields)
    raw=bytes.fromhex('554889e5480faff64889b7980000005dc3' if mac else 'b0b5a1fb014302af01fb023301fb0235c0e91c45b0bd');data[3556:3556+len(raw)]=raw
    for i in range(count):
        struct.pack_into('<3I',data,9000+i*12,2000+i*2,2001+i*2,77777)
        struct.pack_into('<3I',data,10000+i*12,65535,65535,88888)
    struct.pack_into('<3I',data,9012,2100,65535,99999)
    struct.pack_into('<5f',data,11000,0.2,0.8,0.25,1.0,0.625)
    m.data=bytes(data)
    return m,{'resource_ids':list(range(count))},{'provenance':[{'offset':320,'bytes':30}]},blocks


class ShipLOD(unittest.TestCase):
    def test_relocation_and_changed_data(self):
        for mac in [True,False]:
            for shift in [0,0x50000]:
                m,models,lights,_=fixture(mac,shift); result=reader.extract_ship_lod(m,models,lights)
                self.assertTrue(result,(mac,shift))
                self.assertEqual(result['distances'],[321,1021 if mac else 8321])
                self.assertEqual(result['body_resource_ids'][1],[2100,65535])
                self.assertEqual(result['maximum_distance'],50000)
                self.assertEqual(result['squared_distance_factors'],[0.25,0.625,1.0] if mac else [1.0])

    def test_corrupt_contexts_tables_and_links(self):
        for mac in [True,False]:
            for bad in ['body','step','select','cull','square','limit_setter','body_table','child_table','gap','link','extent','duplicate','missing']:
                with self.subTest(mac=mac,bad=bad):
                    m,models,lights,blocks=fixture(mac); data=bytearray(m.data)
                    if bad in blocks:
                        at,body,fields=blocks[bad];field_bytes={p for off,size in fields.values() for p in range(off,off+size)}
                        pos=next(p for p in range(len(body)) if p not in field_bytes);data[256+at+pos]^=1
                    elif bad=='limit_setter':data[3556]^=1
                    elif bad=='body_table':struct.pack_into('<I',data,9000,70000)
                    elif bad=='child_table':struct.pack_into('<I',data,10000,2222)
                    elif bad=='gap':struct.pack_into('<I',data,9000,65535)
                    elif bad=='link':
                        at,_,fields=blocks['step'];off,size=fields['call_3d' if mac else 'call_26'];data[256+at+off:256+at+off+size]=struct.pack('<i',6000-at-off-size) if mac else branch(m.text['address']+at+off,m.text['address']+6000)
                    elif bad=='extent':m.sections[1]['length']=10
                    elif bad=='duplicate':
                        at,body,_=blocks['body'];data[1856:1856+len(body)]=body
                    elif bad=='missing':lights={}
                    m.data=bytes(data);self.assertEqual(reader.extract_ship_lod(m,models,lights),{})


GROUP = '_ZN7Globals12getShipGroupEiib'
UPDATE = '_ZN10AEGeometry9updateLodERKN11AbyssEngine6AEMath6VectorEf'
SETTER = '_ZN10AEGeometry25setLodLastVisibleDistanceEy'
PLAIN = '_ZN10AEGeometry12setLodMeshesEPtPii'
IDS = '_ZN10AEGeometry23setLodMeshesWithMeshIdsEPtPjPii'
FP, SB, SL, IP = 11, 9, 10, 12


# Thumb-2 encodings only these functions need (checked against Capstone below).
def ldrd(asm, rt, rt2, rn, offset=0): return asm.half(0xe9d0 | rn, rt << 12 | rt2 << 8 | offset // 4)
def str_index(asm, rt, rn, rm, shift=0): return asm.half(0xf840 | rn, rt << 12 | shift << 4 | rm)
def strh_index(asm, rt, rn, rm, shift=0): return asm.half(0xf820 | rn, rt << 12 | shift << 4 | rm)
def subs8(asm, rd, imm): return asm.half(0x3800 | rd << 8 | imm)
def umull(asm, low, high, rn, rm): return asm.half(0xfba0 | rn, low << 12 | high << 8 | rm)
def mla(asm, rd, rn, rm, ra): return asm.half(0xfb00 | rn, ra << 12 | rd << 8 | rm)
def orrs_w(asm, rd, rn, rm): return asm.half(0xea50 | rn, rd << 8 | rm)
def subs_reg(asm, rd, rn, rm): return asm.half(0x1a00 | rm << 6 | rn << 3 | rd)
def adds_reg(asm, rd, rn, rm): return asm.half(0x1800 | rm << 6 | rn << 3 | rd)
def sbcs_w(asm, rd, rn, rm): return asm.half(0xeb70 | rn, rd << 8 | rm)
def ldr_reg(asm, rt, rn, rm): return asm.half(0x5800 | rm << 6 | rn << 3 | rt)
def mvn(asm, rd, imm): return asm.half(0xf06f, rd << 8 | imm)
def vcmpe(asm, sd, sm): return asm.half(0xeeb4 | (sd & 1) << 6, (sd >> 1) << 12 | 0xac0 | (sm & 1) << 5 | sm >> 1)
def vmrs(asm): return asm.half(0xeef1, 0xfa10)
def vmov_reg(asm, sd, sm): return asm.half(0xeeb0 | (sd & 1) << 6, (sd >> 1) << 12 | 0xa40 | (sm & 1) << 5 | sm >> 1)


def square(asm, this, i, narrow=False):
    (asm.ldr(0, this, 0x64) if narrow else asm.ldr_w(0, this, 0x64)).add_reg(2, 0, i, 3).ldr_index(1, 0, i, 3).ldr(3, 2, 4)
    umull(asm, 6, 5, 1, 1); mla(asm, 5, 1, 3, 5); str_index(asm, 6, 0, i, 3); mla(asm, 1, 1, 3, 5)
    return asm.str(1, 2, 4)


def android(breaks=(), seed=321, increment=700, maximum=0x21234, factors=(0x60, 0x68, 0x70), low=0x3ea8f5c3, high=0x3f28f5c3,
            body_rows=None, table=None, child_table=None):
    """getShipGroup's ordinary LOD path, updateLod and the setters in the Android compiler's shape."""
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm, build
    body_table, child_table = RODATA, child_table or RODATA + 0x100
    to = lambda name, label: 'elsewhere' if name in breaks else label
    g = Asm(TEXT + 0x100).push()
    g.mov(SB, 1).ldr_address(0, body_table).add_reg(8, SB, SB, 1).movs(1, 0).movw(2, 0xffff).add_pc(0).mov_imm(SL, 0)
    g.add_reg(0, 0, 8, 2).label('body_head').ldr_index(4, 0, 1).mov(6, SL).adds(5, 6, 1).adds8(1, 1).cmp_reg(4, 2)
    g.it('ne').mov(SL, 5).cmp(1, 3 if 'columns' in breaks else 2).branch('ne', to('body loop', 'body_head')).cmp_w(SL, 0).branch('le', to('body none', 'set'), wide=True)
    if 'row' in breaks:
        g.mov(8, 1)
    g.label('elsewhere')
    if 'no move' not in breaks:
        g.mov(FP, 3 if 'moved' in breaks else 8)
    g.ldr_address(0, body_table + (0x10 if 'fill table' in breaks else 0)).movw(1, 0xffff).cmp_reg(4, 1).add_pc(0).movw(1, 0x7dc8)
    g.add_reg(2, 0, FP, 2).ldr_address(0, 0x9000).add_low(1, SB).it('ne').mov(6, 5).add_pc(0).str_sp_w(FP, 8).str_sp(3, 0x24)
    g.movw(FP, seed).ldr(0, 0, 0).mov_imm(8, 0).str_sp(0, 0x1c).uxth(0, 1).str_sp(0, 0x14).str_sp(2, 0x18).ldr_sp(4, 0x10)
    ldrd(g.ldr_sp(0, 0x28), SB, 5, 13, 0x1c)
    g.label('fill_head').ldr_index(1, 2, 8, 0).cmp(0, 0).strh(1, 4, 0)
    str_index(g, FP, 3, 8).branch('ne', to('fill skip', 'step')).nop()
    subs8(g.label('step'), 6, 1).add_imm(5 if 'offset' in breaks else 8, 5 if 'offset' in breaks else 8, 4)
    g.add_imm(4 if 'distance' in breaks else FP, 4 if 'distance' in breaks else FP, increment).add_imm(4, 4, 2)
    g.branch('ne', to('step loop', 'fill_head')).cmp(0, 0).branch('eq', to('step ids', 'ids'), wide=True)
    g.ldr_sp_w(FP, 0xc).mov(2, 3).ldr_sp_w(SB, 0x10).mov(3, SL).mov(0, FP).mov(1, SB).call_to(PLAIN).branch(None, to('step done', 'child'))
    g.label('ids').ldr_sp_w(FP, 0xc).ldr_sp_w(SB, 0x10).ldr_sp(2, 0x20).mov(0, FP).str_sp_w(SL, 0).mov(1, SB).call_to(IDS)
    if 'ids end' in breaks:
        g.nop()
    g.label('child').ldr_address(0, child_table).movs(2, 0).ldr_sp_w(8, 8).movw(6, 0xffff).add_pc(0).movs(1, 0).add_reg(0, 0, 8, 2)
    g.label('child_head').ldr_index(4, 0, 2).mov(5, 1).adds(3, 5, 1).adds8(2, 1).cmp_reg(4, 6).it('ne').mov(1, 3).cmp(2, 2)
    g.branch('ne', to('child loop', 'child_head')).cmp(1, 0).branch('le', to('child none', 'limit'))
    if 'child end' in breaks:
        g.nop()
    g.movw(0, 0xffff).cmp_reg(4, 0).add_reg(0, 1, 1).it('ne').mov(5, 3).cmp_reg(0, 1).it('lo').minus_one(0).call_to('_Znaj').mov(4, 0)
    g.ldr_address(0, child_table + (0x10 if 'copy table' in breaks else 0)).movs(1, 0).add_pc(0).add_reg(0, 0, SB if 'copy row' in breaks else 8, 2)
    strh_index(g.label('copy_head').ldr_index(2, 0, 1), 2, 4, 1, 1).adds8(1, 1).cmp_reg(5, 1).branch('ne', to('copy loop', 'copy_head'))
    g.mov(0, FP).mov(1, 4).call_to('_ZN10AEGeometry17setLodChildMeshesEPt').mov(0, 4).call_to('_ZdaPv')
    if 'copy end' in breaks:
        g.nop()
    g.label('limit').mov(0, SB).call_to('_ZdaPv').ldr_sp(0, 0x24).call_to('_ZdaPv').label('set').movw(2, maximum & 0xffff).mov(0, FP)
    g.movt(2, maximum >> 16).movs(3, 0).call_to(SETTER)
    g.pop()

    u = Asm(TEXT + 0x800).push()
    if 'no input' not in breaks:
        u.mov(8, 3 if 'input' in breaks else 2)
    u.vldr(0, FP, 0x78).vldr(2, FP, 0x7c).vmul(0, 0, 0).vldr(4, FP, 0x80).vmul(2, 2, 2).vmul(4, 4, 4).vadd(0, 0, 2).vadd(0, 0, 4)
    u.vmov_core(0, 0).call_to('__aeabi_f2ulz').strd(0, 1, FP, 0x68)
    orrs_w(ldrd(u, 3, 2, FP, 0x78 if 'limit field' in breaks else 0x70), 6, 3, 2).branch('eq', to('unlimited', 'detail'))
    sbcs_w(subs_reg(u, 0, 0, 3).mov_imm(6, 0), 0, 1, 2).it('hs' if 'visible' in breaks else 'lo').movs(6, 1).strb_w(6, FP, 0x48).cmp(6, 0)
    u.branch('eq', to('culled', 'hidden'), wide=True)
    if 'cull end' in breaks:
        u.nop()
    u.label('detail').ldr_w(1, FP, 0xc).vmov_from(18, 8).ldr_w(0, FP, 0x2c).add_imm(6, FP, 0x68)
    u.call_to('_ZN11AbyssEngine11PaintCanvas21TransformGetTransformEj').vldr_pc(2, high).vmov_imm(4, factors[1]).vmov_imm(0, factors[2])
    vcmpe(mvn(u, 1, 7), 18, 2); vmrs(u.vldr_pc(2, low)); vcmpe(u.vmov_imm(16, factors[0]), 18, 2)
    vmrs(vmov_reg(u.it('lo' if 'bands' in breaks else 'ls'), 0, 4)).mov_imm(5, 0).add_reg(4, 1, 5, 3).it('hi')
    ldrd(vmov_reg(u, 16, 0), SL, SB, 0, 0x110)
    if 'detail end' in breaks:
        u.nop()
    u.label('select').cmp(5, 1).branch('lt', 'nearest').ldr_w(0, FP, 0x60 if 'array' in breaks else 0x64)
    ldr_reg(adds_reg(subs8(u, 5, 1), 1, 0, 4), 0, 0, 4).ldr(1, 1, 4).call_to('__aeabi_ul2f').vmov_from(0, 0)
    ldrd(u, 0, 1, 6).vmul(18, 16, 0).call_to('__aeabi_ul2f').vmov_from(0, 0)
    vmrs(vcmpe(subs8(u, 4, 8), 0, 18)).branch('gt' if 'compare' in breaks else 'le', to('select loop', 'select'))
    u.label('nearest').label('elsewhere').nop().label('hidden').minus_one(0).str_w(0, FP, 0x2c if 'hidden' in breaks else 0x28).pop()

    s = Asm(TEXT + 0xc00)
    umull(s, IP, 1, 2, 2); mla(s, 1, 2, 3, 1); mla(s, 1, 2, 3, 1); s.strd(IP, 1, 0, 0x78 if 'setter' in breaks else 0x70).ret()
    plain = square(Asm(TEXT + 0xd00).push().nop(), 8, 4)
    if 'twice' in breaks:
        square(plain, 8, 4)
    plain.pop()
    ids = square(Asm(TEXT + 0xe00).push(), 4, FP, narrow=True).pop()
    names = {('_ZN7Globals8getShipEi' if 'name' in breaks else GROUP): g, UPDATE: u, SETTER: s, PLAIN: plain, IDS: ids}
    body = body_rows or [[100, 101, 102], [65535, 65535, 0], [200, 65535, 0], [0, 0, 0]]
    children = [[65535, 65535, 0], [65535, 65535, 0], [300, 65535, 0], [0, 0, 0]]
    data = {body_table: b''.join(struct.pack('<3I', *row) for row in body)}
    if child_table < RODATA + 0x1000:
        data[child_table] = b''.join(struct.pack('<3I', *row) for row in children)
    return build(names, data), {'resource_ids': [1, 2, 3, 4] if table is None else table}, {'provenance': [{'offset': 1, 'bytes': 1}]}


class AndroidShipLOD(unittest.TestCase):
    def test_encodings_decode_as_intended(self):
        import capstone
        from android_fixture import TEXT
        from android_thumb import Asm
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        asm = Asm(TEXT)
        cases = [(lambda: ldrd(asm, SB, 5, 13, 0x1c), 'ldrd sb, r5, [sp, #0x1c]'), (lambda: ldrd(asm, 0, 1, 6), 'ldrd r0, r1, [r6]'),
                 (lambda: str_index(asm, FP, 3, 8), 'str.w fp, [r3, r8]'), (lambda: str_index(asm, 6, 0, 4, 3), 'str.w r6, [r0, r4, lsl #3]'),
                 (lambda: strh_index(asm, 2, 4, 1, 1), 'strh.w r2, [r4, r1, lsl #1]'), (lambda: subs8(asm, 6, 1), 'subs r6, #1'),
                 (lambda: umull(asm, IP, 1, 2, 2), 'umull ip, r1, r2, r2'), (lambda: mla(asm, 1, 2, 3, 1), 'mla r1, r2, r3, r1'),
                 (lambda: orrs_w(asm, 6, 3, 2), 'orrs.w r6, r3, r2'), (lambda: subs_reg(asm, 0, 0, 3), 'subs r0, r0, r3'),
                 (lambda: adds_reg(asm, 1, 0, 4), 'adds r1, r0, r4'), (lambda: sbcs_w(asm, 0, 1, 2), 'sbcs.w r0, r1, r2'),
                 (lambda: ldr_reg(asm, 0, 0, 4), 'ldr r0, [r0, r4]'), (lambda: mvn(asm, 1, 7), 'mvn r1, #7'),
                 (lambda: vcmpe(asm, 18, 2), 'vcmpe.f32 s18, s2'), (lambda: vcmpe(asm, 0, 18), 'vcmpe.f32 s0, s18'),
                 (lambda: vmrs(asm), 'vmrs apsr_nzcv, fpscr'), (lambda: vmov_reg(asm, 16, 0), 'vmov.f32 s16, s0'),
                 (lambda: asm.vmov_imm(4, 0x68), 'vmov.f32 s4, #7.500000e-01'), (lambda: asm.vmov_imm(16, 0x60), 'vmov.f32 s16, #5.000000e-01')]
        for emit, expected in cases:
            start = len(asm.code)
            emit()
            decoded = list(decoder.disasm(bytes(asm.code[start:]), TEXT + start))
            self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoded], [expected])

    def test_reads_the_ordinary_path_and_the_selector(self):
        from android_fixture import RODATA
        lib, models, lights = android()
        value = reader.extract_ship_lod(lib, models, lights)
        self.assertEqual(value['body_resource_ids'], [[100, 101], [65535, 65535], [200, 65535], [0, 0]])
        self.assertEqual(value['child_resource_ids'], [[65535, 65535], [65535, 65535], [300, 65535], [0, 0]])
        self.assertEqual((value['distances'], value['maximum_distance']), ([321, 1021], 0x21234))
        self.assertEqual(value['detail_boundaries'], [struct.unpack('<f', struct.pack('<I', w))[0] for w in (0x3ea8f5c3, 0x3f28f5c3)])
        self.assertEqual(value['squared_distance_factors'], [0.5, 0.75, 1.0])
        self.assertEqual((value['threshold_comparison'], value['maximum_comparison']), ('greater', 'greater_or_equal'))
        spans = {key: (row['offset'] - (lib.symbols[name][0] if name else 0), row['bytes']) for key, row in value['provenance'].items()
                 for name in [{'square': PLAIN, 'square_ids': IDS, 'limit_setter': SETTER, 'cull': UPDATE, 'detail': UPDATE,
                               'select': UPDATE, 'detail_low': UPDATE, 'detail_high': UPDATE}.get(key, GROUP if 'table' not in key else None)]}
        self.assertEqual(spans, {'body': (4, 50), 'fill': (56, 74), 'step': (132, 44), 'step_ids': (176, 22), 'child': (198, 44),
                                 'child_copy': (242, 66), 'limit': (308, 28), 'square': (4, 32), 'square_ids': (2, 30),
                                 'limit_setter': (0, 18), 'cull': (4, 78), 'detail': (82, 84), 'select': (166, 52),
                                 'detail_high': (232, 4), 'detail_low': (236, 4), 'body_table': (RODATA, 48),
                                 'child_table': (RODATA + 0x100, 48)})

    def test_each_broken_rule_is_unsupported(self):
        for name in ['name', 'twice', 'setter', 'moved', 'row', 'fill table', 'copy table', 'copy row', 'offset', 'distance',
                     'body loop', 'body none', 'fill skip', 'step loop', 'step ids', 'step done', 'ids end', 'child loop',
                     'child none', 'child end', 'copy loop', 'copy end', 'unlimited', 'culled', 'cull end', 'detail end',
                     'select loop', 'hidden', 'input', 'no move', 'no input', 'columns', 'limit field', 'visible', 'bands',
                     'array', 'compare']:
            lib, models, lights = android([name])
            self.assertEqual(reader.extract_ship_lod(lib, models, lights), {}, name)
        for name, options in {'seed': dict(seed=0x3000, increment=0x1f400, maximum=0x21234), 'maximum': dict(maximum=0x100000),
                              'empty': dict(seed=0), 'step zero': dict(increment=0), 'factor': dict(factors=(0x60, 0x68, 0x00)), 'order': dict(factors=(0x60, 0x50, 0x70)),
                              'boundary': dict(low=0), 'boundaries': dict(low=0x3f28f5c3, high=0x3ea8f5c3),
                              'range': dict(body_rows=[[70000, 1, 0], [65535, 65535, 0], [200, 65535, 0], [0, 0, 0]]),
                              'gap': dict(body_rows=[[100, 101, 0], [65535, 1, 0], [200, 65535, 0], [0, 0, 0]]),
                              'children': dict(body_rows=[[1, 2, 0]] * 4), 'extent': dict(child_table=0x9000),
                              'parent': dict(table=[])}.items():
            lib, models, lights = android(**options)
            self.assertEqual(reader.extract_ship_lod(lib, models, lights), {}, name)
        lib, models, _ = android()
        self.assertEqual(reader.extract_ship_lod(lib, models, {}), {})
