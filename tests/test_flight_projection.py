"""Relocatable, edition-independent perspective declarations and rejection."""
import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import flight_projection as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac, relocation=0, alternate=False):
    base = 0x100000 + relocation
    text = {'segment': b'__TEXT', 'name': b'__text', 'address': base, 'offset': 256, 'length': 9000}
    const = {'segment': b'__TEXT', 'name': b'__const', 'address': base+10000, 'offset': 10000, 'length': 64}
    m = SimpleNamespace(architecture='x86_64' if mac else 'armv7', text=text, sections=[text,const], slice_offset=0)
    data = bytearray(11000); prefix = 'MAC_' if mac else 'ARM_'
    blocks = {k: expand(reader.MAC_ALTERNATES[k] if alternate and mac and k in reader.MAC_ALTERNATES else getattr(reader,prefix+k.upper())) for k in ['start','setter','predicate','compare','metrics']}
    addresses = {k:base+i*1024 for i,k in enumerate(blocks)}
    addresses.update(cursor=base+6000, other=base+7000)
    links = {('start','call_61' if mac else 'call_60'):'setter',('start','call_14' if mac else 'call_18'):'predicate',
             ('start','call_31' if mac else 'call_28'):'cursor',('predicate','call_12' if mac else 'jump_6'):'compare',
             ('setter','call_ab' if mac else 'call_bc'):'metrics'}
    jumps = {'start':{'jump_1b':0x27,'jump_25':0x4b},'compare':{'jump_9':0x14},'setter':{'jump_2f':0x3a,'jump_35':0xcf,'jump_bd':0xcf},'metrics':{'jump_2d':0x38,'jump_33':0x167}} if mac else {
             'start':{'jump_1e':0x3a,'jump_38':0x3e},'setter':{'jump_36':0x3a,'jump_38':0xd4,'jump_ca':0xd4},'metrics':{'jump_4c':0x50,'jump_4e':0x186}}
    if alternate and mac:
        jumps['metrics']['jump_33'] = 0x176
    def relative(site,target,size,kind):
        if mac: return int(target-site-size).to_bytes(size,'little',signed=True)
        delta=target-site-4
        if kind in ['b','bne','blo']: return struct.pack('<H',({'b':0xe000,'bne':0xd100,'blo':0xd300}[kind])|((delta//2)&(2047 if kind=='b' else 255)))
        raw=bytearray(branch(((site+4)&~3)-4 if kind=='blx' else site,target))
        if kind=='b.w': raw[3]&=~0x40
        if kind=='blx': raw[3]&=~0x10
        return raw
    # Modified values prove that the reader imports operands instead of defaults.
    scalars = {'fov':1.0, 'near':32.0, 'fallback':120000.0, 'far':120000.0, 'extended':240000.0}
    locations = {'fov':base+10000,'near':base+10004,'fallback':base+(10008 if mac else 512),'far':base+(10012 if mac else 516)}
    files = {k:(const['offset']+v-const['address'] if mac else 256+v-base) for k,v in locations.items()}
    for k in ['fov','near','fallback','far']:
        if mac or k in ['fallback','far']: struct.pack_into('<f',data,files[k],scalars[k])
    struct.pack_into('<f',data,files['far']+4,scalars['extended'])
    for key,(body,fields) in blocks.items():
        for field,(off,size) in fields.items():
            site=addresses[key]+off
            meta=reader.ARM_FIELDS.get(prefix+key.upper(),{}).get(field,{})
            if (key,field) in links: raw=relative(site,addresses[links[key,field]],size,meta.get('kind','bl'))
            elif field.startswith('call_'): raw=relative(site,addresses['other'],size,meta.get('kind','bl'))
            elif field.startswith('jump_'): raw=relative(site,addresses[key]+jumps[key][field],size,meta.get('kind','bl'))
            elif field.startswith('ref_'):
                target=locations[{'ref_1d':'fallback','ref_3f':'far','ref_4b':'fov','ref_53':'near'}[field]] if field in ['ref_1d','ref_3f','ref_4b','ref_53'] else base+8000
                raw=relative(site,target,size,'bl')
            elif field.startswith('word_'):
                bits=struct.unpack('<I',struct.pack('<f',scalars['near' if field=='word_4e' else 'fov']))[0]
                value=(bits >> 16 if meta['kind']=='movt' else bits&65535) if key=='start' and field in ['word_3e','word_4a','word_4e'] else 0
                raw=arm_wide(value,int(meta['register'][1:]),meta['kind']=='movt')
            elif field=='literal_3a': raw=struct.pack('<HH',0xed9f,0xa00+(locations['fallback']-((site+4)&~3))//4)
            elif field=='address_2c': raw=struct.pack('<H',0xa100+(locations['far']-((site+4)&~3))//4)
            else: raise AssertionError(field)
            body[off:off+size]=raw
        file=256+addresses[key]-base; data[file:file+len(body)]=body
    raw=bytes.fromhex('554889e58b87780200005dc3' if mac else 'd0f8d4017047')
    file=256+addresses['cursor']-base; data[file:file+len(raw)]=raw
    m.data=bytes(data)
    return m,blocks,addresses,files


@unittest.skipUnless(importlib.util.find_spec('capstone'),'optional static-reader dependency')
class FlightProjection(unittest.TestCase):
    def test_alternate_mac_stack_and_projection_context(self):
        for relocation in (0, 0x90000):
            m, blocks, addresses, _ = fixture(True, relocation, alternate=True)
            result = reader.extract_flight_projection(m)
            self.assertEqual([result[k] for k in ['vertical_fov_radians', 'near', 'far', 'matching_location_early_far']], [1, 32, 120000, 240000])
            for key, position in [('setter', 0x52 + 4), ('metrics', blocks['metrics'][1]['jump_33'][0])]:
                original = m.data
                data = bytearray(original)
                data[256 + addresses[key] - m.text['address'] + position] ^= 4
                m.data = bytes(data)
                self.assertFalse(reader.extract_flight_projection(m), key)
                m.data = original

    def test_relocated_changed_parameters(self):
        for mac in [True,False]:
            for relocation in [0,0x90000]:
                m,*_=fixture(mac,relocation); result=reader.extract_flight_projection(m)
                self.assertTrue(result)
                self.assertEqual([result[k] for k in ['vertical_fov_radians','near','far','matching_location_early_far']], [1,32,120000,240000])
                self.assertEqual(result['early_cursor_limit'],80)

    def test_damaged_context(self):
        for mac in [True,False]:
            for bad in ['start','setter','predicate','compare','metrics','cursor','branch','link','nan','mismatch','near','duplicate','truncated']:
                with self.subTest(mac=mac,bad=bad):
                    m,blocks,addresses,files=fixture(mac); data=bytearray(m.data)
                    def file(key,field=None): return 256+addresses[key]-m.text['address']+(blocks[key][1][field][0] if field else 0)
                    if bad in addresses: data[file(bad)+(8 if bad=='start' and not mac else 0)]^=1
                    elif bad=='branch': data[file('start','jump_1b' if mac else 'jump_1e')]^=2
                    elif bad=='link': data[file('start','call_61' if mac else 'call_60')]^=2
                    elif bad=='nan': struct.pack_into('<f',data,files['far']+4,float('nan'))
                    elif bad=='mismatch': struct.pack_into('<f',data,files['fallback'],100)
                    elif bad=='near':
                        if mac: struct.pack_into('<f',data,files['near'],-1)
                        else:
                            off=file('start','word_4e');data[off:off+4]=arm_wide(0xbf80,3,True)
                    elif bad=='duplicate':
                        body=blocks['start'][0];data[8000:8000+len(body)]=body
                    elif bad=='truncated': data=data[:file('metrics')+5]
                    m.data=bytes(data)
                    self.assertEqual(reader.extract_flight_projection(m),{})

if __name__=='__main__': unittest.main()


def android(fov=1.0000001, near=16.000002, far=(250000.0, 400000.0), fallback=250000.0, limit=0x50, predicate='_ZN6Status12inAlienOrbitEv',
            vertical=0x48, table_inside=True, starts=1, setter_height=True, fallback_at=None, omit=None):
    """MGame::reset's projection setup and both CameraSetPerspective functions in the Android shape."""
    from android_fixture import TEXT, Thumb
    from gof2_content import flight_projection as p
    from gof2_content.android_library import AndroidLibrary
    from test_steering import (add_pc, adds8, assemble, b_to, cmp_imm, cmp_reg, ldr_lit, ldr_reg, ldr_w, roomy_library, sub_sp, vdiv,
                               vldr_pc, vmov_from_core, vmov_imm, vstr, wide)
    names = ['_ZN6Status12inAlienOrbitEv', '_ZN6Status25getCurrentCampaignMissionEv', '_ZN11AbyssEngine6Engine15GetDisplayWidthEv',
             '_ZN11AbyssEngine6Engine16GetDisplayHeightEv', '_ZN11AbyssEngine6AEMath4SinfEf', '_ZN11AbyssEngine6AEMath4CosfEf',
             '_ZN6Status10getWingmenEv']
    at = {name: TEXT + 0x40 * i for i, name in enumerate(names, 1)}
    start, setter, metrics = TEXT + 0x400, TEXT + 0x600, TEXT + 0x800

    def halves(value):
        word, = struct.unpack('<I', struct.pack('<f', value))
        return word & 0xffff, word >> 16

    def emit_start(asm, L):
        asm.push()
        for copy in range(starts):
            ldr_lit(asm, 0, 0x40)
            ldr_w(asm, 5, 4, 0xec)
            add_pc(asm, 0).ldr(6, 6, 0).ldr(0, 0, 0).ldr(0, 0, 0).call(at[predicate])
            b_to(cmp_imm(asm, 0, 1), L.get(f'fallback{copy}', asm.here() + 4), 'ne')
            ldr_lit(asm, 0, 0x40)
            add_pc(asm, 0).ldr(0, 0, 0).ldr(0, 0, 0).call(at['_ZN6Status25getCurrentCampaignMissionEv'])
            table = L.get('table', asm.here() + 4) if table_inside else start + 0x100
            asm.half(0xa100 | (table - ((asm.here() + 4) & ~3)) // 4)  # adr r1, table
            cmp_imm(asm, 0, limit).half(0xbfb8)  # it lt
            adds8(asm, 1, 4).vldr(0, 1, 0)
            b_to(asm, L.get(f'fov{copy}', asm.here() + 4)).label(f'fallback{copy}')
            vldr_pc(asm, 0, fallback_at or L.get('pool', asm.here() + 8)).label(f'fov{copy}')
            (fl, fh), (nl, nh) = halves(fov), halves(near)
            asm.movw(2, fl).movs(3, nl).movt(2, fh).movt(3, nh).mov(0, 6).mov(1, 5)
            vstr(asm, 0, 13, 0).call(setter)
        asm.pop()
        if asm.here() % 4:
            asm.nop()
        asm.label('pool').data(*(struct.unpack('<I', struct.pack('<f', v))[0] for v in (fallback,)))
        asm.label('table').data(*(struct.unpack('<I', struct.pack('<f', v))[0] for v in far))

    def emit_setter(asm, L):
        wide(asm, 0xe92d41f0).add_sp(7, 0xc)  # push.w {r4-r8, lr}
        sub_sp(wide(asm, 0xed2d8b04), 8).mov(5, 0).mov(8, 3)  # vpush {d8, d9}
        cmp_reg(ldr_w(asm, 0, 5, 0x164).mov(4, 1).mov(6, 2), 0, 4)
        b_to(asm, L.get('end', asm.here() + 4), 'ls')
        asm.ldr(0, 5, 0x34).vldr(16, 7, 0xc).call(at['_ZN11AbyssEngine6Engine15GetDisplayWidthEv'])
        vmov_from_core(asm, 0, 0).vcvt(18, 0).ldr(0, 5, 0x34).call(at['_ZN11AbyssEngine6Engine16GetDisplayHeightEv' if setter_height else '_ZN11AbyssEngine6Engine15GetDisplayWidthEv'])
        vmov_from_core(asm.vmov_core(2, 16).mov(1, 8).vmov_core(3, 18), 0, 0).vcvt(0, 0)
        ldr_reg(ldr_w(asm, 0, 5, 0x168), 0, 0, 4, 2).str_sp(0, 4).mov(0, 6)
        vstr(asm, 0, 13, 0).call(metrics).label('end').pop()

    def emit_metrics(asm, L):
        asm.half(0xb5b0).add_sp(7, 8)  # push {r4, r5, r7, lr}
        wide(asm, 0xed2d8b06).ldr(5, 7, 0xc)  # vpush {d8, d9, d10}
        b_to(cmp_imm(asm, 5, 0), L.get('end', asm.here() + 4), 'eq')
        vmov_imm(asm, 6, 0.5).vldr(16, 7, 8)
        vmov_from_core(vmov_from_core(vmov_from_core(asm, 4, 0), 0, 2), 2, 1)
        vmov_from_core(vstr(asm, 4, 5, 0), 18, 3)
        vstr(vstr(asm, 2, 5, 4), 0, 5, 8).vmul(6, 4, 6).vmov_core(4, 6).mov(0, 4).call(at['_ZN11AbyssEngine6AEMath4SinfEf'])
        vmov_from_core(asm, 20, 0).mov(0, 4).call(at['_ZN11AbyssEngine6AEMath4CosfEf'])
        vdiv(vdiv(vmov_from_core(asm, 0, 0).mov(0, 4), 2, 18, 16), 0, 20, 0).vmul(4, 2, 0)
        vstr(vstr(vstr(asm, 0, 5, vertical), 4, 5, 0x4c if vertical == 0x48 else 0x48), 2, 5, 0x50)
        asm.label('end').pop()
    functions = [(name, Thumb(address).ret().finish(), address) for name, address in at.items()]
    # The same table outside MGame::reset, for an adr that leaves the function.
    functions.append(('_Z5tablev', Thumb(start + 0x100).data(*(struct.unpack('<I', struct.pack('<f', v))[0] for v in far)).finish(), start + 0x100))
    functions += [(p.ANDROID_START, assemble(start, emit_start).finish(), start), (p.ANDROID_SETTER, assemble(setter, emit_setter).finish(), setter),
                  (p.ANDROID_METRICS, assemble(metrics, emit_metrics).finish(), metrics)]
    return AndroidLibrary(roomy_library([f for f in functions if f[0] != omit]))


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidFlightProjection(unittest.TestCase):
    def test_named_projection(self):
        from android_fixture import TEXT
        result = reader.extract_flight_projection(android())
        provenance = result.pop('provenance')
        self.assertEqual(result, {'vertical_fov_radians': struct.unpack('<f', struct.pack('<f', 1.0000001))[0],
                                  'near': struct.unpack('<f', struct.pack('<f', 16.000002))[0], 'far': 250000.0, 'matching_location_early_far': 400000.0,
                                  'early_cursor_limit': 80, 'fov_axis': 'vertical'})
        self.assertEqual({k: (v['offset'] - TEXT, v['bytes']) for k, v in provenance.items()},
                         {'start': (0x402, 78), 'setter': (0x600, 90), 'metrics': (0x800, 104), 'far': (0x458, 8), 'fallback': (0x454, 4)})

    def test_each_broken_declaration_is_unsupported(self):
        from android_fixture import TEXT
        from gof2_content import flight_projection as p
        cases = {'fallback': dict(fallback=260000.0), 'limit': dict(limit=0x40), 'predicate': dict(predicate='_ZN6Status10getWingmenEv'),
                 'horizontal': dict(vertical=0x4c), 'table outside': dict(table_inside=False), 'two starts': dict(starts=2),
                 'wide fov': dict(fov=4.0), 'zero fov': dict(fov=0.0), 'far near': dict(far=(10.0, 400000.0), fallback=10.0), 'negative near': dict(near=-16.0),
                 'distant': dict(far=(2e9, 400000.0), fallback=2e9), 'nan': dict(far=(250000.0, float('nan'))),
                 'setter': dict(setter_height=False), 'fallback outside': dict(fallback_at=TEXT + 0x3f0)}
        cases.update({name: dict(omit=name) for name in (p.ANDROID_START, p.ANDROID_SETTER, p.ANDROID_METRICS)})
        for name, options in cases.items():
            self.assertEqual(reader.extract_flight_projection(android(**options)), {}, name)
