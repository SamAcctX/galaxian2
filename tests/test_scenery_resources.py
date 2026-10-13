"""Synthetic relocated declarations and disconnected-resource rejection."""
import copy
import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import scenery_resources as reader
from test_font_selection import expand
from test_ship_models import branch
from test_materials import arm_wide


def fixture(mac,shift=0):
    base=0x4000+shift;off=512;data=bytearray(25000);slice_offset=4096 if mac else 0
    sites={'entry':988 if mac else 994,'probability':5000,'selector':2000,'models':3000,'item':8000,'item_origin':8280 if mac else 8176,'station_system':9000,'system_x':9100,'system_y':9200,'sqrt_wrapper':10000,'sqrt':10100,'draw':16000,'table':20000,'stub':21000}
    blocks={}
    links={}
    for key,fields in [('station_system',('call_e2','call_101') if mac else ('call_a4','call_b8')),('system_x',('call_f6','call_139') if mac else ('call_b0','call_de')),('system_y',('call_111','call_168') if mac else ('call_c4','call_100')),('item_origin',('call_129','call_158') if mac else ('call_d2','call_ea')),('sqrt_wrapper',('call_188',) if mac else ('call_11c',))]:
        for field in fields:links[field]=sites[key]
    def block(key,spec):
        at=sites[key];raw,fields=expand(spec)
        for name,(p,n) in fields.items():
            if name in ('ore_first','weight_base','weight_min','fallback','override_item'):
                value={'ore_first':154,'weight_base':90,'weight_min':40,'fallback':164,'override_item':217}[name]
                if not mac and name=='ore_first':value=bytes.fromhex('4ff09a0b')
                elif not mac and name=='weight_base':value=bytes.fromhex('c0f15a00')
                else:value=value.to_bytes(n,'little')
            elif not mac and name.startswith('word_'):
                top=name in ('word_12','word_58','word_7e','word_18')
                delta=sites['table']-at-0x20 if key=='models' else 0
                value=arm_wide((delta>>16) if top else (delta&65535),0,top)
            elif name.startswith('ref_'):
                value=struct.pack('<i',sites['table']-at-p-n) if key=='models' else bytes(n)
            else:
                dest=15000
                if key=='entry':dest=sites['probability']
                elif key=='probability':dest=links.get(name,dest)
                elif key=='selector':dest=sites['draw']
                elif key=='sqrt_wrapper':dest=sites['sqrt']
                elif key=='sqrt':dest=sites['stub']
                value=struct.pack('<i',dest-at-p-n) if mac else branch(base+at+p,base+dest)
                if key=='sqrt_wrapper' and not mac:
                    first,second=struct.unpack('<2H',value);value=struct.pack('<2H',first,second&~0x4000)
            raw[p:p+n]=value
        data[off+at:off+at+len(raw)]=raw;blocks[key]=(at,raw,fields)
    prefix='MAC_' if mac else 'ARM_'
    block('entry','e8 {call:4} 48898520ffffff' if mac else '{call:4} 0a90')
    for key in ['probability','selector','models','item','sqrt']:block(key,getattr(reader,prefix+key.upper()))
    for key,spec in [('station_system','554889e58b47145dc3' if mac else 'c0687047'),('system_x','554889e58b472c5dc3' if mac else '006a7047'),('system_y','554889e58b47305dc3' if mac else '406a7047'),('item_origin','554889e58b47105dc3' if mac else '00697047'),('sqrt_wrapper','554889e55de9 {call:4}' if mac else '0846 {call:4}')]:block(key,spec)
    struct.pack_into('<4i',data,off+sites['table'],1100,1200,1300,1400)
    data[off+sites['stub']:off+sites['stub']+6]=bytes.fromhex('ff2500000000')
    sections=[{'name':b'__text','segment':b'__TEXT','address':base,'offset':off,'length':18000},{'name':b'__const','segment':b'__TEXT','address':base+20000,'offset':off+20000,'length':16},{'name':b'__stubs','segment':b'__TEXT','address':base+21000,'offset':off+21000,'length':6}]
    if mac:
        # Minimal symbol metadata sufficient to identify the imported sqrt stub.
        struct.pack_into('<8I',data,0,0xfeedfacf,0x1000007,0,2,3,256,0,0)
        struct.pack_into('<2I',data,32,0x19,152);struct.pack_into('<I',data,32+64,1)
        section=32+72;struct.pack_into('<QQI',data,section+32,base+21000,6,off+21000);struct.pack_into('<3I',data,section+64,8,0,6)
        struct.pack_into('<6I',data,184,2,24,23000,1,23100,7)
        struct.pack_into('<2I',data,208,11,80);struct.pack_into('<2I',data,208+56,23200,1)
        struct.pack_into('<IB',data,23000,1,1);data[23100:23107]=b'\0_sqrt\0';struct.pack_into('<I',data,23200,0)
    m=SimpleNamespace(data=bytes(data),text=sections[0],sections=sections,slice_offset=slice_offset,architecture='x86_64' if mac else 'armv7')
    population={'provenance':{'count':{'offset':slice_offset+off+1000,'bytes':66 if mac else 70},'draw':{'offset':slice_offset+off+sites['draw'],'bytes':171 if mac else 114}}}
    return m,population,blocks


class SceneryResources(unittest.TestCase):
    def test_relocated_resources_and_weights(self):
        for mac in [True,False]:
            for shift in [0,0x800000]:
                m,p,_=fixture(mac,shift);r=reader.extract_scenery_resources(m,p)
                self.assertEqual(r.get('model_ids'),[1100,1200,1300,1400],(mac,shift,r))
                self.assertEqual((r['weight_base'],r['weight_minimum']),(90,40))
                self.assertEqual(r['ore_item_ids'],list(range(154,164)))
                self.assertEqual(len(r['provenance']),12)

    def test_proofs_links_and_unsupported_inputs(self):
        for mac in [True,False]:
            m,p,blocks=fixture(mac);result=reader.extract_scenery_resources(m,p);self.assertTrue(result)
            for key,span in result['provenance'].items():
                bad=copy.copy(m);raw=bytearray(m.data)
                if key=='model_table':struct.pack_into('<i',raw,span['offset']-m.slice_offset,-1)
                else:raw[span['offset']-m.slice_offset]^=255
                bad.data=bytes(raw);self.assertFalse(reader.extract_scenery_resources(bad,p),(mac,key))
            self.assertFalse(reader.extract_scenery_resources(m,{}))
            for change in ['duplicate','draw','second_origin','truncated']:
                bad=copy.copy(m);raw=bytearray(m.data)
                if change=='duplicate':
                    at,body,_=blocks['models'];raw[512+3500:512+3500+len(body)]=body
                elif change=='truncated':raw=raw[:6000]
                else:
                    key='selector' if change=='draw' else 'probability';field=('call_30' if mac else 'call_3e') if change=='draw' else ('call_158' if mac else 'call_ea')
                    at,_,fields=blocks[key];start,n=fields[field];raw[512+at+start:512+at+start+n]=bytes(n)
                bad.data=bytes(raw);self.assertFalse(reader.extract_scenery_resources(bad,p),(mac,change))

    def test_mac_sqrt_import_metadata(self):
        for change in ['name','type','index','stride','truncated']:
            m,p,_=fixture(True);raw=bytearray(m.data)
            if change=='name':raw[23102]=ord('x')
            elif change=='type':raw[23004]=15
            elif change=='index':struct.pack_into('<I',raw,23200,1)
            elif change=='stride':struct.pack_into('<I',raw,32+72+72,0)
            else:raw=raw[:23104]
            m.data=bytes(raw);self.assertFalse(reader.extract_scenery_resources(m,p),change)


PROBABILITY, SQRT, SQRTF = '_ZN6Galaxy24getAsteroidProbabilitiesEP7Station', '_ZN7Globals4sqrtEf', '_ZN11AbyssEngine6AEMath5SqrtfEf'
# Whole bodies in the Android compiler's encoding (with their literal pools); `call:NAME` is a bl.
RESOURCE_BODIES = {
    PROBABILITY: '2de9f04f03af89b0044670480591784405682868 call:_ZN6Status12inAlienOrbitEv 06462868 '
                 'call:_ZN6Status16inSupernovaOrbitEv 0890002e0cbf606800200390684878440068006802902c20 call:_Znaj 05462c20 '
                 'call:_Znaj 834663484ff000094ff09a0a78440496006801904bf829a016b1002049464ae0059e3046 call:_ZN7Station9getSystemEv '
                 '039c616851f82000 call:_ZN11SolarSystem4getXEv 07903046 call:_ZN7Station9getSystemEv 616851f82000 '
                 'call:_ZN11SolarSystem4getYEv 029e0690706850f82a00 call:_ZN4Item17getMinPriceSystemEv 616851f82000 '
                 'call:_ZN11SolarSystem4getXEv 8046706850f82a00 call:_ZN4Item17getMinPriceSystemEv 6168079a51f82000a8eb020202fb02f4 '
                 'call:_ZN11SolarSystem4getYEv 0699049e401a00fb004000ee100ab8eec00a0198006810ee101a call:_ZN7Globals4sqrtEf '
                 '00ee100a09f10101bdeec00a10ee100ac0f164003228b8bf00200af1010a45f829008946baf1a40fa6d1a420002ecbf8280018bf6426ae62'
                 '2c680122002105eb8103586884420cda45f821000beb81005bf8212046684bf82160426000225c6000e0044601310a29e9d112f0010fe3d0'
                 '0020002155f82120012aa4bf121845f82120013102380b29f4d15820 call:_Znaj 8046194800246ff003097844d926d0f800a004ebd470'
                 '09ea40005bf8001048f8241008eb8401285848600898012807d1daf80000 call:_ZN6Status25getCurrentCampaignMissionEv '
                 '5a28a8bf48f824600234162ce5db2846 call:_ZdaPv 5846 call:_ZdaPv 404609b0bde8f08f00bf4e080c00c6080c00b4080c00e2060c00',
    '_ZN7Station9getSystemEv': 'c0687047', '_ZN11SolarSystem4getXEv': '006a7047', '_ZN11SolarSystem4getYEv': '406a7047',
    '_ZN4Item17getMinPriceSystemEv': '00697047',
    '_ZN4Item4initEv': '016b19b34968c0ef50004a680260ca6842604a698260ca69c2604a6bc261ca6b02624b6c4362d1f824c0c0f810c0c96a4161991a01ebd1'
                       '7102eb6101816100f1340141f98f0a002180f844107047',
    SQRTF: '00ee100ab1eec00ab4eec00af1ee10fa68bf46f1bbbc10ee100a7047'}


def tst_w(asm, rn, imm): return asm.half(0xf010 | rn, 0x0f00 | imm)  # tst.w rn, #imm


def selector(asm, draw=0x64, last=10, override=0xd9, fallback=0xa4, row=4, loop='loop', retry='retry', done='done', tag=''):
    """Rows of the probability table (sl) from r4 until an ore or the override item; labels carry `tag`."""
    asm.label(tag + 'loop').ldr_index(2, 10, 4, 2).movs(0, 0).cmp(2, override).it('eq').movs(0, 1).mov(1, 2).cmp(2, fallback)
    asm.str_sp(1, 0x50).mov_imm(1, 0).it('lt').movs(1, 1).orrs(1, 0).adds(0, row, 2).cmp(0, last).it('gt').movs(0, 0)
    tst_w(asm.label(tag + 'retry').mov(4, 0), 1, 1).branch('ne', tag + done).ldr_sp(0, 0x54).movs(1, draw).ldr(0, 0, 0)
    asm.call_to('_ZN11AbyssEngine8AERandom7nextIntEi').add_reg(1, 10, 4, 2).ldr(2, 1, 4).movs(1, 0).cmp_reg(0, 2).mov_imm(0, 0)
    return asm.branch('ge', tag + retry).branch(None, tag + loop).label(tag + 'done')


def models(asm, table=None, alien=1, override=0xd9, special=3, kind=2):
    """The model kind (sp+0x40; 1 in alien orbit, 3 for the override item) indexing the model table."""
    from android_fixture import RODATA
    asm.ldr_address(1, RODATA + 0x100 if table is None else table).cmp(0, 0).ldr_sp(2, 0x40).mov_imm(0, 0).it('ne').movs(2, alien)
    asm.add_pc(1).str_sp_w(10, 0x50).cmp(10, override).it('eq').movs(2, special).cmp(9, 0).it('gt').movs(0, 1)
    return asm.ldr_index(1, 1, kind, 2)


def roomy(functions, strings, **options):
    """android_fixture.library with .dynstr moved to the end of the image: its slot holds 0x200 bytes of names."""
    import android_fixture
    image = android_fixture.library(functions, strings, **options)
    names = b'\0' + b''.join(name.encode() + b'\0' for name in android_fixture.IMPORTS + tuple(row[0] for row in functions))
    table = bytearray(image)
    struct.pack_into('<II', table, struct.unpack_from('<I', image, 32)[0] + 40 * 2 + 16, len(image), len(names))
    return bytes(table) + names


def resources_library(bodies=None, omit=(), adjacent=True, wrapper=1, sqrt_name=SQRTF, veneer='7847c04600c09fe50ff08ce0', ids=(16900, 16921, 16904, 18836),
                      select=None, model=None, tail=None, **site):
    from unittest import mock
    import android_fixture
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm, build
    from test_scenery_population import android_library, raw
    def entry(asm):
        asm.call_to(PROBABILITY).str_sp(0, 0x3c)
        return asm if adjacent else asm.nop()
    def rest(asm):
        selector(asm, **(select or {}))
        models(asm, **(model or {}))
        return tail(asm) if tail else asm
    import android_thumb
    with mock.patch.object(android_fixture, 'IMPORTS', android_fixture.IMPORTS + (SQRTF, 'sqrtf')), \
            mock.patch.object(android_thumb, 'library', roomy):
        functions = android_library(entry=entry, tail=rest, bodies={**RESOURCE_BODIES, **(bodies or {})}, omit=omit, **site)
        asm = Asm(TEXT + 0x3f00).mov(0, wrapper).branch(None, 'veneer', wide=True).nop().label('veneer')
        functions[SQRT] = raw(asm, veneer + struct.pack('<I', (android_fixture.stub(sqrt_name) - (asm.here() + 16)) & 0xffffffff).hex())
        return build(functions, {RODATA + 0x100: struct.pack('<4i', *ids)})


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidSceneryResources(unittest.TestCase):
    def test_encodings_decode_as_intended(self):
        import capstone
        from android_thumb import Asm
        ins = next(capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB).disasm(tst_w(Asm(0), 1, 1).finish(), 0))
        self.assertEqual('%s %s' % (ins.mnemonic, ins.op_str), 'tst.w r1, #1')

    def test_declarations_and_spans(self):
        from android_fixture import RODATA, TEXT
        lib = resources_library()
        result = reader.extract_scenery_resources(lib, {'count_base': 40})
        provenance = result.pop('provenance')
        self.assertEqual(result, {'ore_item_ids': list(range(154, 164)), 'fallback_item_id': 164, 'override_item_id': 217,
                                  'weight_base': 100, 'weight_minimum': 50, 'location_weight': 100, 'rank_discount': 2,
                                  'sample_rows': 6, 'draw_bound': 100, 'override_cursor': 90, 'item_origin_index': 9,
                                  'system_position_indices': [3, 4], 'model_ids': [16900, 16921, 16904, 18836]})
        starts = {name: lib.symbols[name][0] for name in RESOURCE_BODIES}
        self.assertEqual(provenance, {
            'entry': {'offset': TEXT + 0x102, 'bytes': 6}, 'probability': {'offset': starts[PROBABILITY], 'bytes': 458},
            'selector': {'offset': TEXT + 0x13a, 'bytes': 72}, 'models': {'offset': TEXT + 0x182, 'bytes': 40},
            'model_table': {'offset': RODATA + 0x100, 'bytes': 16}, 'sqrt_wrapper': {'offset': TEXT + 0x3f00, 'bytes': 6},
            'station_system': {'offset': starts['_ZN7Station9getSystemEv'], 'bytes': 4},
            'system_x': {'offset': starts['_ZN11SolarSystem4getXEv'], 'bytes': 4},
            'system_y': {'offset': starts['_ZN11SolarSystem4getYEv'], 'bytes': 4},
            'item_origin': {'offset': starts['_ZN4Item17getMinPriceSystemEv'], 'bytes': 4},
            'item': {'offset': starts['_ZN4Item4initEv'], 'bytes': 78}, 'sqrt': {'offset': starts[SQRTF], 'bytes': 28}})
        self.assertEqual(reader.extract_scenery_resources(lib, {}), {})

    def test_each_broken_shape_is_unsupported(self):
        def patched(name, old, new):
            assert RESOURCE_BODIES[name].count(old) == 1, old
            return {name: RESOURCE_BODIES[name].replace(old, new)}
        cases = {'detached entry': dict(adjacent=False), 'no count site': dict(reload=5), 'two entries': dict(copies=2), 'wrapper': dict(wrapper=2),
                 'draw bound': dict(select=dict(draw=0x63)), 'rows': dict(select=dict(last=12)), 'override row': dict(select=dict(override=0xda)),
                 'ore rows': dict(select=dict(fallback=0xa5)), 'row register': dict(select=dict(row=5)),
                 'loop': dict(select=dict(loop='retry')), 'retry': dict(select=dict(retry='loop')), 'done': dict(select=dict(done='loop')),
                 'two selectors': dict(tail=lambda asm: selector(asm, tag='second ')),
                 'alien kind': dict(model=dict(alien=2)), 'override kind': dict(model=dict(special=2)),
                 'override model': dict(model=dict(override=0xda)), 'kind register': dict(model=dict(kind=3)),
                 'table outside': dict(model=dict(table=0x7ff8)), 'model id': dict(ids=(16900, 16921, 16904, 65533)),
                 'two model sites': dict(tail=models),
                 'veneer': dict(veneer='7847c04600c09fe50ff08ce1'), 'veneer import': dict(sqrt_name='sqrtf'),
                 'ore first': dict(bodies=patched(PROBABILITY, '4ff09a0a', '4ff09b0a')),
                 'fallback pair': dict(bodies=patched(PROBABILITY, 'a420002e', 'a520002e')),
                 'fallback': dict(bodies=patched(PROBABILITY, 'baf1a40fa6d1a420', 'baf1a50fa6d1a520')),
                 'override': dict(bodies=patched(PROBABILITY, 'd926', 'da26')),
                 'weight base': dict(bodies=patched(PROBABILITY, 'c0f16400', 'c0f16500')),
                 'zero minimum': dict(bodies=patched(PROBABILITY, '3228b8bf', '0028b8bf')),
                 'minimum above base': dict(bodies=patched(PROBABILITY, 'c0f164003228', 'c0f130003228')),
                 'cursor': dict(bodies=patched(PROBABILITY, '5a28a8bf', '5b28a8bf')),
                 'loop target': dict(bodies=patched(PROBABILITY, 'a6d1', 'a5d1')),
                 'attribute': dict(bodies=patched('_ZN4Item4initEv', 'd1f824c0', 'd1f828c0')),
                 'origin field': dict(bodies=patched('_ZN4Item17getMinPriceSystemEv', '0069', '4069')),
                 'system field': dict(bodies=patched('_ZN7Station9getSystemEv', 'c068', '0069')),
                 'x field': dict(bodies=patched('_ZN11SolarSystem4getXEv', '006a', '406a')),
                 'y field': dict(bodies=patched('_ZN11SolarSystem4getYEv', '406a', '806a')),
                 'square root': dict(bodies=patched(SQRTF, 'b1eec00a', 'b0eec00a'))}
        for name in RESOURCE_BODIES:
            cases['no ' + name] = dict(omit=(name,))
        for name, options in cases.items():
            self.assertEqual(reader.extract_scenery_resources(resources_library(**options), {'count_base': 40}), {}, name)
