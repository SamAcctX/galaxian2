import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import opening_clock as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac, relocation=0):
    base=0x100000+relocation; data=bytearray(8192)
    text={'segment':b'__TEXT','name':b'__text','address':base,'offset':256,'length':7000}
    m=SimpleNamespace(architecture='x86_64' if mac else 'armv7',text=text,sections=[text],slice_offset=0)
    blocks={}; prefix='MAC_' if mac else 'ARM_'
    for index,key in enumerate(['reset','frame']):
        body,fields=expand(getattr(reader,prefix+key.upper())); blocks[key]=(body,fields)
        for field,(off,size) in fields.items():
            site=base+index*1024+off
            if field.startswith('call_'): raw=int(base+3000-site-size).to_bytes(size,'little',signed=True) if mac else branch(site,base+3000)
            elif field.startswith('ref_'): raw=int(base+6000-site-size).to_bytes(size,'little',signed=True)
            elif field=='seed': raw=struct.pack('<i',12) if mac else bytes.fromhex('0023')
            else:
                meta=reader.ARM_FIELDS[prefix+key.upper()][field]
                raw=arm_wide(1,int(meta['register'][1:]),meta['kind']=='movt')
            body[off:off+size]=raw
        data[256+index*1024:256+index*1024+len(body)]=body
    raw=reader.MAC_ADD if mac else reader.ARM_ADD;data[3256:3256+len(raw)]=raw
    raw=bytes.fromhex('554889e5488b87480200005dc3' if mac else 'd0e969017047');data[4256:4256+len(raw)]=raw
    m.data=bytes(data)
    return m,{'provenance':{'elapsed_getter':{'offset':4256,'bytes':len(raw)}}},blocks


@unittest.skipUnless(importlib.util.find_spec('capstone'),'optional static-reader dependency')
class OpeningClock(unittest.TestCase):
    def test_relocated_reset_and_increment(self):
        for mac in [True,False]:
            for relocation in [0,0x90000]:
                m,drift,_=fixture(mac,relocation)
                result=reader.extract_opening_clock(m,drift,{'ship_id':1})
                self.assertTrue(result)
                self.assertEqual(result['initial_elapsed_ms'],12 if mac else 0)
                self.assertTrue(result['advance_before_controller'])

    def test_corrupt_context(self):
        for mac in [True,False]:
            for bad in ['reset','frame','increment','getter','link','seed','missing','extent','duplicate','truncated']:
                with self.subTest(mac=mac,bad=bad):
                    m,drift,blocks=fixture(mac);data=bytearray(m.data)
                    if bad in ['reset','frame','increment','getter']:
                        off={'reset':256 if mac else 270,'frame':1280 if mac else 1292,'increment':3256,'getter':4256}[bad];data[off]^=1
                    elif bad=='link': data[1280+blocks['frame'][1]['call_e' if mac else 'call_1e'][0]]^=2
                    elif bad=='seed':
                        off,size=blocks['reset'][1]['seed'];data[256+off:256+off+size]=struct.pack('<i',-1) if mac else bytes.fromhex('0123')
                    elif bad=='missing': drift={}
                    elif bad=='extent': drift['provenance']['elapsed_getter']['offset']+=1
                    elif bad=='duplicate':
                        raw=blocks['reset'][0];data[6000:6000+len(raw)]=raw
                    elif bad=='truncated':data=data[:3260]
                    m.data=bytes(data)
                    self.assertEqual(reader.extract_opening_clock(m,drift,{'ship_id':1}),{})

if __name__=='__main__':unittest.main()


def android(seed=0, seeds=1, seed_kind='movs', stores=1, frame_field=0x40, frames=1, increment_field=0x1b8, getter_field=0x1b8, omit=None):
    """Status::resetGame, MGame::OnUpdate's clock step, Status::incPlayingTime and getPlayingTime in the Android shape."""
    from android_fixture import TEXT, Thumb
    from gof2_content import opening_clock as c
    from gof2_content.android_library import AndroidLibrary
    from test_steering import add_pc, cbz, ldr_w, ldrd, roomy_library, wide
    reset, update, increment, getter = (TEXT + 0x200 * i for i in range(1, 5))
    asm = Thumb(reset).push().mov(8, 0)
    for _ in range(seeds):
        asm.movs(4, seed) if seed_kind == 'movs' else asm.mov_imm(4, seed)  # mov.w
    for _ in range(stores):
        asm.nop().strd(4, 4, 8, 0x1b8)
    functions = [(c.ANDROID_RESET, asm.pop().finish(), reset)]
    asm = Thumb(update).push()
    for _ in range(frames):
        add_pc(ldr_w(ldr_w(asm, 0, 15, 0x40), 2, 11, frame_field), 0).ldr(0, 0, 0).half(0x17d3).ldr(0, 0, 0).call(increment)  # asrs r3, r2, #31
        wide(ldr_w(asm, 0, 11, 0x7c), 0xf8900054)  # ldrb.w r0, [r0, #0x54]
        cbz(asm, 0, asm.here() + 4, True).nop()
    functions.append((c.ANDROID_UPDATE, asm.pop().finish(), update))
    asm = ldrd(Thumb(increment), 1, 12, 0, increment_field).half(0x1889)  # adds r1, r1, r2
    functions.append((c.ANDROID_INCREMENT, wide(asm, 0xeb4c0203).strd(1, 2, 0, 0x1b8).ret().finish(), increment))  # adc.w r2, ip, r3
    functions.append((c.ANDROID_GETTER, ldrd(Thumb(getter), 0, 1, 0, getter_field).ret().finish(), getter))
    return AndroidLibrary(roomy_library([f for f in functions if f[0] != omit]))


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidOpeningClock(unittest.TestCase):
    def test_named_seed_and_increment(self):
        from android_fixture import TEXT
        result = reader.extract_opening_clock(android(), {'drift': True}, {'loadout': True})
        self.assertEqual(result, {'initial_elapsed_ms': 0, 'time_unit': 'milliseconds', 'advance_before_controller': True,
                                  'provenance': {'reset': {'offset': TEXT + 0x208, 'bytes': 4}, 'seed': {'offset': TEXT + 0x204, 'bytes': 2},
                                                 'frame': {'offset': TEXT + 0x402, 'bytes': 30}, 'increment': {'offset': TEXT + 0x600, 'bytes': 16},
                                                 'getter': {'offset': TEXT + 0x800, 'bytes': 6}}})
        for drift, opening in (({}, {'loadout': True}), ({'drift': True}, {})):
            self.assertEqual(reader.extract_opening_clock(android(), drift, opening), {})

    def test_each_broken_declaration_is_unsupported(self):
        from gof2_content import opening_clock as c
        cases = {'seed': dict(seed=1), 'two seeds': dict(seeds=2), 'seed by mov.w': dict(seed_kind='mov.w'), 'two stores': dict(stores=2),
                 'frame field': dict(frame_field=0x44), 'two frames': dict(frames=2), 'increment field': dict(increment_field=0x1c0),
                 'getter field': dict(getter_field=0x1c0)}
        cases.update({name: dict(omit=name) for name in (c.ANDROID_RESET, c.ANDROID_UPDATE, c.ANDROID_INCREMENT, c.ANDROID_GETTER)})
        for name, options in cases.items():
            self.assertEqual(reader.extract_opening_clock(android(**options), {'drift': True}, {'loadout': True}), {}, name)
