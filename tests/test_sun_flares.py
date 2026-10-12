"""Relocated synthetic flare declarations; no original assets or tables."""
import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import sun_flares as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch

COLORS=[[70,71,69],[73,72,74],[76,75,77],[64,67,68],[79,80,78],[64,65,66]]

def fixture(mac,shift=0):
    base=0x100000+shift;data=bytearray(12000);blocks={}
    locations={'resources':64,'system_type':256,'palette':512}
    if not mac:locations['fallback']=512+0x48
    getters={'system':2000,'system_id':2040}
    tables={'system_types':8192,'red':8400,'green':8500,'blue':8600,'palette_selectors':2500}
    for key,at in locations.items():
        name=('MAC_' if mac else 'ARM_')+key.upper();body,fields=expand(getattr(reader,name));color_index=0
        for field,(off,size) in fields.items():
            site=base+at+off
            if mac:
                if field.startswith('value_'):raw=struct.pack('<I',64+color_index);color_index+=1
                elif field.startswith('id_'):raw=struct.pack('<I',200)
                else:
                    dest=2200
                    if key=='system_type':dest=getters['system' if field=='call_6' else 'system_id'] if field.startswith('call') else tables['system_types']
                    elif key=='palette':dest=tables['palette_selectors']
                    raw=struct.pack('<i',base+dest-site-size)
            else:
                kind,register=reader.ARM_FIELDS[name][field]
                reg={'fp':11,'sl':10}.get(register,int(register[1:]) if register and register.startswith('r') else 0)
                if kind=='bl':
                    dest=getters['system' if field=='bl_4' else 'system_id'] if key=='system_type' else 2200
                    raw=branch(site,base+dest)
                elif kind=='add.w':raw=struct.pack('<HH',0xf106,0x01c8)
                elif kind=='mov.w':raw=struct.pack('<HH',0xf04f,(reg<<8)+COLORS[5][{10:0,8:1,11:2}[reg]])
                else:
                    if key=='system_type':dest=tables['system_types'];pc=0x1a
                    elif key=='palette':
                        group={'r0':('red',0x20),'r1':('green',0x22),'r2':('blue',0x24)}[register]
                        dest=tables[group[0]];pc=group[1]
                    else:dest=2300;pc=14
                    relative=(dest-at-pc)&0xffffffff
                    value=relative>>16 if kind=='movt' else relative&65535
                    raw=arm_wide(value,reg,kind=='movt')
            body[off:off+size]=raw
        data[256+at:256+at+len(body)]=body;blocks[key]=(at,body,fields)
    raws={'system':'554889e5488b87280200005dc3','system_id':'554889e58b47205dc3'} if mac else {'system':'d0f890017047','system_id':'40697047'}
    for key,raw in raws.items():data[256+getters[key]:256+getters[key]+len(bytes.fromhex(raw))]=bytes.fromhex(raw)
    for index in range(3):
        at=2800+index*128;body,fields=expand(reader.MAC_IMAGE if mac else reader.ARM_IMAGE)
        for field,(off,size) in fields.items():
            if mac:
                if field.startswith('call'):raw=struct.pack('<i',2200-at-off-size)
                elif field.startswith('slot'):raw=struct.pack('<i',-800+index*8)
                else:raw=struct.pack('<H',{'value_17':4000+index,'value_1c':10+index,'value_22':200+index}[field])
            elif field=='blx_2':
                raw=bytearray(branch((base+at+off)&~3,base+2200));raw[3]&=~0x10
            elif field.startswith('number'):
                raw=arm_wide({'number_8':4000+index,'number_10':10+index,'number_14':200+index}[field],3 if field=='number_14' else 2,field=='number_10')
            else:raw=struct.pack('<HH',0xf8d5,((1 if field=='ldr_w_1c' else 2)<<12)+0x120+index*4)
            body[off:off+size]=raw
        data[256+at:256+at+len(body)]=body;blocks['image_'+str(index)]=(at,body,fields)
    values=[i%6 for i in range(34)]
    data[256+8192:256+8192+136]=struct.pack('<34I',*values)
    if mac:
        offsets=[512+v-2500 for v in [0x37,0x4a,0x5d,0x81,0x70]]
        data[256+2500:256+2520]=struct.pack('<5i',*offsets)
    else:
        for index,key in enumerate(['red','green','blue']):
            at=256+tables[key];data[at:at+20]=struct.pack('<5I',*(row[index] for row in COLORS[:5]))
    text={'name':b'__text','segment':b'__TEXT','address':base,'offset':256,'length':4096}
    const={'name':b'__const','segment':b'__TEXT','address':base+8192,'offset':256+8192,'length':2048}
    mach=SimpleNamespace(architecture='x86_64' if mac else 'armv7',data=bytes(data),slice_offset=16384,text=text,sections=[text,const])
    sky={'provenance':{key:{'offset':16384+256+at} for key,at in getters.items()}}
    expected={'scope':'ordinary_sun_flares','image_ids':[200,201,202],'images':[{'id':200+i,'texture_id':4000+i,'region':10+i} for i in range(3)],'system_types':values,'colors':COLORS}
    return mach,sky,blocks,expected

class SunFlares(unittest.TestCase):
    def test_relocated_changed_data(self):
        for mac in [True,False]:
            for shift in [0,0x350000]:
                m,sky,_,expected=fixture(mac,shift);result=reader.extract_sun_flares(m,sky)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({key:result[key] for key in expected},expected)

    def test_fail_closed(self):
        for mac in [True,False]:
            for bad in ['resources','system_type','palette','image_0','image_1','image_2','duplicate','duplicate_image','getter','link','types','color','truncated','missing','selector']:
                with self.subTest(mac=mac,bad=bad):
                    m,sky,blocks,_=fixture(mac);data=bytearray(m.data)
                    if bad in blocks:data[256+blocks[bad][0]+(8 if bad=='resources' and not mac else 0)]^=1
                    elif bad=='duplicate':
                        body=blocks['resources'][1];data[256+1000:256+1000+len(body)]=body
                    elif bad=='duplicate_image':
                        body=blocks['image_0'][1];data[256+1600:256+1600+len(body)]=body
                    elif bad=='getter':data[256+2040]^=1
                    elif bad=='link':sky['provenance']['system_id']['offset']+=4
                    elif bad=='types':struct.pack_into('<I',data,256+8192,6)
                    elif bad=='color':
                        if mac:
                            at,_,fields=blocks['palette'];off,_=fields['value_0'];struct.pack_into('<I',data,256+at+off,256)
                        else:struct.pack_into('<I',data,256+8400,256)
                    elif bad=='truncated':m.sections[1]['length']=135
                    elif bad=='missing':sky={}
                    elif mac:struct.pack_into('<i',data,256+2500,1)
                    else:data[256+512+0x48]=0
                    m.data=bytes(data)
                    self.assertEqual(reader.extract_sun_flares(m,sky),{})


FLARE = '_ZN9LensFlareC1EPN11AbyssEngine11PaintCanvasE'
RENDER = '_ZN9LensFlare8render2DEfffi'
RESOURCES = '_Z17BuildResourceListPN11AbyssEngine6EngineE'
FLARE_GETTERS = {'_ZN6Status9getSystemEv': 0x1a0, '_ZN11SolarSystem8getIndexEv': 0x14}
TYPES = [3, 1, 3, 2, 0, 3, 1, 4, 2, 4, 1, 3, 1, 3, 2, 3, 3, 0, 2, 1, 2, 3, 2, 0, 3, 1, 2, 5, 3, 3, 3, 3, 3, 3]
CHANNELS = [[200, 200, 255, 255, 255], [200, 255, 200, 255, 255], [255, 200, 200, 255, 200]]


def uxtb_w(asm, rd, rm): return asm.half(0xfa5f, 0xf080 | rd << 8 | rm)


def vsub(asm, sd, sn, sm):
    return asm.half(0xee30 | (sd & 1) << 6 | sn >> 1, (sd >> 1) << 12 | 0xa40 | (sn & 1) << 7 | (sm & 1) << 5 | sm >> 1)


def vcvt_to_u(asm, sd, sm): return asm.half(0xeebc | (sd & 1) << 6, (sd >> 1) << 12 | 0xac0 | (sm & 1) << 5 | sm >> 1)


def image(asm, identifier, region, texture=None, kind=3, sentinel=True):
    """One image record; texture/kind/sentinel None keep the previous record's registers."""
    asm.movs(0, 0x10).call_to('_Znwj').mov(4, 0).movs(0, 4).call_to('_Znwj')
    if texture is not None:
        asm.movw(8, texture) if isinstance(texture, int) else asm.mov(8, 1)
    asm.movs(1, region).strh_w(8, 0, 0)
    if kind is not None:
        asm.movs(6, kind)
    asm.strh(1, 0, 2).movw(1, identifier)
    if sentinel is not None:
        asm.minus_one(5) if sentinel else asm.movs(5, 0)
    asm.strh(1, 4, 0).strd(6, 5, 4, 4).str(0, 4, 0xc).movw(0, 0x11a8 + 4 * identifier % 64)
    from test_planet_resources import str_index
    str_index(asm, 4, 10, 0, 0)


def android(first=1288, second=None, back='loop', copies=(), cmp=4, fallback='fallback', join='join', white=(0xff, 0xff, 0xff), types_at=0,
            swap=False, clobber=None, records=None, types=TYPES, channels=CHANNELS, getters=FLARE_GETTERS):
    """LensFlare's three images, the system flare type, render2D's palette and BuildResourceList's image records."""
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm, build
    from test_opening_sky import getter
    from test_planet_resources import adds_reg
    flare = Asm(TEXT + 0x100).push()
    for n in range(1 + copies.count('resources')):
        flare.movs(0, 0xc).mov(8, 1).call_to('_Znaj').mov(2, 0).ldr_address(0, RODATA + 0xf00).str_w(2, 9, 0x10)
        flare.mov_imm(1, first) if first < 256 or first == 1288 else flare.movw(1, first)
        flare.add_pc(0).ldr(0, 0, 0).ldr(0, 0, 0).call_to('_ZN11AbyssEngine11PaintCanvas13Image2DCreateEtRj')
        flare.ldr_address(0, RODATA + 0xf00).movs(6, 4).movw(5, second or first + 1).add_pc(0).ldr(4, 0, 0).label('loop%d' % n)
        flare.ldr_w(1, 9, 0x10).ldr(0, 4, 0)
        adds_reg(flare, 2, 1, 6)
        flare.uxth(1, 5).call_to('_ZN11AbyssEngine11PaintCanvas13Image2DCreateEtRj').adds8(6, 4).adds8(5, 1).cmp(6, 0xc).branch('ne', '%s%d' % (back, n))
        flare.label('other%d' % n).nop()
    system = Asm(TEXT + 0x300).push()
    for _ in range(1 + copies.count('type')):
        system.ldr(0, 4, 0).call_to('_ZN6Status9getSystemEv').call_to('_ZN11SolarSystem8getIndexEv').ldr_address(1, RODATA + types_at).add_pc(1)
        system.ldr_index(0, 1, 0).str_w(0, 9, 0x3c)
    render = Asm(TEXT + 0x500).push()
    for _ in range(1 + copies.count('palette')):
        render.ldr(5, 7, 0x18).vmov_from(0, 3).mov(4, 0).cmp(5, cmp).branch('hi', fallback)
        render.ldr_address(0, RODATA + 0x200).ldr_address(3, RODATA + 0x180).ldr_address(6, RODATA + 0x100).add_pc(0).add_pc(3).add_pc(6)
        render.ldr_index(9, 0, 5).ldr_index(10, 3, 5).ldr_index(8, 6, 5).branch(None, join)
    render.label('other').nop().label('fallback').mov_imm(8, white[2]).mov_imm(10, white[1]).mov_imm(9, white[0]).label('join')
    if clobber:
        render.mov(clobber, 1)
    render.nop()
    for _ in range(1 + copies.count('channels')):
        uxtb_w(render, 2, 9 if swap else 10)
        render.vldr_pc(26, 0x42f00000)
        uxtb_w(render, 3, 8)
        vsub(render, 0, 24, 0)
        render.ldr_address(0, RODATA + 0xf00).add_pc(0).ldr_w(11, 0, 0)
        vsub(render, 0, 26, 0)
        render.ldr_w(0, 11, 0)
        vcvt_to_u(render, 0, 0)
        render.vmov_core(1, 0).str_sp(1, 0)
        uxtb_w(render, 1, 10 if swap else 9)
        render.str_sp(1, 0x24).str_sp(2, 0x20).str_sp(3, 0x1c).call_to('_ZN11AbyssEngine11PaintCanvas8SetColorEhhhh')
    resources = Asm(TEXT + 0x900).push()
    for record in (records or [(first - 1, 186, 10062), (first, 187, None, None, None), (first + 1, 188, 10062), (first + 2, 189, None, None, None)]):
        image(resources, *record)
    functions = {FLARE: flare.pop(), '_ZN10StarSystemC1Ei': system.pop(), RENDER: render.pop(), RESOURCES: resources.pop()}
    functions.update((key, getter(key, field, TEXT + 0xe00 + 0x10 * n)) for n, (key, field) in enumerate(getters.items()))
    data = {RODATA: struct.pack('<34I', *types), RODATA + 0x200: struct.pack('<5I', *channels[0]),
            RODATA + 0x180: struct.pack('<5I', *channels[1]), RODATA + 0x100: struct.pack('<5I', *channels[2])}
    return build(functions, data)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidSunFlares(unittest.TestCase):
    SKY = {'provenance': {'system': {}, 'system_id': {}}}

    def test_encodings_decode_as_intended(self):
        import capstone
        from android_thumb import Asm
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        for emit, expected in [(lambda a: uxtb_w(a, 2, 10), 'uxtb.w r2, sl'), (lambda a: vsub(a, 0, 24, 0), 'vsub.f32 s0, s24, s0'),
                               (lambda a: vcvt_to_u(a, 0, 0), 'vcvt.u32.f32 s0, s0')]:
            asm = Asm(0x2000)
            emit(asm)
            self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoder.disasm(bytes(asm.code), 0x2000)], [expected])

    def test_images_types_colors_and_spans(self):
        from android_fixture import RODATA, TEXT
        lib = android()
        value = reader.extract_sun_flares(lib, self.SKY)
        self.assertEqual({k: v for k, v in value.items() if k != 'provenance'}, {
            'scope': 'ordinary_sun_flares', 'image_ids': [1288, 1289, 1290], 'system_types': TYPES,
            'images': [{'id': 1288 + i, 'texture_id': 10062, 'region': 187 + i} for i in range(3)],
            'colors': [[200, 200, 255], [200, 255, 200], [255, 200, 200], [255, 255, 255], [255, 255, 200], [255, 255, 255]]})
        code = {name: lib.symbols[name][0] for name in (FLARE, '_ZN10StarSystemC1Ei', RENDER, RESOURCES)}
        self.assertEqual(value['provenance'], {
            'resources': {'offset': code[FLARE] + 2, 'bytes': 64}, 'system_type': {'offset': code['_ZN10StarSystemC1Ei'] + 2, 'bytes': 22},
            'palette': {'offset': code[RENDER] + 2, 'bytes': 38}, 'fallback': {'offset': code[RENDER] + 42, 'bytes': 12},
            'channels': {'offset': code[RENDER] + 56, 'bytes': 56}, 'images': {'offset': code[RESOURCES] + 16, 'bytes': 174},
            'system': {'offset': TEXT + 0xe00, 'bytes': 6}, 'system_id': {'offset': TEXT + 0xe10, 'bytes': 4},
            'system_types': {'offset': RODATA, 'bytes': 136}, 'red': {'offset': RODATA + 0x200, 'bytes': 20},
            'green': {'offset': RODATA + 0x180, 'bytes': 20}, 'blue': {'offset': RODATA + 0x100, 'bytes': 20}})
        self.assertEqual(reader.extract_sun_flares(android(white=(0xff, 0xfe, 0xfd)), self.SKY)['colors'][5], [0xff, 0xfe, 0xfd])
        for sky in (None, {}, {'provenance': {'system': {}}}, {'provenance': {'system_id': {}}}):
            self.assertEqual(reader.extract_sun_flares(lib, sky), {})

    def test_each_broken_shape_is_unsupported(self):
        base = [(1287, 186, 10062), (1288, 187, None, None, None), (1289, 188, 10062), (1290, 189, None, None, None)]
        cases = {'second': dict(second=1290), 'loop': dict(back='other'), 'first': dict(first=65532), 'selector': dict(cmp=3),
                 'fallback target': dict(fallback='other'), 'join': dict(join='other'), 'white': dict(white=(0x100, 0xff, 0xff)), 'types outside': dict(types_at=0x2000),
                 'no source': dict(records=[(1288, 187, None, None, None), (1289, 188, 10062), (1290, 189, None, None, None)]),
                 'channel order': dict(swap=True), 'clobbered red': dict(clobber=9), 'clobbered green': dict(clobber=10), 'clobbered blue': dict(clobber=8),
                 'texture source': dict(records=[(1287, 186, 'r1')] + base[1:]), 'kind': dict(records=[(1287, 186, 10062, 2)] + base[1:]),
                 'sentinel': dict(records=[(1287, 186, 10062, 3, False)] + base[1:]), 'missing image': dict(records=base[:3]),
                 'duplicate image': dict(records=base + [(1289, 190, 10062)]), 'big texture': dict(records=[(1287, 186, 65534)] + base[1:]),
                 'types': dict(types=TYPES[:5] + [6] + TYPES[6:]), 'color': dict(channels=[CHANNELS[0], [200, 256, 200, 255, 255], CHANNELS[2]]),
                 'getter': dict(getters={'_ZN6Status9getSystemEv': 0x1a0})}
        for part in ('resources', 'type', 'palette', 'channels'):
            cases['two ' + part] = dict(copies=(part,))
        for name, options in cases.items():
            self.assertEqual(reader.extract_sun_flares(android(**options), self.SKY), {}, name)
