"""Synthetic planet lookup contexts and tables, with relocated pointers."""
import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import planet_resources as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac,shift=0):
    base=0x100000+shift;data=bytearray(12000);blocks={}
    locations={'sun':64,'current':256 if mac else 384,'near':384 if mac else 256,'far':512,'mesh':768}
    getters={'system':2000,'sky_index':2040,'cursor':2080,'planet_type':2120}
    tables={'sun_textures':8192,'near_textures':8300,'far_textures':8450}
    links={'sun':{'call_a':'system','bl_a':'system','call_12':'sky_index','bl_10':'sky_index'},'current':{'call_3':'cursor','bl_8':'cursor'},'near':{'call_14':'planet_type','bl_14':'planet_type'},'far':{'call_14':'planet_type','bl_12':'planet_type'}}
    table_fields={'sun':'ref_1a','near':'ref_2d','far':'ref_2d'}
    table_names={'sun':'sun_textures','near':'near_textures','far':'far_textures'}
    for key,at in locations.items():
        name=('MAC_' if mac else 'ARM_')+key.upper();body,fields=expand(getattr(reader,name))
        for field,(off,size) in fields.items():
            site=base+at+off
            if mac:
                if field.startswith('id_'):raw=struct.pack('<I',6010 if key=='mesh' else 6011)
                else:
                    dest=base+(getters.get(links.get(key,{}).get(field),2200) if field.startswith('call') else tables[table_names[key]] if field==table_fields.get(key) else 9400)
                    raw=struct.pack('<i',dest-site-size)
            elif field.startswith('bl_'):raw=branch(site,base+getters.get(links.get(key,{}).get(field),2200))
            else:
                kind,register=reader.ARM_FIELDS[name][field]
                if key in ['current','mesh']:value=6010 if key=='mesh' else 6011
                else:
                    pc={'sun':0x22,'near':0x30,'far':0x2e}[key]
                    relative=(tables[table_names[key]]-at-pc)&0xffffffff
                    value=relative>>16 if kind=='movt' else relative&65535
                raw=arm_wide(value,int(register[1:]),kind=='movt')
            body[off:off+size]=raw
        data[256+at:256+at+len(body)]=body;blocks[key]=(at,body,fields)
    raws={'system':'554889e5488b87280200005dc3','sky_index':'554889e58b473c5dc3','cursor':'554889e58b87780200005dc3','planet_type':'554889e58b471c5dc3'} if mac else {'system':'d0f890017047','sky_index':'006b7047','cursor':'d0f8d4017047','planet_type':'40697047'}
    for key,raw in raws.items():data[256+getters[key]:256+getters[key]+len(bytes.fromhex(raw))]=bytes.fromhex(raw)
    expected={'scope':'fresh_opening_planet_resources','mesh_id':6010,'opening_texture_id':6011}
    for n,(key,count) in enumerate(reader.COUNTS.items()):
        expected[key]=[20000+n*100+i*3 for i in range(count)]
        start=256+tables[key];data[start:start+4*count]=struct.pack('<'+str(count)+'I',*expected[key])
    text={'name':b'__text','segment':b'__TEXT','address':base,'offset':256,'length':4096}
    const={'name':b'__const','segment':b'__TEXT','address':base+8192,'offset':256+8192,'length':2048}
    mach=SimpleNamespace(architecture='x86_64' if mac else 'armv7',data=bytes(data),slice_offset=16384,text=text,sections=[text,const])
    sky={'provenance':{k:{'offset':16384+256+getters[k]} for k in ['system','cursor']}}
    colors={'provenance':{k:{'offset':16384+256+getters[k]} for k in ['sky_index','planet_type']}}
    return mach,sky,colors,blocks,expected

class PlanetResources(unittest.TestCase):
    def test_relocated_independent_tables(self):
        for mac in [True,False]:
            for shift in [0,0x350000]:
                mach,sky,colors,_,expected=fixture(mac,shift)
                result=reader.extract_planet_resources(mach,sky,colors)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({k:result[k] for k in expected},expected)
                self.assertEqual(result['provenance']['sun_textures'],{'offset':24832,'bytes':76})

    def test_reject_corrupt_selectors_tables_and_links(self):
        for mac in [True,False]:
            for bad in ['sun','current','near','far','mesh','duplicate','system','cursor','getter','table_id','mesh_id','truncated','missing','register_link','table_overlap']:
                with self.subTest(mac=mac,bad=bad):
                    mach,sky,colors,blocks,_=fixture(mac);data=bytearray(mach.data)
                    if bad in blocks:data[256+blocks[bad][0]]^=1
                    elif bad=='duplicate':
                        body=blocks['sun'][1];data[256+1100:256+1100+len(body)]=body
                    elif bad in ['system','cursor']:sky['provenance'][bad]['offset']+=4
                    elif bad=='getter':data[256+2120]^=1
                    elif bad=='table_id':data[256+8192:256+8196]=struct.pack('<I',65534)
                    elif bad=='mesh_id':
                        at,_,fields=blocks['mesh'];off,size=fields['id_1a' if mac else 'movw_a']
                        data[256+at+off:256+at+off+size]=struct.pack('<I',65534) if mac else arm_wide(65534,1,False)
                    elif bad=='truncated':mach.sections[1]['length']=100
                    elif bad=='missing':colors={}
                    elif bad=='register_link':
                        at,_,fields=blocks['far'];off,size=fields['call_3d' if mac else 'bl_36'];site=mach.text['address']+at+off;dest=mach.text['address']+2250
                        data[256+at+off:256+at+off+size]=struct.pack('<i',dest-site-size) if mac else branch(site,dest)
                    else:
                        at,_,fields=blocks['far'];off,size=fields['ref_2d' if mac else 'movw_1e'];site=mach.text['address']+at+off
                        data[256+at+off:256+at+off+size]=struct.pack('<i',mach.text['address']+8192-site-size) if mac else arm_wide((8192-at-0x2e)&65535,1,False)
                    mach.data=bytes(data)
                    self.assertEqual(reader.extract_planet_resources(mach,sky,colors),{})


SYSTEM = '_ZN10StarSystemC1Ei'
TEXTURE = '_ZN11AbyssEngine11PaintCanvas13TextureCreateEtRjb'
PLANET_GETTERS = {'_ZN6Status9getSystemEv': 0x1a0, '_ZN11SolarSystem15getTextureIndexEv': 0x30,
                  '_ZN6Status25getCurrentCampaignMissionEv': 0x1e8, '_ZN7Station15getTextureIndexEv': 0x14}


def adds_reg(asm, rd, rn, rm): return asm.half(0x1800 | rm << 6 | rn << 3 | rd)


def str_index(asm, rt, rn, rm, shift=2): return asm.half(0xf840 | rn, rt << 12 | shift << 4 | rm)  # str.w rt, [rn, rm, lsl #s]


def android(name=SYSTEM, copies=('sun', 'current', 'far', 'near', 'mesh'), targets=('far', 'near', 'tail'), world=3, ids=(6768, 10043),
            big=None, getters=PLANET_GETTERS, near_at=0x100):
    """The constructor's sun texture, per-station planet textures and planet mesh in the Android compiler's shape."""
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm, build
    from test_opening_sky import getter
    asm = Asm(TEXT + 0x100).push()

    def planet(table, slot, early):
        asm.ldr_w(0, 8, 4).ldr_sp(1, slot).ldr_index(0, 0, 11).ldr(5, 1, 0).call_to('_ZN7Station15getTextureIndexEv').ldr_sp_w(10, 0x70)
        if early:
            asm.movs(3, 0)
        asm.ldr_w(1, 10, 0x14).ldr(2, 1, 4).ldr_address(1, table).add_low(2, 4).add_pc(1).ldrh_index(1, 1, 0, 2).mov(0, 5)
        if not early:
            asm.label('tail').movs(3, 0)
        asm.call_to(TEXTURE)

    for part in copies:
        if part == 'sun':
            asm.ldr_address(0, RODATA + 0xf00).ldr_address(1, RODATA + 0xf04).add_pc(0).add_pc(1).ldr(0, 0, 0).ldr(4, 1, 0).ldr(5, 0, 0)
            asm.ldr(0, 4, 0).call_to('_ZN6Status9getSystemEv').call_to('_ZN11SolarSystem15getTextureIndexEv').ldr_address(1, RODATA)
            asm.movs(3, 0).ldr_w(2, 9, 0x14).add_pc(1).ldrh_index(1, 1, 0, 2).mov(0, 5).ldr(2, 2, 4).call_to(TEXTURE)
        elif part == 'current':
            asm.ldr_index(5, 0, 11).ldr_sp(0, 0x68).ldr(0, 0, 0).call_to('_ZN6Status10getStationEv').add_imm(9, 11, 1)
            asm.call_to('_ZN7Station8getIndexEv').cmp_reg(5, 0).branch('ne', targets[0]).ldr_sp(0, 0x60).ldr(0, 0, 0)
            asm.call_to('_ZN6Status25getCurrentCampaignMissionEv').ldr_sp(1, 0x64).cmp(1, world).it('eq').cmp(0, 0).branch('ne', targets[1])
            asm.ldr_sp_w(10, 0x70).str_w(9, 10, 0x50).ldr_w(0, 10, 0x14).ldr(1, 0, 4).ldr_sp(0, 0x50)
            adds_reg(asm, 2, 1, 4)
            asm.movw(1, ids[1]).ldr(0, 0, 0).branch(None, targets[2])
        elif part == 'far':
            asm.label('far')
            planet(RODATA + 0x200, 0x5c, True)
            asm.label('other').nop().nop()
        elif part == 'near':
            asm.label('near')
            planet(RODATA + near_at, 0x4c, False)
        else:
            asm.movs(0, 0xc0).call_to('_Znwj').mov(6, 0).ldr_sp(0, 0x64).ldr(2, 0, 0).mov(0, 6).movw(1, ids[0]).movs(3, 0)
            asm.call_to('_ZN10AEGeometryC1EtPN11AbyssEngine11PaintCanvasEb').ldr_w(0, 9, 0x1c).ldr(0, 0, 4)
            str_index(asm, 6, 0, 8)
    functions = {name: asm.pop()}
    functions.update((key, getter(key, field, TEXT + 0xc00 + 0x10 * n)) for n, (key, field) in enumerate(getters.items()))
    tables = {'sun_textures': list(range(10031, 10050)), 'near_textures': list(range(10042, 10069)), 'far_textures': list(range(10011, 10038))}
    if big:
        tables[big][5] = 65534
    data = {RODATA + at: struct.pack('<%dI' % len(tables[key]), *tables[key]) for at, key in ((0, 'sun_textures'), (0x100, 'near_textures'), (0x200, 'far_textures'))}
    return build(functions, data), tables


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidPlanetResources(unittest.TestCase):
    SKY = {'provenance': {'system': {}, 'cursor': {}}}
    COLORS = {'provenance': {'sky_index': {}, 'planet_type': {}}}

    def test_encodings_decode_as_intended(self):
        import capstone
        from android_thumb import Asm
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        for emit, expected in [(lambda a: adds_reg(a, 2, 1, 4), 'adds r2, r1, r4'), (lambda a: str_index(a, 6, 0, 8), 'str.w r6, [r0, r8, lsl #2]')]:
            asm = Asm(0x2000)
            emit(asm)
            self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoder.disasm(bytes(asm.code), 0x2000)], [expected])

    def test_tables_ids_and_spans(self):
        from android_fixture import RODATA, TEXT
        lib, tables = android()
        value = reader.extract_planet_resources(lib, self.SKY, self.COLORS)
        self.assertEqual({k: v for k, v in value.items() if k != 'provenance'},
                         dict(tables, scope='fresh_opening_planet_resources', mesh_id=6768, opening_texture_id=10043))
        start = lib.symbols[SYSTEM][0]
        self.assertEqual(value['provenance'], {
            'sun': {'offset': start + 2, 'bytes': 46}, 'current': {'offset': start + 48, 'bytes': 68},
            'far': {'offset': start + 116, 'bytes': 44}, 'near': {'offset': start + 164, 'bytes': 44}, 'mesh': {'offset': start + 208, 'bytes': 34},
            'system': {'offset': TEXT + 0xc00, 'bytes': 6}, 'sky_index': {'offset': TEXT + 0xc10, 'bytes': 4},
            'cursor': {'offset': TEXT + 0xc20, 'bytes': 6}, 'planet_type': {'offset': TEXT + 0xc30, 'bytes': 4},
            'sun_textures': {'offset': RODATA, 'bytes': 76}, 'near_textures': {'offset': RODATA + 0x100, 'bytes': 108},
            'far_textures': {'offset': RODATA + 0x200, 'bytes': 108}})
        for sky, colors in ((None, self.COLORS), (self.SKY, None), ({'provenance': {'system': {}}}, self.COLORS),
                            (self.SKY, {'provenance': {'planet_type': {}}}), ({'provenance': {'cursor': {}}}, self.COLORS),
                            (self.SKY, {'provenance': {'sky_index': {}}})):
            self.assertEqual(reader.extract_planet_resources(lib, sky, colors), {})

    def test_each_broken_shape_is_unsupported(self):
        cases = {'name': dict(name='_ZN10StarSystem9initLightEv'), 'world': dict(world=4),
                 'far target': dict(targets=('other', 'near', 'tail')), 'near target': dict(targets=('far', 'other', 'tail')),
                 'tail target': dict(targets=('far', 'near', 'near')), 'big table': dict(big='far_textures'),
                 'big sun': dict(big='sun_textures'), 'big mesh': dict(ids=(65534, 10043)), 'big opening': dict(ids=(6768, 65534)),
                 'table outside': dict(near_at=0x2000), 'getter': dict(getters={k: v for k, v in PLANET_GETTERS.items() if k != '_ZN6Status9getSystemEv'})}
        for part in ('sun', 'current', 'mesh'):
            cases['two ' + part] = dict(copies=('sun', 'current', 'far', 'near', 'mesh', part))
        for name, options in cases.items():
            self.assertEqual(reader.extract_planet_resources(android(**options)[0], self.SKY, self.COLORS), {}, name)
