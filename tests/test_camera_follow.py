"""Synthetic follow parameters and bounded coefficient-table recovery."""
import importlib.util
import struct
import unittest
from test_opening_camera import camera_fixture
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch
from gof2_content import camera_follow as reader
from gof2_content.opening_staging import extract_opening_staging
from gof2_content.opening_camera import extract_opening_camera


def fixture(mac,relocation=0,alternate=False):
    m,parents,parent_addresses,_,helpers=camera_fixture(mac,relocation)
    data=bytearray(m.data);base=m.text['address'];prefix='MAC_' if mac else 'ARM_'
    names=['follow','curve','reset','rate_scale','scale','add','subtract','point']
    blocks={k:expand(reader.MAC_ALTERNATES[k] if mac and alternate and k in reader.MAC_ALTERNATES else getattr(reader,prefix+k.upper())) for k in names}
    addresses={};at=base+30000
    for key,(body,_) in blocks.items():addresses[key]=at;at=(at+len(body)+527)&~15
    assert at<base+49000
    def encoded_link(site,dest,size,kind='bl',register='r0'):
        if mac:return (dest-site-size).to_bytes(size,'little',signed=True)
        if kind in ['bl','blx','b.w']:
            raw=bytearray(branch(((site+4)&~3)-4 if kind=='blx' else site,dest))
            if kind=='blx':raw[3]&=~0x10
            if kind=='b.w':raw[3]&=~0x40
            return raw
        d=dest-site-4
        if kind=='b':return struct.pack('<H',0xe000|((d//2)&0x7ff))
        if kind in ['cbz','cbnz']:return struct.pack('<H',0xb100|(0x800 if kind=='cbnz' else 0)|((d&0x40)<<3)|((d&0x3e)<<2)|int(register[1:]))
        if kind in ['bne','beq']:return struct.pack('<H',(0xd100 if kind=='bne' else 0xd000)|((d//2)&255))
        raise ValueError(kind)
    def patch_parent(key,field,dest):
        off,size=parents[key][1][field];site=parent_addresses[key]+off
        start=256+site-base
        data[start:start+size]=encoded_link(site,dest,size,'b.w' if not mac and field.startswith('jump') else 'bl')
    for f in ['call_3c4','call_3f4'] if mac else ['call_206','call_228']:patch_parent('defaults',f,addresses['curve'])
    patch_parent('increment','jump_52' if mac else 'jump_44',addresses['follow']-(0x795 if mac else 0x43c))
    links={
        'follow':{'point':['call_15a','call_192'],'scale':['call_2b3','call_389'],'add':['call_2be','call_3d3'],'subtract':['call_1d0','call_2f9']},
        'reset':{'rate_scale':['jump_21']},'rate_scale':{'curve':['call_37','jump_72']}
    } if mac else {
        'follow':{'point':['call_c8','call_de'],'scale':['call_1a2','call_208'],'add':['call_1ae','call_246'],'subtract':['call_f2','call_1c2']},
        'reset':{'rate_scale':['jump_18']},'rate_scale':{'curve':['call_36','call_60']}}
    edges={'jump_6d':0x78,'jump_73':0x14d,'jump_13d':0x141,'jump_13f':0x14d,'jump_395':0x3c5} if mac else {'jump_3a':0xb6,'jump_a4':0xbc,'jump_b4':0xbc,'jump_210':0x23e}
    const=m.sections[1];constant_end=const['offset']+const['length'];scalars={}
    coefficient_field='ref_2e8' if mac else 'literal_1f8'
    for key,(body,fields) in blocks.items():
        pool=(addresses[key]+len(body)+7)&~7
        for field,(off,size) in fields.items():
            site=addresses[key]+off;meta=reader.ARM_FIELDS.get(prefix+key.upper(),{}).get(field,{})
            if field.startswith(('call_','jump_')):
                alias=next((name for name,refs in links.get(key,{}).items() if field in refs),None)
                dest=addresses[alias] if alias else addresses[key]+edges[field] if key=='follow' and field in edges else helpers['other']
                kind=meta.get('kind','bl');raw=encoded_link(site,dest,size,kind,meta.get('register','r0'))
            elif field.startswith(('ref_','literal_')):
                width=8 if key=='curve' else 4
                value=57.25 if key=='curve' and field==coefficient_field else 0.0 if key=='curve' else 1.0
                bits=bytes.fromhex('0000000000000080') if mac and key=='curve' and field=='ref_235' else struct.pack('<d' if width==8 else '<f',value)
                if mac:
                    dest=const['address']+constant_end-const['offset'];file=constant_end;constant_end+=width
                    raw=encoded_link(site,dest,4)
                else:
                    dest=pool;pool+=width;file=256+dest-base;disp=dest-((site+4)&~3)
                    assert 0<=disp<=1020 and disp%4==0
                    reg=meta['register'];n=int(reg[1:]);double=reg[0]=='d'
                    raw=struct.pack('<HH',0xed9f|(((n>>4) if double else (n&1))<<6),(((n&15) if double else (n//2))<<12)|(0xb00 if double else 0xa00)|(disp//4))
                data[file:file+width]=bits;scalars[(key,field)]=file
            elif field.startswith('rate_'):raw=struct.pack('<f',.02 if field=='rate_4' else .03)
            elif field.startswith('word_'):
                val=struct.unpack('<I',struct.pack('<f',.02 if field in ['word_0','word_c'] else .03))[0]
                high=meta['kind']=='movt';raw=arm_wide(val>>16 if high else val&65535,int(meta['register'][1:]),high)
            else:raise ValueError(field)
            assert len(raw)==size
            body[off:off+size]=raw
        start=256+addresses[key]-base;data[start:start+len(body)]=body
    const['length']=constant_end-const['offset'];m.data=bytes(data)
    return m,blocks,addresses,scalars


@unittest.skipUnless(importlib.util.find_spec('capstone'),'optional static-reader dependency')
class CameraFollow(unittest.TestCase):
    def test_alternate_helpers_keep_coefficients_links_and_stack_consistent(self):
        for relocation in [0,0x80000]:
            m,blocks,addresses,_=fixture(True,relocation,alternate=True)
            camera=extract_opening_camera(m,extract_opening_staging(m))
            result=reader.extract_camera_follow(m,camera)
            self.assertTrue(result)
            self.assertEqual(result['response_matrix'][0][0],-57.25)
            self.assertEqual([result['provenance'][key]['bytes'] for key in ['add','point']],[128,256])
            for key,offset in [('add',7),('point',30)]:
                damaged=bytearray(m.data)
                damaged[256+addresses[key]-m.text['address']+offset]^=0x10
                original=m.data;m.data=bytes(damaged)
                self.assertEqual(reader.extract_camera_follow(m,camera),{})
                m.data=original

    def test_relocated_changed_rates_and_coefficients(self):
        for mac in [True,False]:
            for relocation in [0,0x80000]:
                with self.subTest(mac=mac,relocation=relocation):
                    m,*_=fixture(mac,relocation);camera=extract_opening_camera(m,extract_opening_staging(m));self.assertTrue(camera)
                    result=reader.extract_camera_follow(m,camera);self.assertTrue(result)
                    self.assertAlmostEqual(result['look_rate'],.02)
                    self.assertAlmostEqual(result['eye_rate'],.03)
                    self.assertEqual(result['response_matrix'][0][0],-57.25)
                    self.assertEqual(sum(v!=0 for row in result['response_matrix'] for v in row),1)

    def test_corrupt_follow_scope_rejected(self):
        for mac in [True,False]:
            for bad in ['missing','helper','link','rate','coefficient','sign','edge','duplicate','truncated']:
                if not mac and bad=='sign':continue
                with self.subTest(mac=mac,bad=bad):
                    m,blocks,addresses,scalars=fixture(mac);data=bytearray(m.data)
                    def file(key,field=None):return 256+addresses[key]-m.text['address']+(blocks[key][1][field][0] if field else 0)
                    if bad=='helper':data[file('scale')]^=1
                    elif bad=='link':data[file('rate_scale','call_37' if mac else 'call_36')]^=4
                    elif bad=='rate':
                        if mac:struct.pack_into('<f',data,file('reset','rate_4'),float('nan'))
                        else:
                            off=file('reset','word_c');data[off:off+4]=arm_wide(0x7fc0,2,True)
                    elif bad=='coefficient':struct.pack_into('<d',data,scalars[('curve','ref_2e8' if mac else 'literal_1f8')],float('inf'))
                    elif bad=='sign':data[scalars[('curve','ref_235')]+7]=0
                    elif bad=='edge':data[file('follow','jump_73' if mac else 'jump_3a')]^=4
                    elif bad=='duplicate':
                        body=blocks['curve'][0];data[256+47000:256+47000+len(body)]=body
                    elif bad=='truncated':data=data[:file('point')+len(blocks['point'][0])-1]
                    m.data=bytes(data)
                    camera={} if bad=='missing' else extract_opening_camera(m,extract_opening_staging(m))
                    self.assertEqual(reader.extract_camera_follow(m,camera),{})

if __name__=='__main__':unittest.main()


FOLLOW_CALLEES = ['_ZN5Level9getPlayerEv', '_ZN18TargetFollowCamera9setTargetEP10AEGeometry',
                  '_ZN18TargetFollowCamera15setTargetOffsetERKN11AbyssEngine6AEMath6VectorE',
                  '_ZN18TargetFollowCamera12setCamOffsetERKN11AbyssEngine6AEMath6VectorE', '_ZN11AbyssEngine6AEMath6VectormLEf',
                  '_ZN11AbyssEngine6AEMathmiERKNS0_6VectorES3_', '__aeabi_l2d']
CURVE_CONSTANTS = (2.5, -1.25, 0.75, 3.0, -0.5, 8.0, 0.125)


def android(constants=CURVE_CONSTANTS, curve='ok', rates=(0x3ba3d70a, 0x3bc49ba6), multiplier=0x3f800000, veneer_to='rates',
            offsets=(0x4416, 0xc4228000, 0xc4a74000), eye_field=0x88, look_field=0x60, rate_field=0x128, eye_copies=1, look_copies=1,
            omit=None):
    """TargetFollowCamera's damping curve, coefficient refresh, reset and update blocks, and LevelScript::resetCamera."""
    from unittest.mock import patch
    import android_fixture
    from android_fixture import TEXT, Thumb
    from gof2_content import camera_follow as f, opening_camera as c
    from gof2_content.android_library import AndroidLibrary
    from test_steering import (add_imm, add_pc, asr_w, assemble, cbz, ldr_lit, ldr_w, mla, mul_w, roomy_library, smull, sub_sp, umull,
                               vadd_d, vcvt_d_int, vcvt_d_s, vcvt_s_d, vdiv, vldmia_d, vldr_d, vldr_d_pc, vmov_d_core, vmov_from_core,
                               vmov_imm, vmul_d, vneg_d, vpush_d8, vstr_d, wide)
    at = {name: TEXT + 0x40 * i for i, name in enumerate(FOLLOW_CALLEES, 1)}
    curve_at, rates_at, reset_at, attach_at, update_at, veneer_at = (TEXT + 0x400 * i for i in range(1, 7))
    with patch.object(android_fixture, 'IMPORTS', android_fixture.IMPORTS + (f.ANDROID_RATES,)):
        rates_stub = android_fixture.stub(f.ANDROID_RATES)

        def emit_curve(asm, L):
            pool = L.get('pool', asm.here() + 0x100)
            ca, cb, cc, cd, ce, cf, cg = (pool + 8 * i for i in range(7))
            vcvt_d_s(vmov_from_core(asm, 0, 1), 16, 0)
            ldr_w(asm, 12, 13, 4).ldr_sp(1, 8).ldr_sp(0, 0)
            vmul_d(asm, 17, 16, 16)
            far = {'outside': curve_at - 8, 'beyond': curve_at + 0x300}.get(curve, cc)
            vldr_d_pc(vldr_d_pc(vldr_d_pc(asm, 20, ca), 21, cb), 22, far)
            vmul_d(asm, 23, 17, 20)
            if curve == 'constant product':
                vmul_d(asm, 24, 20, 23)
            else:
                vmul_d(asm, 24, 17 if curve == 'repeat' else 16, 21)
            vadd_d(asm, 25, 23, 24)
            vstr_d(asm, 25, 2)
            vstr_d(vneg_d(vmul_d(asm, 26, 16, 22), 27, 26), 27, 3 if curve != 'twice' else 2)
            vldr_d_pc(vldr_d_pc(asm, 28, cd), 29, ce)
            vstr_d(vadd_d(vmul_d(asm, 30, 16, 29), 31, 28, 30), 31, 0)
            if curve == 'unknown':
                wide(asm, 0xee332b62)  # vsub.f64 d2, d3, d18
            vstr_d(vmul_d(vldr_d_pc(asm, 2, cf), 3, 17, 2), 3, 12)
            if curve == 'high':  # x^9 for the last output
                vmul_d(vmul_d(vmul_d(asm, 6, 17, 17), 6, 6, 6), 16, 6, 16)
            if curve != 'missing':
                vstr_d(vmul_d(vldr_d_pc(asm, 4, cg), 5, 4, 16), 5, 1)
            if curve == 'again':
                vstr_d(asm, 3, 2)
            if curve == 'stray':
                vstr_d(asm, 3, 5)
            if curve != 'open':
                asm.ret()
            while (asm.here() - 4) % 8:
                asm.nop()
            asm.label('pool').data(*(w for v in constants for w in struct.unpack('<2I', struct.pack('<d', v))))

        def rate_set(asm, field, first):
            asm.vldr(0, 4, field)
            add_imm(add_imm(add_imm(asm, 2, 4, first + 0x18), 3, 4, first + 0x10), 0, 4, first + 0x20).vmul(0, 0, 16)
            add_imm(add_imm(asm.strd(3, 2, 13, 0), 2, 4, first), 3, 4, first + 8).str_sp(0, 8).vmov_core(1, 0).call(curve_at)

        def emit_rates(asm, L):
            vmov_from_core(sub_sp(vpush_d8(asm.half(0xb5d0).add_sp(7, 8)), 0x10).mov(4, 0), 16, 1)
            rate_set(asm, rate_field, 0x60)
            rate_set(asm, 0x12c, 0x88)
            asm.half(0xb004, 0xecbd, 0x8b02, 0xbdd0)  # add sp, #0x10; vpop {d8}; pop {r4, r6, r7, pc}

        def emit_reset(asm, L):
            asm.movw(1, rates[0] & 0xffff).movw(2, rates[1] & 0xffff).movt(1, rates[0] >> 16).movt(2, rates[1] >> 16)
            asm.strd(1, 2, 0, 0x128).mov_imm(1, multiplier)
            from test_steering import b_to
            b_to(asm, veneer_at, None, True)

        def emit_attach(asm, L):
            sub_sp(asm.push().add_sp(7, 0xc), 0x14).mov(4, 0)
            ldr_lit(asm, 0, 0x40).mov(5, 1)
            add_pc(asm, 0).ldr(0, 0, 0).ldr(0, 0, 0).str_sp(0, 0x10).mov(0, 5).call(at['_ZN5Level9getPlayerEv'])
            cbz(asm, 0, L.get('end', asm.here() + 4)).mov(0, 5).ldr(6, 4, 0x14).call(at['_ZN5Level9getPlayerEv'])
            asm.ldr(1, 0, 8).mov(0, 6).call(at['_ZN18TargetFollowCamera9setTargetEP10AEGeometry'])
            y, look, eye = offsets
            asm.movs(6, 0).movw(1, look & 0xffff).ldr(0, 4, 0x14).movs(5, 0).movt(6, y).movt(1, look >> 16)
            asm.str_sp(5, 4).str_sp(6, 8).str_sp(1, 0xc).add_sp(1, 4).call(at['_ZN18TargetFollowCamera15setTargetOffsetERKN11AbyssEngine6AEMath6VectorE'])
            asm.movw(1, eye & 0xffff).ldr(0, 4, 0x14).movt(1, eye >> 16).strd(5, 6, 13, 4).str_sp(1, 0xc).add_sp(1, 4)
            asm.call(at['_ZN18TargetFollowCamera12setCamOffsetERKN11AbyssEngine6AEMath6VectorE']).label('end').pop()

        def emit_update(asm, L):
            asm.push()
            for _ in range(eye_copies):
                eye_block(asm)
            for _ in range(look_copies):
                look_block(asm)
            asm.pop()

        def eye_block(asm):
            mul_w(asm, 0, 10, 10)
            vmov_imm(add_imm(asm, 2, 11, eye_field), 2, 1.0)
            vmov_from_core(mul_w(add_imm(asm, 8, 13, 0x24), 1, 0, 10), 0, 1)
            vcvt_d_int(mul_w(asm, 1, 1, 10), 16, 0)
            vcvt_d_int(vldmia_d(vmov_from_core(asm, 0, 1), 2, 17, 4), 21, 0)
            vmul_d(vmul_d(vmov_from_core(asm, 0, 0).mov(0, 8), 16, 16, 18), 17, 21, 17)
            vmul_d(vmov_from_core(vcvt_d_int(asm, 22, 0), 0, 10), 19, 22, 19)
            vadd_d(vcvt_d_int(asm, 18, 0), 16, 17, 16).vcvt(0, 0)
            vdiv(vadd_d(vmul_d(asm, 17, 18, 20), 16, 16, 19), 0, 2, 0)
            vadd_d(vldr_d(vadd_d(asm, 16, 16, 17), 17, 11, 0xa8), 16, 17, 16)
            vcvt_s_d(vmul_d(vcvt_d_s(asm, 17, 0), 16, 17, 16), 0, 16).vmov_core(1, 0).call(at['_ZN11AbyssEngine6AEMath6VectormLEf'])
            asm.nop()

        def look_block(asm):
            asm.add_sp(0, 0x70).add_sp(2, 0xb0).mov(1, 4).call(at['_ZN11AbyssEngine6AEMathmiERKNS0_6VectorES3_'])
            str_r4 = asr_w(smull(asm, 8, 6, 10, 10), 3, 10, 31)
            mla(umull(str_r4.str_sp(4, 0x10).mov(4, 9), 5, 1, 8, 10), 1, 8, 3, 1)
            mla(mla(umull(asm, 0, 2, 5, 10), 9, 6, 10, 1), 2, 5, 3, 2)
            mla(asm, 1, 9, 10, 2).call(at['__aeabi_l2d'])
            asm.str_sp(0, 0xc).mov(0, 5).str_sp(4, 0x14).mov(4, 1).mov(1, 9).call(at['__aeabi_l2d'])
            vmov_d_core(asm, 8, 0, 1)
            vldmia_d(add_imm(asm, 0, 11, look_field).mov(1, 6), 0, 9, 4)
            vmov_d_core(asm.ldr_sp(0, 0xc), 13, 0, 4).mov(0, 8).ldr_sp(4, 0x14).call(at['__aeabi_l2d'])
            vmul_d(vmul_d(asm, 16, 8, 10).add_sp(6, 0x70), 17, 13, 9)
            vmul_d(vmov_from_core(vmov_d_core(asm, 14, 0, 1).mov(0, 6), 0, 10), 18, 14, 11)
            vmov_imm(vadd_d(vcvt_d_int(asm, 9, 0), 16, 17, 16), 2, 1.0).vcvt(0, 0)
            vdiv(vadd_d(vmul_d(asm, 17, 9, 12), 16, 16, 18), 0, 2, 0)
            vadd_d(vcvt_d_s(vldr_d(vadd_d(asm, 16, 16, 17), 17, 11, 0x80), 10, 0), 16, 17, 16)
            vcvt_s_d(vmul_d(asm, 16, 10, 16), 0, 16).vmov_core(1, 0).call(at['_ZN11AbyssEngine6AEMath6VectormLEf']).nop()

        functions = [(name, Thumb(address).ret().finish(), address) for name, address in at.items()]
        word = ((at['__aeabi_l2d'] if veneer_to == 'l2d' else rates_stub) - (veneer_at + 16)) & 0xffffffff
        veneer = Thumb(veneer_at).half(0x4778 if veneer_to != 'not a veneer' else 0xbf00, 0x46c0).data(0xe59fc000, 0xe08cf00f, word).finish()
        functions += [(f.ANDROID_CURVE, assemble(curve_at, emit_curve).finish(), curve_at), (f.ANDROID_RATES, assemble(rates_at, emit_rates).finish(), rates_at),
                      (f.ANDROID_RESET, assemble(reset_at, emit_reset).finish(), reset_at), (c.ANDROID_ATTACH, assemble(attach_at, emit_attach).finish(), attach_at),
                      (f.ANDROID_UPDATE, assemble(update_at, emit_update).finish(), update_at), ('_Z6veneerv', veneer, veneer_at)]
        return AndroidLibrary(roomy_library([fn for fn in functions if fn[0] != omit]))


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidCameraFollow(unittest.TestCase):
    def test_named_curve_rates_and_offsets(self):
        a, b, c, d, e, f, g = CURVE_CONSTANTS
        result = reader.extract_camera_follow(android(), {'camera': True})
        provenance = result.pop('provenance')
        self.assertEqual(result, {'look_offset': [0.0, 600.0, -650.0], 'eye_offset': [0.0, 600.0, -1338.0],
                                  'look_rate': struct.unpack('<f', struct.pack('<I', 0x3ba3d70a))[0],
                                  'eye_rate': struct.unpack('<f', struct.pack('<I', 0x3bc49ba6))[0], 'reciprocal_numerator': 1.0,
                                  # outputs 4 ... 0 (rows by ascending power of elapsed time), columns by power of rate x handling
                                  'response_matrix': [[0.0, g, 0, 0, 0, 0, 0, 0, 0], [0.0, 0, f, 0, 0, 0, 0, 0, 0], [d, e, 0, 0, 0, 0, 0, 0, 0],
                                                      [0.0, -c, 0, 0, 0, 0, 0, 0, 0], [0.0, b, a, 0, 0, 0, 0, 0, 0]]})
        self.assertEqual({k: v['bytes'] for k, v in provenance.items()},
                         {'curve': provenance['curve']['bytes'], 'rate_scale': 108, 'reset': 28, 'attach': 96, 'follow_eye': 126, 'follow_look': 176})
        self.assertEqual(reader.extract_camera_follow(android(), {}), {})

    def test_each_broken_declaration_is_unsupported(self):
        from gof2_content import camera_follow as f, opening_camera as c
        cases = {'high power': dict(curve='high'), 'curve pool outside': dict(curve='outside'), 'curve pool beyond': dict(curve='beyond'),
                 'constant product': dict(curve='constant product'), 'stored again': dict(curve='again'), 'stray store': dict(curve='stray'),
                 'two eye blocks': dict(eye_copies=2), 'two look blocks': dict(look_copies=2),
                 'negative multiplier': dict(rates=(0xbba3d70a, 0xbbc49ba6), multiplier=0xc0000000), 'repeated power': dict(curve='repeat'),
                 'output twice': dict(curve='twice'), 'unknown': dict(curve='unknown'), 'missing output': dict(curve='missing'),
'nan coefficient': dict(constants=(float('nan'),) + CURVE_CONSTANTS[1:]),
                 'zero rate': dict(rates=(0, 0x3bc49ba6)), 'large rate': dict(rates=(0x3ba3d70a, 0x40000000)),
                 'zero multiplier': dict(multiplier=0), 'large multiplier': dict(multiplier=0x43000000),
                 'scaled rate': dict(rates=(0x3f000000, 0x3bc49ba6), multiplier=0x40800000), 'veneer': dict(veneer_to='l2d'), 'not a veneer': dict(veneer_to='not a veneer'),
                 'far offset': dict(offsets=(0x4416, 0xcc000000, 0xc4a74000)), 'eye field': dict(eye_field=0x90),
                 'look field': dict(look_field=0x68), 'rate field': dict(rate_field=0x12c)}
        cases.update({name: dict(omit=name) for name in (f.ANDROID_CURVE, f.ANDROID_RATES, f.ANDROID_RESET, c.ANDROID_ATTACH, f.ANDROID_UPDATE)})
        for name, options in cases.items():
            self.assertEqual(reader.extract_camera_follow(android(**options), {'camera': True}), {}, name)
