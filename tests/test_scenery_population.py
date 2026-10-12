"""Relocated population declarations, linked sampler and ARM symbol validation."""
import copy
import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import scenery_population as reader
from test_font_selection import expand
from test_ship_models import branch
from test_materials import arm_wide


def fixture(mac,shift=0,alternate=False):
    base=0x100000+shift;offset=512;data=bytearray(9000);slice_offset=4096 if mac else 0
    sites={'count':1000,'station':2000,'station_id':2200,'seed':2400,'draw':2600,'bits':3000,'resize':3500,'modulo':6000}
    blocks={}
    def block(key,spec):
        at=sites[key];raw,fields=expand(spec)
        for name,(p,n) in fields.items():
            if name=='base':value=bytes([17])
            elif name=='bound':value=(37).to_bytes(n,'little')
            elif name in ['low','high']:value=arm_wide(0,0,name=='high')
            elif name=='random':value=bytes(n)
            else:
                dest=sites['bits'] if name in ['first','repeat'] else sites[name]
                if mac:value=struct.pack('<i',dest-at-p-n)
                elif name=='modulo':
                    # The immediate BLX to an aligned ARM stub uses an aligned PC.
                    delta=(base+dest)-((base+at+p+4)&~3)
                    s=(delta>>24)&1;i1=(delta>>23)&1;i2=(delta>>22)&1
                    value=struct.pack('<HH',0xf000|(s<<10)|((delta>>12)&0x3ff),0xc000|((1^i1^s)<<13)|((1^i2^s)<<11)|((delta>>1)&0x7fe))
                else:value=branch(base+at+p,base+dest)
            raw[p:p+n]=value
        data[offset+at:offset+at+len(raw)]=raw;blocks[key]=(at,raw,fields)
    block('count',reader.MAC_COUNT if mac else reader.ARM_COUNT)
    block('station','554889e5488b87180200005dc3' if mac else 'd0f888017047')
    block('station_id','554889e58b47105dc3' if mac else '80687047')
    for key in ['seed','draw','bits']:block(key,reader.MAC_ALTERNATES[key][0][1] if alternate and mac else getattr(reader,('MAC_' if mac else 'ARM_')+key.upper()))
    text={'name':b'__text','segment':b'__TEXT','address':base,'offset':offset,'length':5000}
    if not mac:
        struct.pack_into('<7I',data,0,0xfeedface,12,9,2,3,296,0)
        struct.pack_into('<2I',data,28,1,192);struct.pack_into('<I',data,28+48,2)
        for i,(addr,length,where,flags,first,stride) in enumerate([(base,5000,offset,0,0,0),(base+6000,16,6512,8,0,16)]):
            at=28+56+68*i;struct.pack_into('<3I',data,at+32,addr,length,where);struct.pack_into('<3I',data,at+56,flags,first,stride)
        name=b'\0___modsi3\0'
        struct.pack_into('<6I',data,220,2,24,7100,1,7200,len(name))
        struct.pack_into('<2I',data,244,11,80);struct.pack_into('<2I',data,244+56,7000,1)
        struct.pack_into('<I',data,7000,0);struct.pack_into('<IB',data,7100,1,1);data[7200:7200+len(name)]=name
    m=SimpleNamespace(data=bytes(data),text=text,sections=[text],slice_offset=slice_offset,architecture='x86_64' if mac else 'armv7')
    return m,blocks


class SceneryPopulation(unittest.TestCase):
    def test_alternate_mac_sampler_keeps_mask_and_call_proofs(self):
        for shift in (0, 0x400000):
            m, blocks = fixture(True, shift, alternate=True)
            result = reader.extract_scenery_population(m)
            self.assertEqual((result['count_base'], result['count_bound']), (17, 37))
            self.assertEqual(result['provenance']['draw']['bytes'], 170)
            for key, at in [('seed', 0x3d + 2), ('bits', 0x41 + 2), ('draw', blocks['draw'][2]['repeat'][0])]:
                original = m.data
                raw = bytearray(original)
                raw[512 + blocks[key][0] + at] ^= 1
                m.data = bytes(raw)
                self.assertFalse(reader.extract_scenery_population(m), key)
                m.data = original

    def test_relocated_and_changed_counts(self):
        for mac in [True,False]:
            for shift in [0,0x400000]:
                m,_=fixture(mac,shift);result=reader.extract_scenery_population(m)
                self.assertEqual((result.get('count_base'),result.get('count_bound')),(17,37),(mac,shift,result))

    def test_each_proof_and_links(self):
        for mac in [True,False]:
            m,_=fixture(mac);result=reader.extract_scenery_population(m);self.assertTrue(result)
            for key,span in result['provenance'].items():
                bad=copy.copy(m);raw=bytearray(m.data);raw[span['offset']-m.slice_offset]^=255;bad.data=bytes(raw)
                self.assertFalse(reader.extract_scenery_population(bad),(mac,key))
            for change in ['duplicate','bound_zero','second_bits','station','truncated']:
                bad,blocks=fixture(mac);raw=bytearray(bad.data)
                if change=='duplicate':
                    at,body,_=blocks['count'];raw[512+4000:512+4000+len(body)]=body
                elif change=='truncated':raw=raw[:512+3020]
                else:
                    key='draw' if change=='second_bits' else 'count';field='repeat' if change=='second_bits' else 'bound' if change=='bound_zero' else 'station'
                    at,body,fields=blocks[key];p,n=fields[field]
                    raw[512+at+p:512+at+p+n]=bytes(n)
                bad.data=bytes(raw)
                self.assertFalse(reader.extract_scenery_population(bad),(mac,change))

    def test_imported_modulo_is_required(self):
        for change in ['name','index','kind','stride','command','truncated']:
            m,_=fixture(False);raw=bytearray(m.data)
            if change=='name':raw[7204]=ord('x')
            elif change=='index':struct.pack_into('<I',raw,7000,1)
            elif change=='kind':raw[7104]=15
            elif change=='stride':struct.pack_into('<I',raw,28+56+68+64,0)
            elif change=='command':struct.pack_into('<I',raw,244+4,4)
            else:raw=raw[:7205]
            m.data=bytes(raw)
            self.assertFalse(reader.extract_scenery_population(m),change)


SCENE, STATION, INDEX = '_ZN5Level15createAsteroidsEv', '_ZN6Status10getStationEv', '_ZN7Station8getIndexEv'
SEED, DRAW = '_ZN11AbyssEngine8AERandom7setSeedEx', '_ZN11AbyssEngine8AERandom7nextIntEi'
# Whole bodies in the Android compiler's encoding; `call:NAME` is a bl patched by build().
BODIES = {STATION: 'd0f898017047', INDEX: '80687047', SEED: '99b24ef26d6381f00501cdf6ec635a40c0e900217047',
          DRAW: '2de9f04f03af81b08b46cbf100014ef26d6a01ea0b014ff00509cdf6ec6a594517d1d0e90061a6fb0a2306fb093301fb0a33'
                '12f10b0143f1000296b24a0c42eac632c0e9001682fb0b23d00f40ea43011ee00090abf10108d0e90045a4fb0a0104fb0911'
                '10f10b0405fb0a1141f10000594685b2600c40eac5363046 call:__aeabi_idivmod a8eb010030440028e8db0098c0e90045'
                '084601b0bde8f08f'}


def raw(asm, text):
    for part in text.split():
        if part.startswith('call:'):
            asm.call_to(part[5:])
        else:
            data = bytes.fromhex(part)
            asm.half(*struct.unpack('<%dH' % (len(data) // 2), data))
    return asm


def asrs(asm, rd, rm, imm): return asm.half(0x1000 | imm << 6 | rm << 3 | rd)  # asrs rd, rm, #imm


def count_site(asm, bound=40, base=40, reload=6, seed=5):
    """createAsteroids' seeding and list sizing (Globals::rnd at r6 via the GOT word, AERandom* in r5)."""
    from android_fixture import RODATA
    asm.ldr_address(0, RODATA).add_pc(0).ldr(6, 0, 0).ldr_w(0, 10, 0).ldr(5, 6, 0).call_to(STATION).call_to(INDEX)
    asrs(asm.mov(1, 0).mov(0, seed), 3, 1, 31).mov(2, 1).call_to(SEED).ldr(0, reload, 0).movs(1, bound).call_to(DRAW)
    return asm.ldr_w(1, 4, 0xfc).adds8(0, base).call_to('_Z14ArraySetLengthIP8KIPlayerEvjR5ArrayIT_E')


def android_library(scene=SCENE, copies=1, bodies=None, omit=(), entry=None, **site):
    """Synthetic createAsteroids plus the four sampler bodies; `entry(asm)` code runs before the site."""
    from android_fixture import TEXT
    from android_thumb import Asm, build
    asm = Asm(TEXT + 0x100).push()
    for _ in range(copies):
        count_site(entry(asm) if entry else asm, **site)
    functions = {scene: asm.pop()}
    for index, (name, text) in enumerate({**BODIES, **(bodies or {})}.items()):
        if name not in omit:
            functions[name] = raw(Asm(TEXT + 0x400 + 0x100 * index), text)
    return functions


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidSceneryPopulation(unittest.TestCase):
    def test_encodings_decode_as_intended(self):
        import capstone
        from android_thumb import Asm
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        ins = next(decoder.disasm(asrs(Asm(0), 3, 1, 31).finish(), 0))
        self.assertEqual('%s %s' % (ins.mnemonic, ins.op_str), 'asrs r3, r1, #0x1f')

    def test_count_and_sampler_spans(self):
        from android_fixture import TEXT
        from android_thumb import build
        result = reader.extract_scenery_population(build(android_library(bound=37, base=17)))
        self.assertEqual(result, {'count_base': 17, 'count_bound': 37, 'provenance': {
            'count': {'offset': TEXT + 0x102, 'bytes': 50}, 'station': {'offset': TEXT + 0x400, 'bytes': 6},
            'station_id': {'offset': TEXT + 0x500, 'bytes': 4}, 'seed': {'offset': TEXT + 0x600, 'bytes': 22},
            'draw': {'offset': TEXT + 0x700, 'bytes': 152}}})

    def test_each_broken_shape_is_unsupported(self):
        from android_thumb import build
        def patched(name, old, new):
            return {name: BODIES[name].replace(old, new, 1)}
        cases = {'scene': dict(scene='_ZN5Level11createSpaceEv'), 'twice': dict(copies=2), 'bound': dict(bound=0),
                 'reload': dict(reload=5), 'seeded object': dict(seed=4),
                 'station field': dict(bodies=patched(STATION, 'd0f89801', 'd0f89c01')),
                 'index field': dict(bodies=patched(INDEX, '8068', 'c068')),
                 'scramble low': dict(bodies=patched(SEED, '6d63', '6e63')), 'scramble high': dict(bodies=patched(SEED, '0501', '0401')),
                 'multiplier': dict(bodies=patched(DRAW, '4ef26d6a', '4ef26e6a')), 'addend': dict(bodies=patched(DRAW, '12f10b01', '12f10c01')),
                 'bits': dict(bodies=patched(DRAW, '4a0c', '8a0c')), 'loop': dict(bodies=patched(DRAW, 'e8db', 'e7db')),
                 'skip': dict(bodies=patched(DRAW, '17d1', '16d1')), 'join': dict(bodies=patched(DRAW, '1ee0', '1de0')),
                 'modulo': dict(bodies={DRAW: BODIES[DRAW].replace('call:__aeabi_idivmod', 'call:__aeabi_uidivmod')})}
        for name in BODIES:
            cases['no ' + name] = dict(omit=(name,))
        for name, options in cases.items():
            self.assertEqual(reader.extract_scenery_population(build(android_library(**options))), {}, name)
