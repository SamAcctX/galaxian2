"""Relocated manager clocks with changed constants and verified selector links."""
import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import lod_refresh as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac, relocation=0):
    base=0x100000+relocation; data=bytearray(4096); blocks={}
    locations={'initial':64,'batch':128,'tick':400}
    prefix='MAC_' if mac else 'ARM_'
    for key,at in locations.items():
        body,fields=expand(getattr(reader,prefix+key.upper()))
        for field,(off,size) in fields.items():
            site=base+at+off
            if field.startswith(('call','jump','ref')):
                dest=base+(128 if key=='tick' else 1000)
                raw=struct.pack('<i',dest-site-size) if mac else bytearray(branch(site,dest))
                if not mac and key=='tick': raw[3]&=~0x40
            elif mac: raw=struct.pack('<i',73 if key=='initial' else 201)
            elif key=='tick': raw=bytes.fromhex('b1f5fa7f') # cmp.w r1, #500
            else:
                meta=reader.ARM_FIELDS[prefix+key.upper()][field]
                raw=arm_wide(73,int(meta['register'][1:]),meta['kind']=='movt')
            body[off:off+size]=raw
        data[256+at:256+at+len(body)]=body;blocks[key]=(at,body,fields)
    m=SimpleNamespace(architecture='x86_64' if mac else 'armv7',data=bytes(data),slice_offset=8192,
        text={'address':base,'offset':256,'length':2048})
    return m,{'provenance':{'cull':{'offset':8192+256+1100,'bytes':20}}},blocks


class LODRefresh(unittest.TestCase):
    def test_changed_constants_and_relocation(self):
        for mac in [True,False]:
            for shift in [0,0x90000]:
                m,lod,_=fixture(mac,shift);result=reader.extract_lod_refresh(m,lod)
                self.assertTrue(result,(mac,shift))
                self.assertEqual(result['initial_milliseconds'],73)
                self.assertEqual(result['refresh_at_milliseconds'],201 if mac else 501)
                self.assertEqual(result['reset_milliseconds'],0)
                self.assertFalse(result['forced_refresh_resets_clock'])
                self.assertEqual(result['provenance']['initial']['offset'],8512)

    def test_rejects_corruption_and_unlinked_context(self):
        for mac in [True,False]:
            for bad in ['initial','batch','tick','jump','selector','duplicate','missing','register']:
                with self.subTest(mac=mac,bad=bad):
                    m,lod,blocks=fixture(mac);data=bytearray(m.data)
                    if bad in blocks:
                        at,_,_=blocks[bad];data[256+at]^=1
                    elif bad=='jump':
                        at,_,fields=blocks['tick'];off,size=fields['jump_1e' if mac else 'jump_14']
                        raw=struct.pack('<i',1000-at-off-size) if mac else bytearray(branch(m.text['address']+at+off,m.text['address']+1000))
                        if not mac:raw[3]&=~0x40
                        data[256+at+off:256+at+off+size]=raw
                    elif bad=='selector':lod['provenance']['cull']['offset']+=512
                    elif bad=='duplicate':
                        _,body,_=blocks['initial'];data[1856:1856+len(body)]=body
                    elif bad=='missing':lod={}
                    elif bad=='register':
                        if mac:continue
                        at,_,fields=blocks['initial'];off,size=fields['word_6'];data[256+at+off:256+at+off+size]=arm_wide(73,1,False)
                    m.data=bytes(data)
                    self.assertEqual(reader.extract_lod_refresh(m,lod),{})


CONSTRUCTOR, UPDATE, FORCE = '_ZN10LODManagerC1Ev', '_ZN10LODManager6updateEi', '_ZN10LODManager11forceUpdateEib'
SELECTOR = '_ZN10AEGeometry9updateLodERKN11AbyssEngine6AEMath6VectorEf'


def vldr_d(asm, dd, rn): return asm.half(0xed90 | (dd >> 4) << 6 | rn, (dd & 15) << 12 | 0xb00)  # vldr dd, [rn]
def vstr_d(asm, dd, rn): return asm.half(0xed80 | (dd >> 4) << 6 | rn, (dd & 15) << 12 | 0xb00)  # vstr dd, [rn]


def android(breaks=(), seed=73, threshold=500):
    """LODManager's constructor, update, forceUpdate and the veneer between them in the Android compiler's shape."""
    from android_fixture import TEXT
    from android_thumb import Asm, build
    to = lambda name, label: 'elsewhere' if name in breaks else label
    c = Asm(TEXT + 0x100).push().mov(4, 0).movs(6, 0).movs(1, 1)
    for _ in range(2 if 'twice' in breaks else 1):
        c.movw(0, seed).str(1, 5, 8).str(6, 5, 0).str(5, 4, 0).str(0, 4, 0x14 if 'field' in breaks else 0x10)
    c.pop()
    veneer = TEXT + 0x600
    t = Asm(TEXT + 0x200)
    if 'tick start' in breaks:
        t.nop()
    t.ldr(2, 0, 0x10).add_low(1, 2).str(1, 0, 0x10).cmp_w(1, threshold).it('lt' if 'compare' in breaks else 'le').ret()
    t.movs(1, 5 if 'reset' in breaks else 0).movs(2, 0).str(1, 0, 0x10)
    t.labels['veneer'] = TEXT + 0x4ff8 if 'outside' in breaks else veneer
    t.branch(None, 'veneer', wide=True)
    f = Asm(TEXT + 0x300).push().mov(9, 0).ldr_address(0, 0x9000).mov(8, 2).ldr_address(2, 0x9004).add_pc(0)
    f.ldr_address(1, 0x9008).add_pc(2).ldr(0, 0, 0).add_pc(1).ldr(2, 2, 0).ldr(1, 1, 0).ldr(0, 0, 0).str_sp(0, 0xc).ldr(4, 2, 0)
    f.vldr(16, 1, 0x28).mov(0, 4).call_to('_ZN11AbyssEngine11PaintCanvas16CameraGetCurrentEv').mov(1, 0).mov(0, 4)
    f.call_to('_ZN11AbyssEngine11PaintCanvas14CameraGetLocalEj').mov(4, 13).mov(1, 0).mov(0, 4)
    f.call_to('_ZN11AbyssEngine6AEMath17MatrixGetPositionERKNS0_6MatrixE').add_imm(11, 9, 4).mov(1, 4).mov(0, 11)
    f.call_to('_ZN11AbyssEngine6AEMath6VectoraSERKS1_').ldr_w(0, 9).ldr(1, 0, 0).cbz(1, to('done', 'done'))
    f.vmov_core(5, 16).movs(6, 0).mov(10, 13).label('loop').ldr(0, 0, 4).cmp_w(8, 1).ldr_index(4, 0, 6)
    f.branch('ne', to('own', 'own')).mov(0, 10).mov(1, 4).call_to('_ZN10AEGeometry17getParentPositionEv')
    vldr_d(f.branch(None, to('update', 'update')).label('own'), 16, 11).ldr_w(0, 11, 8).str_sp(0, 8)
    vstr_d(f, 16, 13).label('update').mov(0, 4).mov(1, 10).mov(2, 5).call_to(SELECTOR).ldr_w(0, 9).adds8(6, 1).ldr(1, 0, 0)
    f.cmp_reg(6, 1).branch('lo', to('loop', 'loop')).label('done').nop().label('elsewhere').nop().pop()
    target = TEXT + (0x100 if 'veneer target' in breaks else 0x300)
    v = Asm(veneer).half(0x4778, 0x46c0 if 'veneer' not in breaks else 0xbf00).data(0xe59fc000, 0xe08cf00f, target - (veneer + 16) & 0xffffffff)
    lib = build({CONSTRUCTOR: c, UPDATE: t, ('_ZN10LODManager6updateEv' if 'name' in breaks else FORCE): f, 'veneer': v})
    return lib, {'provenance': {'cull': {'offset': lib.symbols[SELECTOR][0], 'bytes': 1}}}


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidLODRefresh(unittest.TestCase):
    def test_encodings_decode_as_intended(self):
        import capstone
        from android_fixture import TEXT
        from android_thumb import Asm
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        for emit, expected in [(lambda asm: vldr_d(asm, 16, 11), 'vldr d16, [fp]'), (lambda asm: vstr_d(asm, 16, 13), 'vstr d16, [sp]')]:
            code = bytes(emit(Asm(TEXT)).code)
            self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoder.disasm(code, TEXT)], [expected])

    def test_reads_the_clock_and_the_batch(self):
        lib, lod = android()
        value = reader.extract_lod_refresh(lib, lod)
        self.assertEqual({k: v for k, v in value.items() if k != 'provenance'},
                         {'initial_milliseconds': 73, 'refresh_at_milliseconds': 501, 'reset_milliseconds': 0,
                          'time_unit': 'milliseconds', 'forced_refresh_resets_clock': False})
        self.assertEqual({k: (v['offset'] - lib.symbols[name][0], v['bytes']) for (k, v), name in
                          zip(sorted(value['provenance'].items()), (FORCE, CONSTRUCTOR, UPDATE))},
                         {'batch': (2, 142), 'initial': (8, 12), 'tick': (0, 24)})

    def test_each_broken_rule_is_unsupported(self):
        for name in ['name', 'twice', 'tick start', 'veneer', 'veneer target', 'outside', 'loop', 'own', 'update', 'done', 'field',
                     'compare', 'reset']:
            lib, lod = android([name])
            self.assertEqual(reader.extract_lod_refresh(lib, lod), {}, name)
        lib, lod = android(threshold=0xff0000)
        self.assertEqual(reader.extract_lod_refresh(lib, lod), {})
        lib, lod = android()
        lod['provenance']['cull']['offset'] += 2
        self.assertEqual(reader.extract_lod_refresh(lib, lod), {})
        self.assertEqual(reader.extract_lod_refresh(lib, {}), {})
