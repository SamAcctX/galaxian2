"""Synthetic compiler contexts with independently relocated resource IDs."""
import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import opening_sky as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac, relocation=0):
    base=0x100000+relocation; data=bytearray(4096); blocks={}; prefix='MAC_' if mac else 'ARM_'
    star_size=len(expand(getattr(reader,prefix+'STARS'))[0])
    locations={'stars':64,'opening':64+star_size,'texture':700}
    targets={'system':1600,'system_id':1640,'cursor':1680,'mesh':1800,'texture':1840}
    calls=({'stars':{'call_b':'system','call_13':'system_id','call_47':'mesh','call_5a':'system','call_62':'system_id','call_99':'texture'},
            'opening':{'call_4':'cursor','call_2e':'mesh'},'texture':{'call_2':'texture'}} if mac else
           {'stars':{'call_8':'system','call_10':'system_id','call_42':'mesh','call_50':'system','call_58':'system_id','call_82':'texture'},
            'opening':{'call_6':'cursor','call_2a':'mesh'},'texture':{'call_2':'texture'}})
    for key,at in locations.items():
        body,fields=expand(getattr(reader,prefix+key.upper()))
        for field,(off,size) in fields.items():
            site=base+at+off
            if field.startswith(('call','jump','ref')):
                dest=base+(700 if field.startswith('jump') else targets[calls[key][field]] if field.startswith('call') else 1900)
                raw=(struct.pack('<i',dest-site-size) if mac else
                     struct.pack('<H',0xe000|(((dest-site-4)//2)&2047)) if size==2 else branch(site,dest))
            elif mac: raw=struct.pack('<I',300 if key=='opening' and field=='id_24' else 400 if key=='opening' else 100 if field=='id_38' else 200)
            else:
                meta=reader.ARM_FIELDS[prefix+key.upper()][field]
                value=(0x5556 if field=='word_18' else 0x5555 if field=='word_20' else 100 if field=='word_38' else 200) if key=='stars' else 300 if field=='word_1e' else 400
                register=11 if meta['register']=='fp' else int(meta['register'][1:])
                raw=arm_wide(value,register,meta['kind']=='movt')
            body[off:off+size]=raw
        data[256+at:256+at+len(body)]=body; blocks[key]=(at,body,fields)
    getters=({'system':'554889e5488b87280200005dc3','system_id':'554889e58b47205dc3','cursor':'554889e58b87780200005dc3'} if mac else
             {'system':'d0f890017047','system_id':'40697047','cursor':'d0f8d4017047'})
    for key,raw in getters.items():
        body=bytes.fromhex(raw); at=targets[key];data[256+at:256+at+len(body)]=body
    text={'name':b'__text','segment':b'__TEXT','address':base,'offset':256,'length':2048}
    m=SimpleNamespace(architecture='x86_64' if mac else 'armv7',data=bytes(data),slice_offset=8192,text=text,sections=[text])
    projection={'provenance':{'cursor':{'offset':8192+256+1680,'bytes':len(bytes.fromhex(getters['cursor']))}}}
    return m,projection,blocks


class OpeningSky(unittest.TestCase):
    def test_changed_ids_and_relocation(self):
        for mac in [True,False]:
            for shift in [0,0x180000]:
                m,projection,_=fixture(mac,shift); result=reader.extract_opening_sky(m,projection)
                self.assertTrue(result,(mac,shift))
                self.assertEqual([result[k] for k in ['star_mesh_base','star_texture_base','sky_mesh_id','sky_texture_id']],[100,200,300,400])
                self.assertEqual(result['star_variants'],3)
                self.assertFalse(result['location_match'])
                self.assertEqual(result['provenance']['stars']['offset'],8512)

    def test_rejects_corruption_and_unlinked_calls(self):
        for mac in [True,False]:
            for bad in ['stars','opening','texture','cursor','system','duplicate','link','modulo','id','missing']:
                with self.subTest(mac=mac,bad=bad):
                    m,p,blocks=fixture(mac); data=bytearray(m.data)
                    if bad in ['stars','opening','texture']:data[256+blocks[bad][0]]^=1
                    elif bad=='cursor':p['provenance']['cursor']['offset']+=4
                    elif bad=='system':data[256+1600]^=1
                    elif bad=='duplicate':
                        _,body,_=blocks['stars'];data[256+1100:256+1100+len(body)]=body
                    elif bad=='missing':p={}
                    else:
                        at,_,fields=blocks['stars']
                        field=('call_47' if mac else 'call_42') if bad=='link' else ('id_38' if mac else 'word_38') if bad=='id' else 'word_18' if not mac else None
                        if field is None:
                            data[256+at+0x20]^=1
                        else:
                            off,size=fields[field];site=m.text['address']+at+off
                            raw=(struct.pack('<i',1900-at-off-size) if mac else branch(site,m.text['address']+1900)) if bad=='link' else (struct.pack('<I',65535) if mac else arm_wide(65535 if bad=='id' else 0x5557,1 if bad=='id' else 11,False))
                            data[256+at+off:256+at+off+size]=raw
                    m.data=bytes(data)
                    self.assertEqual(reader.extract_opening_sky(m,p),{})


SPACE = '_ZN5Level11createSpaceEv'
CREATE = '_ZN11AbyssEngine11PaintCanvas'
GETTERS = {'_ZN6Status25getCurrentCampaignMissionEv': 0x1e8, '_ZN6Status9getSystemEv': 0x1a0, '_ZN11SolarSystem8getIndexEv': 0x14}


def smmul(asm, rd, rn, rm): return asm.half(0xfb50 | rn, 0xf000 | rd << 8 | rm)


def add_lsr(asm, rd, rn, rm, shift): return asm.half(0xeb00 | rn, (shift >> 2) << 12 | rd << 8 | (shift & 3) << 6 | 0x10 | rm)


def subs_reg(asm, rd, rn, rm): return asm.half(0x1a00 | rm << 6 | rn << 3 | rd)


class Raw:
    """A function body laid out by android_thumb.build without the 4-byte padding."""
    def __init__(self, address, code):
        self.address, self.code, self.named = address, bytes(code), []

    def finish(self):
        return self.code


def getter(name, field, address=None, rd=0, padded=False):
    """`ldr.w r0, [r0, #field]; bx lr` (`ldr r0, [r0, #field]` when it fits 16 bits)."""
    from android_thumb import Asm
    from android_fixture import TEXT
    asm = Asm(address or TEXT + 0x800 + 0x10 * list(GETTERS).index(name))
    (asm.ldr(rd, 0, field) if field < 128 else asm.ldr_w(rd, 0, field)).ret()
    return asm if padded else Raw(asm.address, asm.code)


def android(name=SPACE, magic=0x5556, world=3, copies=1, tail=('movs', CREATE + '13TextureCreateEtRjb'), ids=(17850, 10086, 17803, 10068),
            getters=GETTERS, split=False, broken=None):
    """createSpace's star layer and the opening sky in the Android compiler's shape."""
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm, build
    asm = Asm(TEXT + 0x100).push()
    for n in range(copies):
        asm.ldr_address(0, RODATA).add_pc(0).ldr(5, 0, 0).ldr(0, 5, 0)
        asm.call_to('_ZN6Status9getSystemEv').call_to('_ZN11SolarSystem8getIndexEv').movw(8, magic).add_imm(2, 10, 8).movt(8, 0x5555).movs(3, 0)
        smmul(asm, 1, 0, 8); add_lsr(asm, 1, 1, 1, 31); asm.add_reg(1, 1, 1, 1); subs_reg(asm, 0, 0, 1)
        asm.movw(1, ids[0]).add_low(0, 1).uxth(1, 0).mov(0, 6).call_to(CREATE + '10MeshCreateEtRjb')
        asm.ldr_address(0, RODATA + 4).add_pc(0).ldr(0, 0, 0).ldr(6, 0, 0).ldr(0, 5, 0)
        asm.call_to('_ZN6Status9getSystemEv').call_to('_ZN11SolarSystem8getIndexEv')
        smmul(asm, 1, 0, 8); asm.add_imm(2, 10, 0x19c).movs(3, 0); add_lsr(asm, 1, 1, 1, 31); asm.add_reg(1, 1, 1, 1); subs_reg(asm, 0, 0, 1)
        asm.movw(1, ids[1]).add_low(0, 1).uxth(1, 0).mov(0, 6).call_to(CREATE + '13TextureCreateEtRjb')
        asm.ldr(0, 5, 0).call_to('_ZN6Status25getCurrentCampaignMissionEv').cbz(0, 'other%d' % n, nonzero=True)
        asm.ldr_w(0, 10, 0xc0).cmp(0, world).branch('ne', 'other%d' % n).ldr_address(0, RODATA + 8).movw(1, ids[2]).mov(2, 9).movs(3, 0)
        asm.add_pc(0).ldr(5, 0, 0).ldr(0, 5, 0).call_to(CREATE + '10MeshCreateEtRjb').ldr(0, 5, 0).add_imm(2, 10, 0x198)
        asm.movw(1, ids[3]).branch(None, 'tail%d' % n).label('other%d' % n).nop().nop()
        if split:  # the jump lands inside a 32-bit instruction
            asm.half(0xf240).label('tail%d' % n).half(0x0300)
        else:
            asm.label('tail%d' % n)
        asm.movs(3, 0 if tail[0] == 'movs' else 1)
        asm.call_to(tail[1])
    functions = {name: asm.pop()}
    functions.update((key, getter(key, field, **(broken or {}) if key == '_ZN6Status9getSystemEv' else {})) for key, field in getters.items())
    return build(functions)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidOpeningSky(unittest.TestCase):
    PROJECTION = {'provenance': {'cursor': {'offset': 1, 'bytes': 12}}}

    def test_encodings_decode_as_intended(self):
        import capstone
        from android_thumb import Asm
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        for emit, expected in [(lambda a: smmul(a, 1, 0, 8), 'smmul r1, r0, r8'), (lambda a: add_lsr(a, 1, 1, 1, 31), 'add.w r1, r1, r1, lsr #31'),
                               (lambda a: subs_reg(a, 0, 0, 1), 'subs r0, r0, r1')]:
            asm = Asm(0x2000)
            emit(asm)
            self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoder.disasm(bytes(asm.code), 0x2000)], [expected])

    def test_star_bases_and_opening_sky(self):
        from android_fixture import TEXT
        lib = android()
        value = reader.extract_opening_sky(lib, self.PROJECTION)
        self.assertEqual({k: v for k, v in value.items() if k != 'provenance'},
                         {'world_type': 3, 'campaign_cursor': 0, 'location_match': False, 'star_variants': 3,
                          'star_mesh_base': 17850, 'star_texture_base': 10086, 'sky_mesh_id': 17803, 'sky_texture_id': 10068})
        start = lib.symbols[SPACE][0]
        self.assertEqual(value['provenance'], {'stars': {'offset': start + 2, 'bytes': 110}, 'opening': {'offset': start + 112, 'bytes': 48},
                                               'texture': {'offset': start + 164, 'bytes': 6}, 'cursor': {'offset': TEXT + 0x800, 'bytes': 6},
                                               'system': {'offset': TEXT + 0x810, 'bytes': 6}, 'system_id': {'offset': TEXT + 0x820, 'bytes': 4}})
        self.assertEqual(reader.extract_opening_sky(lib, {'provenance': {}}), {})
        self.assertEqual(reader.extract_opening_sky(lib, None), {})

    def test_each_broken_shape_is_unsupported(self):
        cases = {'name': dict(name='_ZN5Level11createSceneEv'), 'modulo': dict(magic=0x5557), 'world': dict(world=4), 'two': dict(copies=2),
                 'tail call': dict(tail=('movs', CREATE + '10MeshCreateEtRjb')), 'tail shape': dict(tail=('other', CREATE + '13TextureCreateEtRjb')),
                 'id': dict(ids=(17850, 10086, 65534, 10068)), 'getter': dict(broken={'rd': 1}), 'getter tail': dict(broken={'padded': True}),
                 'tail inside an instruction': dict(split=True),
                 'missing getter': dict(getters={k: v for k, v in GETTERS.items() if k != '_ZN11SolarSystem8getIndexEv'})}
        for name, options in cases.items():
            self.assertEqual(reader.extract_opening_sky(android(**options), self.PROJECTION), {}, name)
