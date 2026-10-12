"""Synthetic lookup code and color data, independent of proprietary fixtures."""
import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import environment_colors as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac,shift=0):
    base=0x100000+shift;data=bytearray(12000);blocks={}
    locations={'sun':64,'planet':256 if mac else 1500,'rim':768}
    if not mac:locations['planet_table']=512
    getters={'system':2200,'sky_index':2240,'station':2280,'planet_type':2320}
    tables={'sun_rgb':8192,'planet_rgb':8500,'rim_rgb':8900}
    refs={'sun':{'ref_21':'sun_rgb'},'planet':{'ref_24':'planet_rgb'},'rim':{'ref_0':'rim_rgb'}}
    links={'sun':{'call_a':'system','call_12':'sky_index','bl_e':'system','bl_12':'sky_index'},'planet':{'call_a':'station','call_12':'planet_type','bl_2':'station','bl_6':'planet_type'}}
    for key,at in locations.items():
        name=('MAC_' if mac else 'ARM_')+key.upper();body,fields=expand(getattr(reader,name))
        for field,(off,size) in fields.items():
            site=base+at+off
            if mac:
                dest=base+(getters.get(links.get(key,{}).get(field),2400) if field.startswith('call') else tables.get(refs.get(key,{}).get(field),9400))
                raw=struct.pack('<i',dest-site-size)
            elif field.startswith('bl'):raw=branch(site,base+getters.get(links.get(key,{}).get(field),2400))
            elif field.startswith('b_'):raw=struct.pack('<H',0xe000|(((base+512-site-4)//2)&2047))
            elif field.startswith('vldr'):raw=bytes.fromhex('1fed0dba')
            else:
                target,pc=(tables['sun_rgb'],0x30) if key=='sun' and field in ['movw_1e','movt_26'] else (tables['planet_rgb'],0xe) if key=='planet_table' else (tables['rim_rgb'],0x10) if key=='rim' else (9400,0xc)
                relative=(target-at-pc)&0xffffffff;meta=reader.ARM_FIELDS[name][field]
                raw=arm_wide(relative>>16 if meta['kind']=='movt' else relative&65535,int(meta['register'][1:]),meta['kind']=='movt')
            body[off:off+size]=raw
        data[256+at:256+at+len(body)]=body;blocks[key]=(at,body,fields)
    raw_getters=({'system':'554889e5488b87280200005dc3','sky_index':'554889e58b473c5dc3','station':'554889e5488b87180200005dc3','planet_type':'554889e58b471c5dc3'} if mac else {'system':'d0f890017047','sky_index':'006b7047','station':'d0f888017047','planet_type':'40697047'})
    for name,raw in raw_getters.items():data[256+getters[name]:256+getters[name]+len(bytes.fromhex(raw))]=bytes.fromhex(raw)
    expected={}
    for index,(key,count) in enumerate(reader.COUNTS.items()):
        expected[key]=[[float(index+1),float(i)/32,2.0] for i in range(count)]
        raw=b''.join(struct.pack('<3f',*row) for row in expected[key]);at=256+tables[key];data[at:at+len(raw)]=raw
    text={'name':b'__text','segment':b'__TEXT','address':base,'offset':256,'length':4096}
    const={'name':b'__const','segment':b'__TEXT','address':base+8192,'offset':256+8192,'length':2048}
    m=SimpleNamespace(architecture='x86_64' if mac else 'armv7',data=bytes(data),slice_offset=16384,text=text,sections=[text,const])
    sky={'provenance':{'system':{'offset':16384+256+getters['system']}}}
    return m,sky,blocks,expected


class EnvironmentColors(unittest.TestCase):
    def test_relocated_independent_tables(self):
        for mac in [True,False]:
            for shift in [0,0x250000]:
                m,sky,_,expected=fixture(mac,shift);result=reader.extract_environment_colors(m,sky)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({key:result[key] for key in expected},expected)
                self.assertEqual(result['provenance']['sun_rgb'],{'offset':24832,'bytes':228})

    def test_invalid_contexts_and_tables(self):
        for mac in [True,False]:
            for bad in ['sun','planet','rim','system','getter','duplicate','negative','nan','infinity','oversized','missing','extent','link','overlap']:
                with self.subTest(mac=mac,bad=bad):
                    m,sky,blocks,_=fixture(mac);data=bytearray(m.data)
                    if bad in ['sun','planet','rim']:data[256+blocks[bad][0]+(8 if bad=='sun' and not mac else 0)]^=1
                    elif bad=='system':sky['provenance']['system']['offset']+=4
                    elif bad=='getter':data[256+2320]^=1
                    elif bad=='duplicate':
                        _,body,_=blocks['sun'];data[256+1100:256+1100+len(body)]=body
                    elif bad in ['negative','nan','infinity','oversized']:
                        data[256+8192:256+8196]=struct.pack('<f',{'negative':-1,'nan':float('nan'),'infinity':float('inf'),'oversized':17}[bad])
                    elif bad=='missing':sky={}
                    elif bad=='extent':m.sections[1]['length']=512
                    else:
                        at,_,fields=blocks['planet' if bad=='link' else 'rim'];field=('call_12' if mac else 'bl_6') if bad=='link' else ('ref_0' if mac else 'movw_0');off,size=fields[field];site=m.text['address']+at+off
                        dest=m.text['address']+(2240 if bad=='link' else 8192)
                        raw=(struct.pack('<i',dest-site-4) if mac else branch(site,dest)) if bad=='link' else struct.pack('<i',dest-site-4) if mac else arm_wide((8192-at-0x10)&65535,0,False)
                        data[256+at+off:256+at+off+size]=raw
                    m.data=bytes(data);self.assertEqual(reader.extract_environment_colors(m,sky),{})


LIGHT = '_ZN10StarSystem9initLightEv'
COLOR_GETTERS = {'_ZN6Status9getSystemEv': 0x1a0, '_ZN11SolarSystem15getTextureIndexEv': 0x30, '_ZN6Status10getStationEv': 0x198,
                 '_ZN7Station15getTextureIndexEv': 0x14}


def ldrb_w(asm, rt, rn, offset): return asm.half(0xf890 | rn, rt << 12 | offset)


def stm_w(asm, rn, *registers): return asm.half(0xe880 | rn, sum(1 << r for r in registers))


def android(name=LIGHT, copies=('sun', 'planet', 'rim'), read='table', tables=None, getters=COLOR_GETTERS, planet_at=0x100, shifts=(1, 1), rim=(6, 4, 10)):
    """initLight's sun row, rim row and the shared planet table read in the Android compiler's shape."""
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm, build
    from test_opening_sky import getter
    asm = Asm(TEXT + 0x100).push()

    def status(getter_name, index_name):
        asm.ldr_address(0, RODATA + 0xf00).add_pc(0).ldr(0, 0, 0).ldr(0, 0, 0).call_to(getter_name).call_to(index_name)
        ldrb_w(asm, 1, 8, 0x28)

    for _ in range(copies.count('sun')):
        status('_ZN6Status9getSystemEv', '_ZN11SolarSystem15getTextureIndexEv')
        asm.add_reg(4, 0, 0, shifts[0]).cmp(1, 0).it('eq').movs(5, 1).ldr_address(0, RODATA).add_imm(10, 4, 1).adds(6, 4, 2).vldr_pc(22, 0x3e19999a)
        asm.add_pc(0).cmp(5, 1).ldr_index(1, 0, 10).ldr_index(2, 0, 6).ldr_index(0, 0, 4)
        stm_w(asm, 8, 0, 1, 2)
    asm.nop().label('table').ldr_address(2, RODATA + planet_at).vmov_imm(24, 0x2e).cmp(1, 0).add_pc(2).add_reg(0, 2, 0, 2)
    asm.vldr(16, 0, 0).vldr(18, 0, 4).vldr(20, 0, 8).label('other').nop()
    for _ in range(copies.count('rim')):
        asm.ldr_address(0, RODATA + 0x300).vmov_imm(0, 0x08).add_pc(0).add_reg(1, 0, rim[0], 2).add_reg(2, 0, rim[1], 2).add_reg(0, 0, rim[2], 2)
        asm.vldr(2, 2, 0).vldr(4, 0, 0).ldr_w(0, 9, 0).vmul(22, 2, 0).vldr(6, 1, 0).vmul(17, 4, 0).vmul(19, 6, 0)
        asm.call_to('_ZN11AbyssEngine18ApplicationManager9GetEngineEv').vmov_core(1, 22).vmov_core(2, 17).vmov_core(3, 19)
        asm.call_to('_ZN11AbyssEngine6Engine16LightSetRimColorEfff')
    for _ in range(copies.count('planet')):
        status('_ZN6Status10getStationEv', '_ZN7Station15getTextureIndexEv')
        asm.add_reg(0, 0, 0, shifts[1]).branch(None, read)
    functions = {name: asm.pop()}
    functions.update((key, getter(key, field, TEXT + 0xc00 + 0x10 * n)) for n, (key, field) in enumerate(getters.items()))
    rows = tables or {key: [[float(index + 1), i / 32, 2.0] for i in range(count)] for index, (key, count) in enumerate(reader.COUNTS.items())}
    data = {RODATA + at: b''.join(struct.pack('<3f', *row) for row in rows[key]) for at, key in ((0, 'sun_rgb'), (0x100, 'planet_rgb'), (0x300, 'rim_rgb'))}
    return build(functions, data), rows


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidEnvironmentColors(unittest.TestCase):
    SKY = {'provenance': {'system': {'offset': 1, 'bytes': 6}}}

    def test_encodings_decode_as_intended(self):
        import capstone
        from android_thumb import Asm
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        for emit, expected in [(lambda a: ldrb_w(a, 1, 8, 0x28), 'ldrb.w r1, [r8, #0x28]'), (lambda a: stm_w(a, 8, 0, 1, 2), 'stm.w r8, {r0, r1, r2}')]:
            asm = Asm(0x2000)
            emit(asm)
            self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoder.disasm(bytes(asm.code), 0x2000)], [expected])

    def test_rows_and_spans(self):
        from android_fixture import RODATA, TEXT
        lib, rows = android()
        value = reader.extract_environment_colors(lib, self.SKY)
        self.assertEqual({k: v for k, v in value.items() if k != 'provenance'}, rows)
        start = lib.symbols[LIGHT][0]
        self.assertEqual(value['provenance'], {
            'sun': {'offset': start + 2, 'bytes': 62}, 'planet_table': {'offset': start + 66, 'bytes': 26},
            'rim': {'offset': start + 94, 'bytes': 68}, 'planet': {'offset': start + 162, 'bytes': 26},
            'system': {'offset': TEXT + 0xc00, 'bytes': 6}, 'sky_index': {'offset': TEXT + 0xc10, 'bytes': 4},
            'station': {'offset': TEXT + 0xc20, 'bytes': 6}, 'planet_type': {'offset': TEXT + 0xc30, 'bytes': 4},
            'sun_rgb': {'offset': RODATA, 'bytes': 228}, 'planet_rgb': {'offset': RODATA + 0x100, 'bytes': 324},
            'rim_rgb': {'offset': RODATA + 0x300, 'bytes': 228}})
        self.assertEqual(reader.extract_environment_colors(lib, {}), {})
        self.assertEqual(reader.extract_environment_colors(lib, None), {})
        self.assertEqual(reader.extract_environment_colors(lib, {'provenance': {'cursor': {}}}), {})

    def test_each_broken_shape_is_unsupported(self):
        def table(key, value):
            rows = android()[1]
            rows[key][3][1] = value
            return rows
        cases = {'name': dict(name='_ZN10StarSystem6renderEv'), 'two suns': dict(copies=('sun', 'sun', 'planet', 'rim')),
                 'two planets': dict(copies=('sun', 'planet', 'planet', 'rim')), 'two rims': dict(copies=('sun', 'planet', 'rim', 'rim')),
                 'no sun': dict(copies=('planet', 'rim')), 'read elsewhere': dict(read='other'),
                 'negative': dict(tables=table('planet_rgb', -1.0)), 'nan': dict(tables=table('rim_rgb', float('nan'))),
                 'oversized': dict(tables=table('sun_rgb', 17.0)), 'table outside': dict(planet_at=0x2000),
                 'sun row': dict(shifts=(2, 1)), 'planet row': dict(shifts=(1, 2)), 'rim row': dict(rim=(4, 6, 10)),
                 'getter': dict(getters={k: v for k, v in COLOR_GETTERS.items() if k != '_ZN7Station15getTextureIndexEv'})}
        for name, options in cases.items():
            self.assertEqual(reader.extract_environment_colors(android(**options)[0], self.SKY), {}, name)
