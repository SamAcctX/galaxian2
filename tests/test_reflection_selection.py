"""Independent identifiers and relocated linked contexts; no proprietary fixture."""
import struct
import unittest
from types import SimpleNamespace
from gof2_content import reflection_selection as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac,shift=0,alternate=False):
    base=0x100000+shift;data=bytearray(10000);blocks={};locations={'select':64,'bind':512}
    links=({'call_a':1800,'call_2f':1900,'call_37':2000,'call_4d':3000,'call_59':512} if mac else {'call_14':1800,'call_30':1900,'call_36':2000,'call_4a':3000,'call_5a':512})
    for key,at in locations.items():
        name=('MAC_' if mac else 'ARM_')+key.upper()
        body,fields=expand(reader.MAC_BIND_ALTERNATE if mac and alternate and key=='bind' else getattr(reader,name))
        for field,(off,size) in fields.items():
            site=base+at+off
            if mac:
                if field in ['texture_base','special_id']:raw=struct.pack('<I',22000 if field=='texture_base' else 31000)
                else:raw=struct.pack('<i',base+(links.get(field,3000) if key=='select' and field.startswith('call_') else 3000)-site-size)
            else:
                meta=reader.ARM_FIELDS[name][field];kind=meta['kind']
                if field.startswith('call_'):
                    target=base+(links.get(field,3000) if key=='select' else 3000)
                    raw=bytearray(branch(((site+4)&~3)-4 if kind=='blx' else site,target))
                    if kind=='blx':raw[3]&=~0x10
                else:raw=arm_wide(22000 if field=='texture_base' else 31000 if field=='special_id' else 0,int(meta['register'][1:]),kind=='movt')
            body[off:off+size]=raw
        data[256+at:256+at+len(body)]=body;blocks[key]=(at,body,fields)
    data[256+2000:256+2000+(9 if mac else 4)]=bytes.fromhex('554889e58b473c5dc3' if mac else '006b7047')
    data[256+1600:256+1600+(7 if mac else 6)]=(bytes.fromhex('31c9e8')+struct.pack('<i',3000-1607)) if mac else bytes.fromhex('0023')+branch(base+1602,base+3000)
    section={'name':b'__text','segment':b'__TEXT','address':base,'offset':256,'length':8192}
    m=SimpleNamespace(architecture='x86_64' if mac else 'armv7',slice_offset=16384,data=bytes(data),text=section,sections=[section])
    def provenance(offset,size):return {'offset':16384+256+offset,'bytes':size}
    projection={'provenance':{'predicate':provenance(1800,26 if mac else 10)}}
    sky={'provenance':{'system':provenance(1900,13 if mac else 6),'texture':provenance(1600,7 if mac else 6)}}
    return m,projection,sky,blocks


class ReflectionSelection(unittest.TestCase):
    def test_alternate_binding_keeps_linked_identifiers(self):
        for shift in [0,0x240000]:
            m,p,s,blocks=fixture(True,shift,alternate=True)
            result=reader.extract_reflection_selection(m,p,s)
            self.assertEqual({key:result.get(key) for key in ['texture_base','special_id']},{'texture_base':22000,'special_id':31000})
            self.assertEqual(result['provenance']['bind']['bytes'],310)
            for key in ['call_8b','call_13f']:
                at,_,fields=blocks['bind'];offset,_=fields[key]
                damaged=bytearray(m.data);damaged[256+at+offset]^=4
                original=m.data;m.data=bytes(damaged)
                self.assertEqual(reader.extract_reflection_selection(m,p,s),{})
                m.data=original

    def test_identifiers_and_relocation(self):
        for mac in [True,False]:
            for shift in [0,0x240000]:
                m,p,s,_=fixture(mac,shift);result=reader.extract_reflection_selection(m,p,s)
                self.assertEqual({k:result.get(k) for k in ['texture_base','special_id']},{'texture_base':22000,'special_id':31000})
                self.assertEqual(result['provenance']['select'],{'offset':16704,'bytes':94})
                self.assertEqual(result['provenance']['bind']['bytes'],330 if mac else 240)

    def test_reject_unsupported_or_unlinked_context(self):
        for mac in [True,False]:
            for bad in ['select','bind','getter','duplicate','predicate','system','load','missing','extent','identifier','bind_link','helper_link','global_link']:
                if not mac and bad=='global_link':continue
                with self.subTest(mac=mac,bad=bad):
                    m,p,s,blocks=fixture(mac);data=bytearray(m.data)
                    if bad in ['select','bind']:data[256+blocks[bad][0]+(12 if bad=='select' and not mac else 0)]^=1
                    elif bad=='getter':data[256+2000]^=1
                    elif bad=='duplicate':
                        _,body,_=blocks['select'];data[256+1024:256+1024+len(body)]=body
                    elif bad=='predicate':p['provenance']['predicate']['offset']+=4
                    elif bad=='system':s['provenance']['system']['offset']+=4
                    elif bad=='load':data[256+1600]^=1
                    elif bad=='missing':p={}
                    elif bad=='extent':m.text['length']=100
                    else:
                        key='bind' if bad=='helper_link' else 'select'
                        field=('call_8b' if mac else 'call_50') if bad=='helper_link' else 'texture_base' if bad=='identifier' else 'ref_25' if bad=='global_link' else ('call_59' if mac else 'call_5a')
                        at,_,fields=blocks[key];off,size=fields[field];site=m.text['address']+at+off
                        if bad=='identifier':raw=struct.pack('<I',65534) if mac else arm_wide(65534,1,False)
                        elif mac:raw=struct.pack('<i',m.text['address']+3500-site-size)
                        else:
                            kind=reader.ARM_FIELDS['ARM_'+key.upper()][field]['kind'];raw=bytearray(branch(((site+4)&~3)-4 if kind=='blx' else site,m.text['address']+3500))
                            if kind=='blx':raw[3]&=~0x10
                        data[256+at+off:256+at+off+size]=raw
                    m.data=bytes(data);self.assertEqual(reader.extract_reflection_selection(m,p,s),{})


GAME = '_ZN5MGame12OnInitializeEv'
SPACE = '_ZN5Level11createSpaceEv'
CUBE = '_ZN11AbyssEngine11PaintCanvas17ChangeCubeTextureEj'
LOAD = '_ZN11AbyssEngine11PaintCanvas13TextureCreateEtRjb'


def android(**bad):
    """MGame::OnInitialize's selection, Level::createSpace's opening sky load, ChangeCubeTexture and the
    getters in the Android shape; each `bad` key breaks one relation."""
    from android_fixture import TEXT
    from android_thumb import Asm, build
    status = 0x9000
    game = Asm(TEXT + 0x100).push()
    for n in range(2 if 'two selects' in bad else 1):
        game.ldr_address(0, status).add_pc(0).ldr(0, 0, 0).ldr(0, 0, 0).call_to('_ZN6Status12inAlienOrbitEv')
        game.ldr_w(5, 9, 4).cmp(0, 1).branch('ne', 'elsewhere%d' % n if 'sky target' in bad else 'sky%d' % n).add_sp(2, 4).mov(0, 5)
        game.movw(1, 12040).branch(None, 'call%d' % n if 'load target' in bad else 'load%d' % n).label('sky%d' % n)
        game.ldr_address(0, status + (4 if 'status' in bad else 0)).add_pc(0).ldr(0, 0, 0).ldr(0, 0, 0)
        game.call_to('_ZN6Status9getSystemEv').call_to('_ZN11SolarSystem15getTextureIndexEv')
        game.movw(1, 65534 if 'base range' in bad else 12030).add_low(0, 1).add_sp(2, 8 if 'slot' in bad else 4).label('elsewhere%d' % n)
        game.uxth(1, 0).mov(0, 4 if 'canvas' in bad else 5).label('load%d' % n).movs(3, 0).label('call%d' % n).call_to(LOAD)
        game.ldr_sp(1, 4).ldr_w(0, 8 if 'game' in bad else 9, 4).call_to(CUBE)
    space = Asm(TEXT + 0x400).push()
    for n in range(2 if 'two openings' in bad else 1):
        space.call_to('_ZN6Status25getCurrentCampaignMissionEv').cbz(0, 'other%d' % n, nonzero='campaign' not in bad)
        space.ldr_w(0, 10, 0xc4 if 'world field' in bad else 0xc0).cmp(0, 2 if 'world' in bad else 3).branch('ne', 'other%d' % n)
        space.ldr_address(0, 0x9100).movw(1, 17803).mov(2, 9).movs(3, 0).add_pc(0).ldr(5, 0, 0).ldr(0, 5, 0)
        space.call_to('_ZN11AbyssEngine11PaintCanvas10MeshCreateEtRjb').ldr(0, 4 if 'mesh canvas' in bad else 5, 0)
        space.add_imm(2, 11 if 'level' in bad else 10, 0x198).movw(1, 10068)
        space.branch(None, 'mid' if 'mid target' in bad else 'tail').label('other%d' % n).nop()
    space.label('tail').movs(3, 1 if 'tail' in bad else 0)
    space.labels['mid'] = space.here() + 2
    space.call_to(LOAD).ret()
    # ChangeCubeTexture: bind the selected cube to unit 7 when the shader path is on.
    cube = Asm(TEXT + 0x600).half(*([0xbf00] if 'bind start' in bad else []))
    for n in range(2 if 'bind twice' in bad else 1):
        cube.half(0xb5b0, 0xaf02).mov(5, 0).ldr_address(0, 0x9200).mov(4, 1).add_pc(0).ldr(0, 0, 0).ldrb(0, 0, 0).cbz(0, 'done%d' % n)
        cube.ldr(0, 5, 0x10).cmp_reg(0, 4).branch('ls', 'done%d' % n).ldr(0, 5, 0x14).ldr_index(0, 0, 4).ldrb(1, 0, 0x10).cbz(1, 'name%d' % n)
        cube.ldr_address(0, 0x9204).add_pc(0).ldr(0, 0, 0).str(4, 0, 0).movw(0, 0x84c6 if 'unit' in bad else 0x84c7).call_to('glActiveTexture')
        cube.ldr(0, 5, 0x14).ldr_index(0, 0, 4).ldr(1, 0, 0).movw(0, 0x84e1 if 'target' in bad else 0x8513).call_to('glBindTexture')
        cube.movw(0, 0x84c0).half(0xe8bd, 0x40b0).jump('done%d' % n).label('name%d' % n).adds8(0, 4)
        cube.call_to('_ZNK11AbyssEngine6String9GetAECharEv').cbz(0, 'done%d' % n).half(0xe8bd, 0x40b0).jump('done%d' % n)
        cube.label('done%d' % n).half(0xbdb0)
    index = Asm(TEXT + 0x700).ldr(0, 0, 0x34 if 'sky index' in bad else 0x30).ret()
    lib = build({GAME: game.pop(), SPACE: space, CUBE: cube, '_ZN11SolarSystem15getTextureIndexEv': index,
                 '_ZN6Status12inAlienOrbitEv': Asm(TEXT + 0x720).half(0x6f81).half(0xf8d0, 0x0198).jump('end').label('end')})
    for name in ['_ZN6Status12inAlienOrbitEv', '_ZN6Status9getSystemEv']:
        if name in bad:  # called through the PLT only, as exported functions are
            lib.imports[lib.symbols.pop(name)[0]] = name
    return lib


class AndroidReflection(unittest.TestCase):
    parents = ({'provenance': {'predicate': {'offset': 1622656, 'bytes': 26}}},
               {'provenance': {'system': {'offset': 1637320, 'bytes': 13}, 'texture': {'offset': 723533, 'bytes': 7}}})

    def test_encodings_decode_as_intended(self):
        import capstone
        from android_thumb import Asm
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        code = Asm(0x2000).half(0xb5b0, 0xaf02, 0xe8bd, 0x40b0, 0xbdb0, 0x6f81).finish()
        self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoder.disasm(code, 0x2000)][:5],
                         ['push {r4, r5, r7, lr}', 'add r7, sp, #8', 'pop.w {r4, r5, r7, lr}', 'pop {r4, r5, r7, pc}', 'ldr r1, [r0, #0x78]'])

    def test_identifiers_and_spans(self):
        from android_fixture import TEXT
        lib = android()
        result = reader.extract_reflection_selection(lib, *self.parents)
        self.assertEqual({key: result[key] for key in ['texture_base', 'special_id']}, {'texture_base': 12030, 'special_id': 12040})
        self.assertEqual(result['provenance'], {'select': {'offset': TEXT + 0x102, 'bytes': 74}, 'bind': {'offset': TEXT + 0x600, 'bytes': 96},
                                                'predicate': {'offset': TEXT + 0x720, 'bytes': lib.symbols['_ZN6Status12inAlienOrbitEv'][1]},
                                                'system': {'offset': lib.symbols['_ZN6Status9getSystemEv'][0], 'bytes': 2},
                                                'sky_index': {'offset': TEXT + 0x700, 'bytes': 4},
                                                'load_context': {'offset': TEXT + 0x432, 'bytes': 6}})

    def test_each_broken_shape_is_unsupported(self):
        for bad in ['two selects', 'sky target', 'load target', 'status', 'base range', 'slot', 'canvas', 'game', 'two openings', 'campaign',
                    'world field', 'world', 'mesh canvas', 'level', 'mid target', 'tail', 'bind start', 'bind twice', 'unit', 'target', 'sky index',
                    '_ZN6Status12inAlienOrbitEv', '_ZN6Status9getSystemEv']:
            self.assertEqual(reader.extract_reflection_selection(android(**{bad: True}), *self.parents), {}, bad)
        projection, sky = self.parents
        for parents in [({}, sky), (projection, {}), ({'provenance': {}}, sky), ({'predicate': {}}, sky), (projection, {'system': {}}), (projection, {'provenance': {'texture': {}}}),
                        (projection, {'provenance': {'system': {}}})]:
            self.assertEqual(reader.extract_reflection_selection(android(), *parents), {}, parents)
