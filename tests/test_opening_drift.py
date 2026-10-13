"""Relocated opening drift declarations and malformed helper rejection."""
import importlib.util
import struct
import unittest
from test_opening_camera import camera_fixture
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch
from gof2_content import opening_drift as reader
from gof2_content.opening_camera import extract_opening_camera
from gof2_content.opening_staging import extract_opening_staging


def fixture(mac, relocation=0):
    m,parents,parent_addresses,parent_scalars,helpers=camera_fixture(mac,relocation)
    data=bytearray(m.data);base=m.text['address'];prefix='MAC_' if mac else 'ARM_'
    blocks={k:expand(getattr(reader,prefix+k.upper())) for k in ['wave','sine','translate']}
    addresses={k:base+30000+i*1024 for i,k in enumerate(blocks)}
    addresses['getter']=base+34000
    def link(site,dest,size,kind='bl'):
        if mac:return int(dest-site-size).to_bytes(size,'little',signed=True)
        raw=bytearray(branch(((site+4)&~3)-4 if kind=='blx' else site,dest))
        if kind=='blx':raw[3]&=~0x10
        return raw
    def patch_parent(field,dest):
        off,size=parents['cut'][1][field];site=parent_addresses['cut']+off
        data[256+site-base:256+site-base+size]=link(site,dest,size)
    patch_parent('call_22' if mac else 'call_30',addresses['wave'])
    patch_parent('call_56' if mac else 'call_5e',addresses['translate'])
    frequency=0.03125
    if mac:
        struct.pack_into('<f',data,parent_scalars['cut','ref_1a'],frequency)
        struct.pack_into('<f',data,parent_scalars['cut','ref_27'],-0.25)
    else:
        bits=struct.unpack('<I',struct.pack('<f',frequency))[0]
        for field,high in [('word_c',False),('word_24',True)]:
            off,size=parents['cut'][1][field];file=256+parent_addresses['cut']+off-base
            parent_scalars['drift',field]=file
            data[file:file+size]=arm_wide(bits>>16 if high else bits&65535,1,high)
    const=m.sections[1];next_constant=const['offset']+const['length'];sign_file=None
    for key,(body,fields) in blocks.items():
        for field,(off,size) in fields.items():
            site=addresses[key]+off
            meta=reader.ARM_FIELDS.get(prefix+key.upper(),{}).get(field,{})
            if field.startswith('call_'):
                if key=='wave' and field in (['call_15','call_34'] if mac else ['call_1a','call_36']): dest=addresses['getter']
                elif key=='wave' and field in (['call_27','call_46'] if mac else ['call_2e','call_4e']): dest=addresses['sine']
                else: dest=helpers['other']
                raw=link(site,dest,size,meta.get('kind','bl'))
            elif field.startswith('jump_'):raw=link(site,addresses[key]+0x5f,size)
            elif field.startswith('ref_'):
                dest=const['address']+next_constant-const['offset'];raw=link(site,dest,size)
                data[next_constant:next_constant+4]=bytes.fromhex('00000080') if field=='ref_58' else bytes(4)
                if field=='ref_58':sign_file=next_constant
                next_constant+=4
            elif field.startswith('word_'):raw=arm_wide(1,0,meta['kind']=='movt')
            else:raise ValueError(field)
            assert len(raw)==size
            body[off:off+size]=raw
        file=256+addresses[key]-base;data[file:file+len(body)]=body
    getter=bytes.fromhex('554889e5488b87480200005dc3' if mac else 'd0e969017047')
    file=256+addresses['getter']-base;data[file:file+len(getter)]=getter
    const['length']=next_constant-const['offset'];m.data=bytes(data)
    return m,blocks,addresses,sign_file,parent_scalars


@unittest.skipUnless(importlib.util.find_spec('capstone'),'optional static-reader dependency')
class OpeningDrift(unittest.TestCase):
    def test_changed_relocated_frequency(self):
        for mac in [True,False]:
            for relocation in [0,0x90000]:
                m,*_=fixture(mac,relocation)
                camera=extract_opening_camera(m,extract_opening_staging(m));self.assertTrue(camera)
                result=reader.extract_opening_drift(m,camera);self.assertTrue(result)
                self.assertEqual(result['frequency_per_millisecond'],0.03125)
                self.assertEqual(result['bias'],-0.25 if mac else -0.5)
                self.assertEqual(result['actor_ids'],[0,1,2])
                self.assertEqual(result['application'],'per_update_world_y')

    def test_damaged_scopes(self):
        for mac in [True,False]:
            for bad in ['wave','sine','translate','getter','link','branch','frequency','missing','provenance','truncated']+(['sign'] if mac else ['register']):
                with self.subTest(mac=mac,bad=bad):
                    m,blocks,addresses,sign,scalars=fixture(mac);data=bytearray(m.data);base=m.text['address']
                    file=lambda k,f=None:256+addresses[k]-base+(blocks[k][1][f][0] if f else 0)
                    if bad in ['wave','sine','translate','getter']:data[file(bad)]^=1
                    elif bad=='link':data[file('wave','call_34' if mac else 'call_36')]^=4
                    elif bad=='branch':data[file('wave','jump_56') if mac else file('wave')+0x5e]^=1
                    elif bad=='frequency':
                        if mac:struct.pack_into('<f',data,scalars['cut','ref_1a'],float('nan'))
                        else:
                            lo=scalars['drift','word_c'];hi=scalars['drift','word_24']
                            data[lo:lo+4]=arm_wide(0,1,False)
                            data[hi:hi+4]=arm_wide(0x7fc0,1,True)
                    elif bad=='sign':data[sign+3]=0
                    elif bad=='register':
                        f=file('wave','word_8');data[f:f+4]=arm_wide(1,1,False)
                    elif bad=='truncated':data=data[:file('translate')+5]
                    m.data=bytes(data)
                    camera=extract_opening_camera(m,extract_opening_staging(m))
                    if bad=='missing':camera={}
                    if bad=='provenance':camera['provenance']['cut']['offset']+=2
                    self.assertEqual(reader.extract_opening_drift(m,camera),{})

if __name__=='__main__':unittest.main()


def android(wave_condition='gt', clock_field=0x1b8, sine_jump=True, translate_y=0x5c, omit=None, **camera_options):
    """The camera fixture plus Layout::getPulseValue, Sinf, Status::getPlayingTime and AEGeometry::translate."""
    from android_fixture import TEXT, Thumb
    from test_opening_camera import android as camera
    from test_opening_staging import STAGING_CALLEES
    from test_steering import (add_imm, add_pc, b_to, ldr_lit, ldr_reg, ldr_w, ldrd, sub_sp, vadd, vfp, vldr_pc, vmov_from_core,
                               vneg, vpush_d8, vstr, wide, CONDITIONS)
    wave, sine, clock, translate, l2f = (TEXT + 0x1a00 + 0x100 * i for i in range(5))
    staged = {name: TEXT + 0x40 * i for i, name in enumerate(STAGING_CALLEES)}
    asm = Thumb(wave)
    asm.half(0xb5b0, 0xaf02)  # push {r4, r5, r7, lr}; add r7, sp, #8
    vpush_d8(asm)
    vmov_from_core(ldr_lit(asm, 0, 0x60), 16, 1)
    add_pc(asm, 0).ldr(5, 0, 0)
    for second in (False, True):
        asm.ldr(0, 5, 0).call(clock).call(l2f)
        vmov_from_core(asm, 0, 0).vmul(0, 0, 16).vmov_core(0, 0).call(sine)
        if not second:
            asm.mov(4, 0)
    vmov_from_core(vmov_from_core(asm, 4, 4), 0, 0)
    wide(asm, 0xeeb52ac0)  # vcmpe.f32 s4, #0
    asm.half(0xeef1, 0xfa10)  # vmrs apsr_nzcv, fpscr
    vneg(asm, 2, 0).half(0xbf00 | CONDITIONS[wave_condition] << 4 | 8)  # it <condition>
    vfp(asm, 0xeeb00a40, 2, 0, 0).vmov_core(0, 2)  # vmov<condition>.f32 s2, s0
    asm.half(0xecbd, 0x8b02, 0xbdb0)  # vpop {d8}; pop {r4, r5, r7, pc}
    functions = [('_ZN6Layout13getPulseValueEf', asm.finish(), wave)]
    asm = Thumb(sine)
    functions.append(('_ZN11AbyssEngine6AEMath4SinfEf', (b_to(asm, l2f, None, True) if sine_jump else asm.ret()).finish(), sine))
    functions.append(('_ZN6Status14getPlayingTimeEv', ldrd(Thumb(clock), 0, 1, 0, clock_field).ret().finish(), clock))
    functions.append(('__aeabi_l2f', Thumb(l2f).ret().finish(), l2f))
    asm = wide(Thumb(translate), 0xe92d4ff0).add_sp(7, 0xc)  # push.w {r4-fp, lr}
    vpush_d8(sub_sp(asm, 4))
    ldr_lit(sub_sp(asm, 0x80).mov(11, 0), 0, 0x90).mov(10, 2)
    add_imm(add_pc(vmov_from_core(asm, 16, 1), 0).mov(9, 3), 8, 13, 0x40).ldr(0, 0, 0).ldr(0, 0, 0).str_sp(0, 0x7c)
    ldr_w(ldr_w(asm, 2, 11, 0xc), 0, 11, 0x2c).mov(1, 2).call(TEXT + 0x1f00)
    vmov_from_core(asm.mov(1, 8).half(0xc87c), 6, 10).stm(1, 2, 3, 4, 5, 6).half(0xc87c).stm(1, 2, 3, 4, 5, 6)
    wide(asm, 0xe890007c).add_sp(0, 4).stm(1, 2, 3, 4, 5, 6).mov(1, 8)
    vadd(asm.vldr(0, 13, 0x4c).vldr(2, 13, translate_y), 0, 0, 16).vldr(4, 13, 0x6c)
    vmov_from_core(vadd(asm, 2, 2, 6).vmov_core(2, 0).vmov_core(3, 2), 0, 9)
    vstr(vadd(asm, 0, 4, 0), 0, 13, 0).call(staged['_ZN11AbyssEngine6AEMath20MatrixSetTranslationERNS0_6MatrixEfff'])
    ldr_w(ldr_w(asm, 1, 11, 0xc).mov(2, 8), 0, 11, 0x2c).call(TEXT + 0x1f40).pop()
    functions.append(('_ZN10AEGeometry9translateEfff', asm.finish(), translate))
    functions += [('_ZN11AbyssEngine11PaintCanvas17TransformGetLocalEj', Thumb(TEXT + 0x1f00).ret().finish(), TEXT + 0x1f00),
                  ('_ZN11AbyssEngine11PaintCanvas17TransformSetLocalEjRKNS_6AEMath6MatrixE', Thumb(TEXT + 0x1f40).ret().finish(), TEXT + 0x1f40)]
    return camera(extra=[f for f in functions if f[0] != omit], omit=omit, **camera_options)


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidOpeningDrift(unittest.TestCase):
    def test_named_wave_and_cut(self):
        result = reader.extract_opening_drift(android(frequency=0x3a83126f, bias=-0.25), {'camera': True})
        provenance = result.pop('provenance')
        self.assertEqual(result, {'frequency_per_millisecond': struct.unpack('<f', struct.pack('<I', 0x3a83126f))[0], 'bias': -0.25,
                                  'actor_ids': [0, 1, 2], 'through_phase': 2, 'skip_formation_update': True, 'time_unit': 'milliseconds',
                                  'waveform': 'absolute_sine', 'application': 'per_update_world_y'})
        self.assertEqual({k: v['bytes'] for k, v in provenance.items()},
                         {'cut': 72, 'wave': 108, 'sine': 4, 'elapsed_getter': 6, 'translate': 134})
        self.assertEqual(reader.extract_opening_drift(android(), {}), {})

    def test_each_broken_declaration_is_unsupported(self):
        cases = {'zero frequency': dict(frequency=0), 'nan frequency': dict(frequency=0x7fc00000), 'far frequency': dict(frequency=0x7f000000),
                 'wave': dict(wave_condition='lt'), 'clock': dict(clock_field=0x1c0), 'sine': dict(sine_jump=False),
                 'translate': dict(translate_y=0x58), 'cut': dict(cut_phase=3)}
        cases.update({name: dict(omit=name) for name in ('_ZN6Layout13getPulseValueEf', '_ZN11AbyssEngine6AEMath4SinfEf',
                                                         '_ZN6Status14getPlayingTimeEv', '_ZN10AEGeometry9translateEfff')})
        for name, options in cases.items():
            self.assertEqual(reader.extract_opening_drift(android(**options), {'camera': True}), {}, name)
