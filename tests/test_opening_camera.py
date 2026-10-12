"""Relocatable camera declarations and rejection of corrupted control context."""
import importlib.util
import struct
import unittest
from gof2_content import opening_camera as reader
from gof2_content.opening_staging import extract_opening_staging
from test_opening_staging import fixture as staging_fixture
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def camera_fixture(mac, relocation=0):
    m,old_blocks,_,old_helpers = staging_fixture(mac,relocation)
    base=m.text['address']; data=bytearray(110000)
    data[:len(m.data)]=m.data
    const=m.sections[1]
    data[100000:100000+const['length']]=m.data[const['offset']:const['offset']+const['length']]
    const['offset']=100000
    m.text['length']=50000
    prefix='MAC_' if mac else 'ARM_'
    names=['attach','cut','pan2','pan3','defaults','increment']+([] if mac else ['route3'])
    blocks={key:expand(getattr(reader,prefix+key.upper())) for key in names}
    at=base+22000; addresses={}
    for key in names:
        addresses[key]=at;at+=len(blocks[key][0])
        if key != 'cut' and (key != 'pan2' or not mac):at=(at+175)&~15
    helpers={**old_helpers,'mode':base+18000,'target':base+18128}
    for name,raw in {'mode':'554889e54088774d5dc3' if mac else '80f845107047','target':'554889e5488977085dc3' if mac else '41607047'}.items():
        off=256+helpers[name]-base; raw=bytes.fromhex(raw);data[off:off+len(raw)]=raw
    links={
      'attach':{'player':['16','27'],'target':['33']},
      'cut':{'finished':['7b'],'target':['9c'],'camera_components':['b9']},
      'pan2':{'increment':['24'],'finished':['38']},
      'pan3':{'increment':['33'],'finished':['47'],'player':['8a'],'mode':['a7'],'target':['b4']}
    } if mac else {
      'attach':{'player':['c','16'],'target':['1e']},
      'cut':{'finished':['82'],'target':['a2'],'camera_components':['c2']},
      'pan2':{'increment':['30'],'finished':['42']},
      'pan3':{'increment':['42'],'finished':['54'],'player':['9a'],'mode':['bc'],'target':['cc']}}
    jumps={
      'attach':{'1e':('attach',0x7c)},
      'cut':{'3':('pan3',0),'61':('cut',0x39),'6a':('cut',0xc9),'82':('cut',0xbe),'e8':('pan2',0)},
      'pan2':{'b6':('pan2',0x4f)},'pan3':{'3':('pan3',0xc8)}
    } if mac else {
      'attach':{'10':('attach',0x56)},
      'cut':{'6':('route3',0),'66':('cut',0x48),'6e':('cut',0xca),'88':('cut',0xc6),'f4':('pan2',0)},
      'pan2':{'b8':('pan2',0x64)},'route3':{'4':('pan3',0)}}
    def arm_jump(site,target,kind,reg='r0'):
        if kind in ['bl','b.w']:
            raw=bytearray(branch(site,target))
            if kind=='b.w': raw[3]&=~0x40
            return raw
        delta=target-site-4
        if kind in ['cbz','cbnz']:
            return struct.pack('<H',0xb100|(0x800 if kind=='cbnz' else 0)|((delta&0x40)<<3)|((delta&0x3e)<<2)|int(reg[1:]))
        if kind in ['bne','beq']:
            return struct.pack('<H',(0xd100 if kind=='bne' else 0xd000)|((delta//2)&255))
        if kind in ['bne.w','beq.w','bgt.w']:
            d=delta&0x1fffff;cond={'beq.w':0,'bne.w':1,'bgt.w':12}[kind]
            return struct.pack('<HH',0xf000|((d>>20)<<10)|(cond<<6)|((d>>12)&63),0x8000|(((d>>18)&1)<<13)|(((d>>19)&1)<<11)|((d>>1)&2047))
        raise ValueError(kind)
    def link(site,target,size,kind='bl',reg='r0'):
        return int(target-site-size).to_bytes(size,'little',signed=True) if mac else arm_jump(site,target,kind,reg)
    # Extend the already-validated parent staging dispatch to this cut block.
    patches=[(0,'call_75' if mac else 'call_52',helpers['mode']), (1,'jump_4e' if mac else 'jump_28',addresses['cut'])]
    if mac:patches.append((1,'jump_56',addresses['cut']))
    for index,key,target in patches:
        off,size=old_blocks[index][1][key];site=base+index*1024+off
        data[256+index*1024+off:256+index*1024+off+size]=link(site,target,size,'bl' if key.startswith('call') else 'bne.w')
    scalars={};const_next=100000+const['length']
    for key,(body,fields) in blocks.items():
        address=addresses[key]
        for field,(offset,size) in fields.items():
            site=address+offset
            meta=reader.ARM_FIELDS.get(prefix+key.upper(),{}).get(field,{})
            if field.startswith('call_'):
                helper=next((h for h,fields in links.get(key,{}).items() if field[5:] in fields),'other')
                target=addresses['increment'] if helper=='increment' else helpers[helper]
                raw=link(site,target,size)
            elif field.startswith('jump_'):
                to=jumps.get(key,{}).get(field[5:])
                target=addresses[to[0]]+to[1] if to else base+40000
                # Unused branch sites still need a valid bounded encoding.
                if not mac and meta['kind'] in ['cbnz','cbz'] and not to:target=site+16
                raw=link(site,target,size,meta.get('kind','bl'),meta.get('register','r0'))
            elif field.startswith('ref_') or field.startswith('literal_'):
                value=1.0
                if key=='cut' and field in ['ref_a9','ref_a1']:value=-123.0 if field=='ref_a9' else 192.0
                if key in ['pan2','pan3']:
                    value=.75 if field in ['ref_c','ref_1b','literal_6'] or (key=='pan3' and field=='literal_c') else -1.25
                if mac:
                    dest=base+0x10000+(const_next-100000);scalars[(key,field)]=const_next
                    struct.pack_into('<f',data,const_next,value);const_next+=4
                    raw=link(site,dest,4)
                else:
                    # Keep each VFP literal pool after its declaration block.
                    reg=int(meta['register'][1:])
                    dest=addresses[key]+len(body)+64+(4 if field in ['literal_c','literal_14'] else 0)
                    if key=='pan3' and field=='literal_c':dest=addresses[key]+len(body)+64
                    dest=(dest+3)&~3;delta=dest-((site+4)&~3)
                    assert 0<=delta<=1020
                    file=256+dest-base;scalars[(key,field)]=file;struct.pack_into('<f',data,file,value)
                    raw=struct.pack('<HH',0xed9f|((reg&1)<<6),((reg//2)<<12)|0xa00|(delta//4))
            elif field.startswith('word_'):
                value=1
                if key=='cut':
                    bits=struct.unpack('<I',struct.pack('<f',-123.0))[0]
                    value={'word_a6':bits&65535,'word_b4':bits>>16,'word_b8':0x4340}.get(field,1)
                raw=arm_wide(value, int(meta['register'][1:]) if meta['register'].startswith('r') else {'sl':10,'fp':11}[meta['register']],meta['kind']=='movt')
            else:raise ValueError(field)
            assert len(raw)==size
            body[offset:offset+size]=raw
        off=256+address-base;data[off:off+len(body)]=body
    const['length']=const_next-100000
    m.data=bytes(data)
    return m,blocks,addresses,scalars,helpers


@unittest.skipUnless(importlib.util.find_spec('capstone'),'optional static-reader dependency')
class OpeningCamera(unittest.TestCase):
    def test_changed_relocated_declarations(self):
        for mac in [True,False]:
            for relocation in [0,0x60000]:
                with self.subTest(mac=mac,relocation=relocation):
                    m,*_=camera_fixture(mac,relocation)
                    staging=extract_opening_staging(m);self.assertTrue(staging)
                    result=reader.extract_opening_camera(m,staging)
                    self.assertTrue(result)
                    self.assertEqual(result['actor_cut'],{'after_event_finished':6,'actor_id':0,'eye':[-123,192,-123]})
                    self.assertEqual(result['pan']['velocity_per_ms'],[.75,0,-1.25])
                    self.assertTrue(result['initial_fixed_eye'])

    def test_corrupted_context_and_scalars_rejected(self):
        for mac in [True,False]:
            for bad in ['missing_staging','mode','target','gate','nan','different_pan','cut_link','duplicate','unbacked_call','defaults','truncated'] + ([] if mac else ['register']):
                with self.subTest(mac=mac,bad=bad):
                    m,blocks,addresses,scalars,helpers=camera_fixture(mac)
                    data=bytearray(m.data)
                    def file(key,field=None):
                        return 256+addresses[key]-m.text['address']+(blocks[key][1][field][0] if field else 0)
                    if bad in ['mode','target']:data[256+helpers[bad]-m.text['address']]^=1
                    elif bad=='gate':data[file('pan2')+(0x37 if mac else 0x3c)]^=1
                    elif bad in ['nan','different_pan']:
                        pair=[('pan2','ref_c' if mac else 'literal_6'),('pan3','ref_1b' if mac else 'literal_c')]
                        for key in pair if bad=='nan' else pair[:1]:struct.pack_into('<f',data,scalars[key],float('nan') if bad=='nan' else 4.0)
                    elif bad=='cut_link':data[file('cut','jump_3' if mac else 'jump_6')]^=2
                    elif bad=='duplicate':
                        body=blocks['defaults'][0];data[256+42000:256+42000+len(body)]=body
                    elif bad=='unbacked_call':
                        field='call_1b2' if mac else 'call_d6';off,size=blocks['defaults'][1][field]
                        raw=struct.pack('<i',0x70000000) if mac else branch(addresses['defaults']+off,m.text['address']+0x100000)
                        data[file('defaults',field):file('defaults',field)+size]=raw
                    elif bad=='defaults':data[file('defaults')+(0x34a if mac else 0x18a)]^=1
                    elif bad=='register':
                        off=file('cut','word_a6');data[off:off+4]=arm_wide(0,2,False)
                    elif bad=='truncated':data=data[:file('defaults')+len(blocks['defaults'][0])-1]
                    m.data=bytes(data)
                    staging={} if bad=='missing_staging' else extract_opening_staging(m)
                    self.assertEqual(reader.extract_opening_camera(m,staging),{})

if __name__=='__main__':unittest.main()



CAMERA_CALLEES = ['_ZN6Layout13getPulseValueEf', '_ZN10AEGeometry9translateEfff', '_ZN18TargetFollowCamera9setTargetEP10AEGeometry',
                  '_ZN9FModSound9isPlayingEi', '_ZN9FModSound4stopEi', '_ZN9FModSound4playEiPN11AbyssEngine6AEMath6VectorES3_f',
                  '_ZN18TargetFollowCamera9translateEfff', '_ZN13PlayerFighter17setExhaustVisibleEb']


def android(eye=(-4000.0, 200.0), velocity=((0.25, 2.5), (0.25, 2.5)), events=(0x18, 0x1c, 0x20), cut_phase=2, exits_agree=True,
            mode_field=0x45, up_default=True, zeros=1, attach_call='_ZN18TargetFollowCamera9setTargetEP10AEGeometry', cut_actor=0,
            zero_value=0, pool_at=None, frequency=0x3a03126f, bias=-0.5, extra=(), omit=None, **staging_options):
    """LevelScript::process's opening phases after the staging formation, and the camera's helpers. Returns the library."""
    from android_fixture import TEXT, Thumb
    from gof2_content import opening_camera as c
    from test_opening_staging import STAGING_CALLEES, android as staging, halves
    from test_steering import (adds8, add_pc, assemble, b_to, blx_reg, cbz, cmp_imm, ldr_lit, ldr_reg, ldr_w, strb_w, sub_sp, vadd,
                               vldr_pc, vmov_from_core, vmov_imm)
    at = {name: TEXT + 0x1400 + 0x40 * i for i, name in enumerate(CAMERA_CALLEES)}
    stubs = dict(at)
    at.update({name: address for name, _, address in extra})
    staged = {name: TEXT + 0x40 * i for i, name in enumerate(STAGING_CALLEES)}

    def pan(asm, L, which):
        pool = pool_at if pool_at and not which else L.get('pool', asm.here() + 8)
        vldr_pc(vmov_from_core(asm, 0, 9), 2, pool + 8 * which)
        return ldr_w(vldr_pc(asm, 4, pool + 8 * which + 4).movs(2, 0).vcvt(0, 0), 0, 10, 0x14)

    def tail(asm, L, call):
        def to(name): return L.get(name, asm.here() + 4)
        def calls(asm, name): return asm.call(at[name])
        def pan_tail(asm): return calls(asm.vmul(2, 0, 2).vmul(0, 0, 4).vmov_core(1, 2).vmov_core(3, 0), '_ZN18TargetFollowCamera9translateEfff')
        b_to(cmp_imm(asm, 1, cut_phase), to('pan'), 'gt', True)
        ldr_w(asm, 0, 15, 0x40).movw(1, frequency & 0xffff).movt(1, frequency >> 16)
        calls(add_pc(asm, 0).ldr(0, 0, 0).ldr(0, 0, 0), '_ZN6Layout13getPulseValueEf')
        vadd(vmov_from_core(vmov_imm(asm, 0, bias).movs(5, 0), 2, 0), 0, 2, 0).vmov_core(4, 0).label('drift')
        ldr_reg(ldr_w(asm, 0, 11, 4).movs(1, 0).mov(2, 4).movs(3, 0), 0, 0, 5, 2).ldr(0, 0, 8)
        b_to(cmp_imm(adds8(calls(asm, '_ZN10AEGeometry9translateEfff'), 5, 1), 5, 3), to('drift'), 'ne')
        b_to(cmp_imm(ldr_w(asm, 0, 10, 0x1c), 0, 1), to('phase2'), 'ne')
        b_to(cmp_imm(call(asm.ldr(0, 6, 4).ldr(0, 0, events[0]), '_ZN12RadioMessage6isOverEv'), 0, 1), to('reload'), 'ne')
        ldr_w(asm.movs(0, 2).str_w(0, 10, 0x1c), 0, 11, 4).ldr(1, 0, 4 * cut_actor)
        calls(ldr_w(asm, 0, 10, 0x14).ldr(1, 1, 8), '_ZN18TargetFollowCamera9setTargetEP10AEGeometry')
        (xl, xh), (yl, yh) = halves(eye[0]), halves(eye[1])
        ldr_w(asm.movw(1, xl), 0, 10, 0x14).movs(2, yl).movt(1, xh).movt(2, yh).mov(3, 1)
        call(asm, '_ZN18TargetFollowCamera11setPositionEfff').label('reload')
        ldr_w(asm, 0, 10, 0x1c).label('phase2')
        b_to(cmp_imm(asm, 0, 2), to('exit'), 'ne', True)
        calls(add_pc(ldr_w(asm, 0, 15, 0x40).movs(1, 0x8e), 0).ldr(0, 0, 0).ldr(0, 0, 0), '_ZN9FModSound9isPlayingEi')
        add_pc(ldr_w(cbz(asm, 0, to('music'), True), 0, 15, 0x40), 0).ldr(4, 0, 0).ldr(0, 4, 0).ldr(1, 0, 0)
        calls(calls(asm, '_ZN9FModSound4stopEi').ldr(0, 4, 0).movs(1, 0).str_sp(1, 0).movs(1, 0x8e).movs(2, 0).movs(3, 0),
              '_ZN9FModSound4playEiPN11AbyssEngine6AEMath6VectorES3_f').label('music')
        pan_tail(pan(asm, L, 0))
        b_to(cmp_imm(call(asm.ldr_sp(0, 0x40).ldr(0, 0, 4).ldr(0, 0, events[1]), '_ZN12RadioMessage6isOverEv'), 0, 1), to('exit'), 'ne', True)
        ldr_w(asm.movs(0, 3).movs(4, 0).str_w(0, 10, 0x1c).movs(5, 1), 0, 11, 4).movw(6, 0xc350).label('engage')
        calls(ldr_reg(asm, 0, 0, 4, 2).movs(1, 1), '_ZN13PlayerFighter17setExhaustVisibleEb')
        call(ldr_reg(ldr_w(asm, 0, 11, 4).movs(1, 1), 0, 0, 4, 2).ldr(0, 0, 8), '_ZN10AEGeometry10setVisibleEb')
        blx_reg(ldr_reg(ldr_w(asm, 0, 11, 4), 0, 0, 4, 2).ldr(1, 0, 0).ldr(1, 1, 0xc), 1)
        ldr_reg(ldr_w(asm, 0, 11, 4), 1, 0, 4, 2)
        strb_w(cmp_imm(adds8(asm, 4, 1), 4, 3).str_w(6, 1, 0x124).ldr(1, 1, 4), 5, 1, 0x5c)
        b_to(b_to(asm, to('engage'), 'ne'), to('exit')).label('pan')
        b_to(cmp_imm(b_to(cmp_imm(asm, 1, 4), to('exit'), 'eq', True), 1, 3), to('exit'), 'ne', True)
        pan_tail(pan(asm, L, 1).movs(4, 0))
        b_to(cmp_imm(call(asm.ldr(0, 6, 4).ldr(0, 0, events[2]), '_ZN12RadioMessage6isOverEv'), 0, 1), to('exit'), 'ne', True)
        call(asm.movs(0, 4).strd(4, 4, 10, 0x90).str_w(0, 10, 0x1c).movs(1, 0).ldr_sp(6, 0x44).mov(0, 6), '_ZN9PlayerEgo21setComputerControlledEb')
        strb_w(ldr_w(strb_w(asm.ldr(0, 6, 0).movs(5, 1), 4, 0, 0x5e), 0, 10, 0xd4), 5, 0, 0x48)
        call(call(ldr_w(asm, 0, 10, 0x18), '_ZN5Level9getPlayerEv').movs(1, 1), '_ZN9PlayerEgo10setCollideEb')
        call(ldr_w(strb_w(asm, 4, 10, 0x11).movs(1, 0), 0, 10, 0x14), '_ZN18TargetFollowCamera12setLookAtCamEb')
        calls(ldr_w(asm.ldr(1, 6, 8), 0, 10, 0x14), '_ZN18TargetFollowCamera9setTargetEP10AEGeometry')
        b_to(strb_w(strb_w(asm, 5, 10, 0x12), 4, 10, 0x20), to('exit' if exits_agree else 'pan'), None, True).label('exit').pop()
        if asm.here() % 4:
            asm.nop()
        asm.label('pool').data(*(struct.unpack('<I', struct.pack('<f', v))[0] for pair in velocity for v in pair))

    def attach(asm, L):
        sub_sp(asm.push().add_sp(7, 0xc), 0x14).mov(4, 0)
        ldr_lit(asm, 0, 0x40).mov(5, 1)
        add_pc(asm, 0).ldr(0, 0, 0).ldr(0, 0, 0).str_sp(0, 0x10).mov(0, 5).call(staged['_ZN5Level9getPlayerEv'])
        cbz(asm, 0, L.get('end', asm.here() + 4)).mov(0, 5).ldr(6, 4, 0x14).call(staged['_ZN5Level9getPlayerEv'])
        asm.ldr(1, 0, 8).mov(0, 6).call(at.get(attach_call) or staged[attach_call])
        for _ in range(18):
            asm.nop()
        asm.label('end').pop()

    def camera(asm, L):
        asm.push()
        for _ in range(zeros):
            asm.mov_imm(9, zero_value)
        asm.nop().movs(0, 1)
        for field, register in ((0x44, 9), (0x47, 9), (0x45, 9)):
            strb_w(asm, register, 11, field)
        strb_w(asm.str_w(9, 11, 0x48), 0, 11, 0x46)
        for field in (0x4c, 0xf0, 0x100):
            strb_w(asm, 9, 11, field)
        strb_w(asm, 0 if up_default else 9, 11, 0x10c).pop()
    functions = [(name, Thumb(address).ret().finish(), address) for name, address in stubs.items() if name not in at or at[name] == address]
    functions += list(extra) + [(c.ANDROID_ATTACH, assemble(TEXT + 0x1700, attach).finish(), TEXT + 0x1700),
                  (c.ANDROID_MODE, strb_w(Thumb(TEXT + 0x1780), 1, 0, mode_field).ret().finish(), TEXT + 0x1780),
                  (c.ANDROID_CAMERA, assemble(TEXT + 0x1800, camera).finish(), TEXT + 0x1800)]
    lib, _ = staging(tail=tail, extra=[f for f in functions if f[0] != omit], omit=omit, **staging_options)
    return lib


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidOpeningCamera(unittest.TestCase):
    def test_named_phases_give_cut_and_pan(self):
        lib = android()
        result = reader.extract_opening_camera(lib, extract_opening_staging(lib))
        provenance = result.pop('provenance')
        self.assertEqual(result, {'initial_target': 'player', 'initial_fixed_eye': True, 'inherit_target_up': True,
                                  'actor_cut': {'after_event_finished': 6, 'actor_id': 0, 'eye': [-4000.0, 200.0, -4000.0]},
                                  'pan': {'velocity_per_ms': [0.25, 0.0, 2.5], 'engagement_after_event_finished': 7,
                                          'follow_player_after_event_finished': 8}})
        self.assertEqual({k: v['bytes'] for k, v in provenance.items()},
                         {'cut': 340, 'pan3': 156, 'attach': 44, 'mode_setter': 6, 'defaults': 38, 'defaults_zero': 4,
                          'velocity_cut_x': 4, 'velocity_cut_z': 4, 'velocity_pan3_x': 4, 'velocity_pan3_z': 4})
        self.assertEqual(reader.extract_opening_camera(lib, {}), {})

    def test_each_broken_declaration_is_unsupported(self):
        from android_fixture import TEXT
        from gof2_content import opening_camera as c
        cases = {'eye': dict(eye=(float('nan'), 200.0)), 'velocity disagrees': dict(velocity=((0.25, 2.5), (0.25, 2.0))),
                 'far velocity': dict(velocity=((0.25, 2e7), (0.25, 2e7))), 'event': dict(events=(0x14, 0x1c, 0x20)),
                 'cut phase': dict(cut_phase=3), 'pan event': dict(events=(0x18, 0x1c, 0x24)), 'zero value': dict(zero_value=1),
                 'pool outside': dict(pool_at=TEXT + 0xbf8), 'exits': dict(exits_agree=False), 'mode field': dict(mode_field=0x44),
                 'up default': dict(up_default=False), 'zero twice': dict(zeros=2), 'zero missing': dict(zeros=0),
                 'attach call': dict(attach_call='_ZN9PlayerEgo10setCollideEb'), 'cut actor': dict(cut_actor=1),
                 'formation': dict(message=0xc), 'dispatch': dict(dispatches=(1, 2))}
        cases.update({name: dict(omit=name) for name in (c.ANDROID_ATTACH, c.ANDROID_MODE, c.ANDROID_CAMERA, '_ZN11LevelScript7processEi')})
        for name, options in cases.items():
            self.assertEqual(reader.extract_opening_camera(android(**options), {'staged': True}), {}, name)
