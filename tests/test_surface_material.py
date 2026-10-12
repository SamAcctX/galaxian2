"""Relocated static contexts with independently chosen material values."""
import struct
import unittest
from gof2_content import surface_material as reader
from gof2_content.environment_colors import extract_environment_colors
from test_environment_colors import fixture as color_fixture
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def arm_modified(value, reg):
    for bits in range(4096):
        byte = bits & 255
        if bits < 1024:
            decoded = [byte, byte | (byte << 16), (byte << 8) | (byte << 24), byte * 0x01010101][bits >> 8]
        else:
            rotate = bits >> 7; initial = 128 | (bits & 127)
            decoded = ((initial >> rotate) | (initial << (32-rotate))) & 0xffffffff
        if decoded == value:
            return struct.pack('<HH', 0xf04f | ((bits >> 11) << 10), (reg << 8) | (bits & 255) | (((bits >> 8) & 7) << 12))
    raise ValueError('Test value is not a Thumb modified immediate')


def fixture(mac, shift=0):
    mach, sky, blocks, _ = color_fixture(mac, shift)
    colors = extract_environment_colors(mach, sky)
    data = bytearray(mach.data); base = mach.text['address']
    locations = {'setup':blocks['rim'][0]+len(blocks['rim'][1]), 'ambient':2800, 'diffuse':2920, 'specular':3040, 'power':3160, 'renderer':3240}
    expected = {'ambient_rgb':[0.25]*3, 'diffuse_rgb':[0.5]*3, 'specular_rgb':[0.75]*3, 'specular_power':32.0}
    if not mac: expected.update(ambient_rgb=[0.25,0.5,0.75], diffuse_rgb=[2.0,1.5,1.0], specular_rgb=[4.0,2.0,0.0])
    contexts = {}
    for key, at in locations.items():
        body, fields = expand(getattr(reader, ('MAC_' if mac else 'ARM_')+key.upper()))
        for field,(off,n) in fields.items():
            site = base+at+off
            role = field.split('_')[0]
            if field.startswith('renderer_') or field.endswith('_call'):
                target = base+locations[role]
                raw = struct.pack('<i',target-site-4) if mac else branch(site,target)
            elif mac:
                index = reader.ROLES.index(role);target = base+9500+index*8
                raw = struct.pack('<i',target-site-4)
                value = expected['specular_power' if role=='power' else role+'_rgb']
                struct.pack_into('<f',data,256+9500+index*8,value if role=='power' else value[0])
            elif field.startswith('global_'): raw = arm_wide(0,1,field=='global_movt')
            elif role == 'power':raw = struct.pack('<H',0x2100) if field=='power_0' else arm_wide(0x4200,1,True)
            else:
                index = int(field[-1]); bits = struct.unpack('<I',struct.pack('<f',expected[role+'_rgb'][index]))[0]
                raw = arm_modified(bits,index+1)
            body[off:off+n] = raw
        data[256+at:256+at+len(body)] = body; contexts[key] = (at,body,fields)
    mach.data = bytes(data)
    return mach,colors,contexts,expected


class SurfaceMaterial(unittest.TestCase):
    def test_relocated_values_and_provenance(self):
        for mac in [True,False]:
            for shift in [0,0x350000]:
                mach,colors,_,expected=fixture(mac,shift)
                result=reader.extract_surface_material(mach,colors)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({key:result[key] for key in expected},expected)
                self.assertEqual(result['provenance']['rim'],colors['provenance']['rim'])
                self.assertEqual(result['provenance']['setup']['bytes'],118 if mac else 90)

    def test_missing_corrupt_or_unlinked_contexts(self):
        for mac in [True,False]:
            for bad in ['setup','ambient','diffuse','specular','power','renderer','rim','missing','link','duplicate','truncated','wrong_setter','wrong_renderer','bad_value','bad_power','wrong_register','partial_constant']:
                with self.subTest(mac=mac,bad=bad):
                    mach,colors,contexts,_=fixture(mac);data=bytearray(mach.data)
                    at,body,fields=contexts['setup']
                    def replace(field,raw):
                        off,n=fields[field];self.assertEqual(len(raw),n);data[256+at+off:256+at+off+n]=raw
                    if bad in contexts:data[256+contexts[bad][0]]^=1
                    elif bad=='rim':data[256+768+(0 if mac else 4)]^=1
                    elif bad=='missing':colors={}
                    elif bad=='link':colors['provenance']['rim']['offset']+=2
                    elif bad=='duplicate':data[256+1700:256+1700+len(body)]=body
                    elif bad=='truncated':mach.text['length']=at+len(body)-1
                    elif bad in ['wrong_setter','wrong_renderer']:
                        field='ambient_call' if bad=='wrong_setter' else 'renderer_3';off,_=fields[field];site=mach.text['address']+at+off
                        target=mach.text['address']+contexts['specular'][0]
                        replace(field,struct.pack('<i',target-site-4) if mac else branch(site,target))
                    elif bad in ['bad_value','bad_power']:
                        if mac:struct.pack_into('<f',data,256+9500+(24 if bad=='bad_power' else 0),0 if bad=='bad_power' else float('nan'))
                        elif bad=='bad_power':replace('power_1',arm_wide(0,1,True))
                        else:replace('ambient_0',arm_modified(0x42000000,1))
                    elif bad=='wrong_register':
                        if mac:data[256+at+24]^=1
                        else:replace('diffuse_1',arm_modified(0x3f800000,1))
                    elif bad=='partial_constant':
                        if not mac:continue
                        off,_=fields['diffuse_value'];replace('diffuse_value',struct.pack('<i',9502-at-off-4))
                    mach.data=bytes(data)
                    self.assertEqual(reader.extract_surface_material(mach,colors),{})

    def test_exact_constant_alias_is_supported(self):
        mach,colors,contexts,_=fixture(True);data=bytearray(mach.data)
        at,_,fields=contexts['setup'];off,_=fields['diffuse_value']
        struct.pack_into('<i',data,256+at+off,9500-at-off-4);mach.data=bytes(data)
        result=reader.extract_surface_material(mach,colors)
        self.assertEqual(result['ambient_rgb'],result['diffuse_rgb'])
        self.assertEqual(result['value_sources']['ambient'],result['value_sources']['diffuse'])


ANDROID_VALUES = {'ambient': [0.25, 0.5, 0.75], 'diffuse': [2.0, 1.5, 1.0], 'specular': [4.0, 2.0, 0.0], 'power': 0x42000000}


def android(light='_ZN10StarSystem9initLightEv', rim=True, gap=False, setups=1, app=(9, 9, 9, 9), renderer=0xa8, lead=(), fields=None,
            values=ANDROID_VALUES, twice=(), rims=1):
    """StarSystem::initLight's rim call and material setup, GetEngine and the four setters in the Android shape."""
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm, build
    engine = '_ZN11AbyssEngine18ApplicationManager9GetEngineEv'
    fields = dict({'ambient': 0x298, 'diffuse': 0x288, 'specular': 0x2a8, 'power': 0x2b8}, **(fields or {}))
    asm = Asm(TEXT + 0x100).push()
    def rim_call():
        asm.ldr_address(0, RODATA).vmov_imm(0, 0x08).add_pc(0).add_reg(1, 0, 6, 2).add_reg(2, 0, 4, 2).add_reg(0, 0, 10, 2)
        asm.vldr(2, 2, 0).vldr(4, 0, 0).ldr_w(0, 9).vmul(22, 2, 0).vldr(6, 1, 0).vmul(17, 4, 0).vmul(19, 6, 0).call_to(engine)
        asm.vmov_core(1, 22).vmov_core(2, 17).vmov_core(3, 19).call_to('_ZN11AbyssEngine6Engine16LightSetRimColorEfff')
    if rim:
        rim_call()
    if gap:
        asm.nop()
    for n in range(setups):
        for role, setter in reader.ANDROID_SETTERS.items():
            asm.ldr_w(0, app[reader.ROLES.index(role)]).call_to(engine)
            if role == 'power':
                asm.movs(1, values['power'] & 0xffff).movt(1, values['power'] >> 16)
            else:
                for i, value in enumerate(values[role]):
                    asm.mov_imm(i + 1, struct.unpack('<I', struct.pack('<f', value))[0])
            asm.call_to(setter[0])
    for _ in range(rims - 1):
        rim_call()
    functions = {light: asm.ret(), engine: Asm(TEXT + 0x400).half(*([0xbf00] if 'renderer' in lead else [])).ldr_w(0, 0, renderer).ret()}
    for at, (role, (setter, _)) in zip(range(TEXT + 0x500, TEXT + 0x900, 0x100), reader.ANDROID_SETTERS.items()):
        body = Asm(at).half(*([0xbf00] if role in lead else []))
        for _ in range(2 if role in twice else 1):
            if role == 'power':
                body.mov(2, 1).ldr_address(1, 0x9000).str_w(2, 0, fields[role])
            else:
                body.ldr_pc(12, 0x9000).strd(1, 2, 0, fields[role]).add_low(12, 15).str_w(3, 0, fields[role] + 8)
        functions[setter] = body.ret()
    return build(functions, {RODATA: bytes(228)})


class AndroidSurfaceMaterial(unittest.TestCase):
    colors = {'provenance': {'rim': {'offset': 1610533, 'bytes': 48}}}

    def test_values_and_spans(self):
        from android_fixture import TEXT
        result = reader.extract_surface_material(android(), self.colors)
        self.assertEqual({key: result[key] for key in ['ambient_rgb', 'diffuse_rgb', 'specular_rgb', 'specular_power']},
                         {'ambient_rgb': [0.25, 0.5, 0.75], 'diffuse_rgb': [2.0, 1.5, 1.0], 'specular_rgb': [4.0, 2.0, 0.0], 'specular_power': 32.0})
        self.assertEqual(result['provenance'], {'rim': {'offset': TEXT + 0x102, 'bytes': 68}, 'setup': {'offset': TEXT + 0x146, 'bytes': 90},
                                                'renderer': {'offset': TEXT + 0x400, 'bytes': 6}, 'ambient': {'offset': TEXT + 0x500, 'bytes': 14},
                                                'diffuse': {'offset': TEXT + 0x600, 'bytes': 14}, 'specular': {'offset': TEXT + 0x700, 'bytes': 14},
                                                'power': {'offset': TEXT + 0x800, 'bytes': 8}})
        self.assertEqual(result['value_sources'], {role: {'offset': TEXT + 0x146 + at, 'bytes': 6 if role == 'power' else 12}
                                                   for role, at in [('ambient', 8), ('diffuse', 32), ('specular', 56), ('power', 80)]})

    def test_each_broken_shape_is_unsupported(self):
        cases = {'function': dict(light='_ZN10StarSystem4initEv'), 'no rim': dict(rim=False), 'gap': dict(gap=True),
                 'two setups': dict(setups=2), 'two rims': dict(rims=2), 'mixed holder': dict(app=(9, 9, 8, 9)), 'rim holder': dict(app=(8, 8, 8, 8)), 'renderer field': dict(renderer=0xa4),
                 'renderer start': dict(lead=('renderer',)), 'setter start': dict(lead=('diffuse',)),
                 'setter twice': dict(twice=('power',)), 'ambient field': dict(fields={'ambient': 0x290}),
                 'diffuse field': dict(fields={'diffuse': 0x298}), 'specular field': dict(fields={'specular': 0x2a4}),
                 'power field': dict(fields={'power': 0x2bc}),
                 'color range': dict(values=dict(ANDROID_VALUES, diffuse=[2.0, 32.0, 1.0])),
                 'negative color': dict(values=dict(ANDROID_VALUES, specular=[4.0, -2.0, 0.0])),
                 'zero power': dict(values=dict(ANDROID_VALUES, power=0)),
                 'power range': dict(values=dict(ANDROID_VALUES, power=0x45000000))}
        for name, options in cases.items():
            self.assertEqual(reader.extract_surface_material(android(**options), self.colors), {}, name)
        for colors in [{}, {'provenance': {}}, {'provenance': {'sun': {'offset': 1, 'bytes': 1}}}]:
            self.assertEqual(reader.extract_surface_material(android(), colors), {}, colors)
