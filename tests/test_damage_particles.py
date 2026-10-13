"""Relocated, changed synthetic sprite declarations; no original content."""
import copy
import importlib.util
import struct
import unittest
from types import SimpleNamespace
from gof2_content import damage_particles as reader
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch

def fbits(value):return struct.unpack('<I',struct.pack('<f',value))[0]

def immediate(kind,reg,value):
    value&=0xffffffff
    if kind=='vmov.i32':
        assert value==0
        return bytes.fromhex('80ef10a0' if reg==10 else '80ef5080')
    if kind=='movs':
        assert reg<8 and value<256
        return struct.pack('<H',0x2000|(reg<<8)|value)
    if kind in ['movw','movt']:return arm_wide(value,reg,kind=='movt')
    assert kind in ['mov.w','mvn']
    wanted=(~value)&0xffffffff if kind=='mvn' else value
    for code in range(4096):
        byte=code&255
        if code>>10==0:
            value=[byte,(byte<<16)|byte,(byte<<24)|(byte<<8),byte*0x1010101][(code>>8)&3]
        else:
            byte=128|(code&127);shift=(code>>7)&31
            value=((byte>>shift)|(byte<<(32-shift)))&0xffffffff
        if value==wanted:
            return struct.pack('<HH',(0xf06f if kind=='mvn' else 0xf04f)|((code>>11)<<10),((code>>8&7)<<12)|(reg<<8)|(code&255))
    raise AssertionError((kind,reg,hex(wanted)))

def words(preset):
    fire=preset==42
    return {0x10:0x2000021,0x14:9 if fire else 18,0x18:fbits(256 if fire else 128),
        0x1c:100 if fire else 120,0x2c:768 if fire else 777,0x30:fbits(8),
        0x34:1,0x38:0xffffff70 if fire else 0xffffffff,0x3c:0xffffffcc,
        0x40:64 if fire else 60,0x48:120 if fire else 1000,
        0x4c:64 if fire else 60,0x50:64 if fire else 60,0x54:0,
        0x68:fbits(-8),0x74:0,0x80:0,0x84:fbits(64 if fire else -32),
        0x88:fbits(64 if fire else 128),0x8c:0,0x90:0,
        0x94:fbits(0.5),0x98:fbits(0.5),0xa0:4}

def fixture(mac,shift=0):
    base=0x100000+shift;offset=128;data=bytearray(offset+4096)
    blocks={};locations={'presets':64,'smoke_material':1100,'fire_material':1300,'defaults':1600}
    prefix='MAC_' if mac else 'ARM_'
    for key,at in locations.items():
        name=prefix+key.upper();body,fields=expand(getattr(reader,name));values={}
        for destination,expression in reader.DATA_FIELDS.get(name,{}).items():
            preset,field=map(int,destination.split(':'));value=words(preset)[field]
            for index,hole in enumerate(expression):
                part=value if len(expression)==1 else (value>>16 if index else value&65535)
                assert hole not in values or values[hole]==part
                values[hole]=part
        for field,(where,size) in fields.items():
            if field=='material':value=410 if key=='smoke_material' else 420
            elif field in values:value=values[field]
            else:value=0
            if mac:
                raw=struct.pack('<i',3600-at-where-size) if field.startswith(('call','ref')) else struct.pack('<I',value)
            else:
                if field not in reader.ARM_FIELDS[name]:raw=bytes(size)
                else:
                    kind,register=reader.ARM_FIELDS[name][field]
                    if kind=='bl':raw=branch(base+at+where,base+3600)
                    else:raw=immediate(kind,int(register[1:]),value)
            assert len(raw)==size
            body[where:where+size]=raw
        data[offset+at:offset+at+len(body)]=body;blocks[key]=(at,body,fields)
    section={'name':b'__text','segment':b'__TEXT','address':base,'offset':offset,'length':4096}
    return SimpleNamespace(architecture='x86_64' if mac else 'armv7',data=bytes(data),slice_offset=8192,text=section,sections=[section]),blocks

class DamageParticles(unittest.TestCase):
    def test_changed_data_and_relocation(self):
        for mac in [True,False]:
            for shift in [0,0x360000]:
                m,_=fixture(mac,shift);data=reader.extract_damage_particles(m)
                self.assertTrue(data,(mac,shift))
                self.assertEqual(data['scope'],'damage_particle_sprite_presets')
                for index,row in enumerate(data['presets']):
                    preset=[15,42][index];values=words(preset)
                    self.assertEqual(row['material_id'],[410,420][index])
                    for field,key in reader.INTEGER_FIELDS.items():self.assertEqual(row[key],values[field])
                    for field,key in reader.FLOAT_FIELDS.items():self.assertEqual(row[key],struct.unpack('<f',struct.pack('<I',values[field]))[0])
                    self.assertEqual(row['uv_rect'],[0,0,0.5,0.5])
                    self.assertEqual(row['end_rgba'],[255,255,255,204])
                self.assertEqual(set(data['provenance']),{'presets','smoke_material','fire_material','defaults'})
                self.assertEqual(data['emitter_defaults'],{'auxiliary_sizes':[0,0], 'velocity_size_factor':0,
                    'initial_fade_ms':0, 'velocity_base':[0,0,0], 'local_velocity_xy':[0,0],
                    'local_offset_x':0, 'minimum_squared_speed':0})
                for row in data['provenance'].values():self.assertEqual(set(row),{'offset','bytes'})

    def test_malformed_and_ambiguous_declarations(self):
        for mac in [True,False]:
            for problem in ['presets','smoke_material','fire_material','defaults','duplicate','truncate','link','material','architecture']:
                with self.subTest(mac=mac,problem=problem):
                    m,blocks=fixture(mac);data=bytearray(m.data)
                    if problem in blocks:data[128+blocks[problem][0]]^=255
                    elif problem=='duplicate':
                        body=blocks['presets'][1];data[128+2200:128+2200+len(body)]=body
                    elif problem=='truncate':m.text['length']=1320
                    elif problem=='architecture':m.architecture='unknown'
                    else:
                        at,_,fields=blocks['fire_material'];field='material' if problem=='material' else 'call_1d' if mac else 'call_12';where,size=fields[field]
                        if mac:raw=struct.pack('<I',410) if problem=='material' else struct.pack('<i',10)
                        else:raw=arm_wide(410,3) if problem=='material' else branch(m.text['address']+at+where,m.text['address']+3604)
                        data[128+at+where:128+at+where+size]=raw
                    m.data=bytes(data);self.assertEqual(reader.extract_damage_particles(m),{})

    def test_parameter_boundaries(self):
        row=reader.extract_damage_particles(fixture(True)[0])['presets'][0]
        for key,value in [('capacity',0),('lifetime_ms',0),('emission_per_second',0),('size',float('nan')),('flags',0),('animation_frames',5),('fade_in_ms',778),('size_jitter',32767),('uv_rect',[0,0,0,0.5])]:
            bad=copy.deepcopy(row);bad[key]=value
            self.assertFalse(reader.parameters(bad),key)

    def test_invalid_literal_values_do_not_create_a_capability(self):
        for mac in [True,False]:
            for field,value in [(0x10,0),(0x14,0),(0x2c,0),(0x18,0x7fc00000),(0x30,0),(0x94,fbits(2))]:
                with self.subTest(mac=mac,field=field):
                    m,blocks=fixture(mac);at,_,holes=blocks['presets'];data=bytearray(m.data)
                    name=('MAC_' if mac else 'ARM_')+'PRESETS'
                    expression=reader.DATA_FIELDS[name]['15:'+str(field)]
                    for index,hole in enumerate(expression):
                        where,size=holes[hole]
                        part=value if len(expression)==1 else (value>>16 if index else value&65535)
                        if mac:raw=struct.pack('<I',part)
                        else:
                            kind,register=reader.ARM_FIELDS[name][hole]
                            raw=immediate(kind,int(register[1:]),part)
                        data[128+at+where:128+at+where+size]=raw
                    m.data=bytes(data)
                    self.assertEqual(reader.extract_damage_particles(m),{})

    def test_changed_or_duplicate_defaults_are_unsupported(self):
        for mac in [True,False]:
            for duplicate in [True,False]:
                m,blocks=fixture(mac);data=bytearray(m.data);at,body,holes=blocks['defaults']
                if duplicate:data[128+3050:128+3050+len(body)]=body
                else:
                    where,size=holes['v_44' if mac else 'scalar_defaults']
                    data[128+at+where:128+at+where+size]=struct.pack('<I',1) if mac else immediate('movs',1,1)
                m.data=bytes(data)
                self.assertEqual(reader.extract_damage_particles(m),{})


NAME, CTOR, DTOR = '_ZN11AbyssEngine6StringaSERKS0_', '_ZN11AbyssEngine6StringC1EPKcb', '_ZN11AbyssEngine6StringD1Ev'
POOL = 0x1000  # four uv words in .text, between the two functions


def vmov_i32(asm, q, imm): return asm.half(0xef80 | (2 * q >> 4) << 6, (2 * q & 15) << 12 | 0x50 | imm)  # vmov.i32 qN, #imm (< 16)


def vld1_64(asm, d, rn): return asm.half(0xf920 | (d >> 4) << 6 | rn, (d & 15) << 12 | 0xaef)  # vld1.64 {dN, dN+1}, [rn:0x80]


def vst1_32(asm, d, rn): return asm.half(0xf900 | (d >> 4) << 6 | rn, (d & 15) << 12 | 0xa8f)  # vst1.32 {dN, dN+1}, [rn]


def adr(asm, rd, imm): return asm.half(0xa000 | rd << 8 | imm // 4)  # adr rd, #imm


def str_index(asm, rt, rn, rm): return asm.half(0xf840 | rn, rt << 12 | rm)  # str.w rt, [rn, rm]


def strd_neg(asm, rt, rt2, rn, offset): return asm.half(0xe940 | rn, rt << 12 | rt2 << 8 | offset // 4)


def load(asm, rd, value):
    """The shortest constant load the compiler would use: movs, mov.w, mvn or movw/movt."""
    value &= 0xffffffff
    if rd < 8 and value < 256:
        return asm.movs(rd, value)
    for kind in ('mov.w', 'mvn'):
        try:
            asm.code += immediate(kind, rd, value)
            return asm
        except AssertionError:
            pass
    asm.movw(rd, value & 0xffff)
    return asm.movt(rd, value >> 16) if value >> 16 else asm


def android(**changes):
    """ParticleSettings::init (defaults loop, sets 15 and 42) and Level::init (managers) in the Android shapes."""
    from android_fixture import RODATA, TEXT
    from android_thumb import Asm, build
    o = SimpleNamespace(early_name=True, r0_written=False, preambles=1, loops=1, vector=0, scalar=0, entry='loop', back='loop',
                        count=0x30, stride=0x9c, d=8, fp_moved=False, entry_jump=False, clobber=False, overlap=False,
                        missing=False, twice=False, foreign=False, strb=False, loaded=False, high=False, pool_base=15, vector_last=False,
                        rename=False, end=True, level_r0=False, level_this=0, camera=1, none=0xffff, rewrite=False,
                        wide_stack=False, args_early=False, arg_target=False, fields=(0x78, 0x84, 0x74), ids=(410, 420),
                        frames=4)
    o.__dict__.update(changes)
    stride = o.stride
    asm = Asm(TEXT + 0x100).push()
    if o.early_name:
        asm.call_to(NAME)  # r0 holds nothing known: not a set's name
    if o.r0_written:
        asm.movs(0, 0)
    marks = {'preamble': asm.here()}

    def preamble(target):
        asm.mov(11, 0).ldr_address(0, RODATA)
        vmov_i32(asm, 5, o.vector)
        asm.movw(10, 0).add_pc(0).add_imm(5, 11, 0x8c).add_sp(6, 0x24).movs(4, o.scalar).ldr(0, 0, 0)
        asm.mov_imm(9, 0x1f4).movt(10, 0x427c).mov_imm(8, 0).ldr(0, 0, 0).str_sp(0, 0x2c)
        adr(asm, 0, 0x18)
        vld1_64(asm, 8, 0)
        asm.branch(None, target)
    preamble(o.entry)

    def loop(name):
        asm.label(name).ldr_address(1, RODATA + 0x10).mov(0, 6).movs(2, 0).add_pc(1).call_to(CTOR)
        asm.sub_imm(0, 5, 0x8c).mov(1, 6).call_to(NAME).mov(0, 6).call_to(DTOR)
        asm.movs(0, 0x10).movs(1, 0x48).str_neg(0, 5, 0x84).movs(0, 1).str_neg(0, 5, 0x80)
        asm.movs(0, 0).movt(0, 0x42c8).str_neg(0, 5, 0x7c).sub_imm(0, 5, 0x78)
        vst1_32(asm, 10, 0)
        asm.movs(0, 0x64).str_neg(0, 5, 0x68).movs(0, 0).movt(0, 0x43fa).str_neg(0, 5, 0x64).sub_imm(0, 5, 0x60)
        vst1_32(asm, 8, 0)
        asm.sub_imm(0, 5, 0x48)
        strd_neg(asm, 4, 9, 5, 0x50)
        asm.call_to('__aeabi_memclr4').strd(10, 10, 5, 0).add_imm(8, 8, 1).strd(4, 4, 5, 8)
        asm.adds8(5, stride).cmp(8, o.count).branch('lt', o.back if name == 'loop' else name)
    asm.label('early').nop()
    loop('loop')
    marks['defaults'] = asm.here()
    values = {preset: words(preset) for preset in (15, 42)}
    values[15][0xa0] = values[42][0xa0] = o.frames
    # The set before these leaves set 15's lifetime in r8 and a zero in r6.
    marks['presets'] = asm.here()
    asm.movw(8, values[15][0x2c]).movs(6, 0)
    asm.addw(0, o.pool_base, TEXT + POOL - (asm.here() + 4 & ~3))
    vld1_64(asm, o.d, 0)
    if o.high:
        asm.vldr_pc(o.d + 1, 0, double=True)
    base = 15 * stride
    asm.addw(4, 11, base).mov(0, 4).mov(1, 5).call_to(NAME)
    fields = [m for m in sorted(values[15]) if m not in (0x2c, 0x34, 0x54, 0x74, 0x80, 0x8c, 0x90, 0x94, 0x98)]
    for m in fields + [0x10] * o.twice:
        if o.missing and m == 0x50:
            continue
        if o.overlap and m == 0x48:
            values[15][m] = 0x1f4
            asm.str_w(9, 11, base + m - 8)  # sb: the defaults loop's 500
            continue
        load(asm, 0, values[15][m]) if not (o.loaded and m == 0x14) else asm.ldr_sp(0, 4)
        asm.str_w(0, 11, base + m - 8)
    for m in (0x54, 0x74, 0x80):
        asm.str_w(6, 11, base + m - 8)
    asm.movs(6, 1).str_w(6, 11, base + 0x34 - 8).label('inside').str_w(8, 11, base + 0x2c - 8)
    asm.addw(0, 11, base + 0x8c - 8)
    vst1_32(asm, o.d, 0)
    if o.foreign:
        asm.call_to('_Z3foov')
    if o.strb:
        asm.strb_w(0, 11, base + 0x10 - 8)
    base = 42 * stride
    asm.movw(0, base).add_low(0, 11).mov(1, 5).call_to(NAME)

    def vector():
        asm.movw(0, base + 0x8c - 8).add_low(0, 11)
        vst1_32(asm, o.d, 0)

    def stores():
        for m in sorted(values[42]):
            if m not in (0x8c, 0x90, 0x94, 0x98):
                load(asm, 1, values[42][m])
                if o.clobber and m == 0x10:
                    asm.call_to(DTOR)
                load(asm, 0, base + m - 8)
                str_index(asm, 1, 11, 0)
    first, second = (stores, vector) if o.vector_last else (vector, stores)
    first()
    if o.fp_moved:
        asm.mov(11, 2)  # fp no longer holds the object
    second()
    marks['end'] = asm.here()
    if o.end:
        asm.ldr_sp(0, 4).mov(1, 5).call_to(NAME)
    if o.rename:
        asm.addw(0, 11, 15 * stride).call_to(NAME)
    asm.pop()
    if o.entry_jump:
        asm.branch(None, 'inside')
    if o.loops == 2:
        loop('again')
    if o.preambles == 2:
        preamble('dead')
        asm.label('dead').nop()

    level = Asm(TEXT + 0x1400).push()
    if o.level_r0:
        level.movs(0, 1)
    level.mov(4, o.level_this)
    manager = '_ZN21ParticleSystemManagerC1EPN11AbyssEngine11PaintCanvasEN16ParticleSettings9CameraSetEtbtb'
    level.movs(0, 0x64).call_to('_Znwj').mov(5, 0).movw(8, o.none).movs(0, 0)
    marks['smoke'] = level.here()
    level.str_sp(0, 8).movs(2, o.camera).strd(0, 8, 13, 0).movw(3, o.ids[0]).mov(0, 5).call_to(manager).str(5, 4, o.fields[0])
    marks['smoke_end'] = level.here()
    level.movs(6, 0).cbz(0, 'skip', nonzero=True).mov_imm(9, 0).label('skip')
    if o.args_early:
        level.strd(6, 8, 13, 0).str_sp(6, 8)
    level.movs(0, 0x64).call_to('_Znwj').mov(5, 0)
    if o.arg_target:
        level.cbz(5, 'arguments')
    marks['fire'] = level.here()
    if not o.args_early:
        level.strd(6, 8, 13, 0).str_sp(6, 8)
        if o.wide_stack:
            level.str_sp_w(6, 8)  # a store the reader does not follow
    level.label('arguments').mov(0, 5).movs(2, 1).movw(3, o.ids[1]).movs(6, 1).call_to(manager).movs(0, 0x64)
    if o.rewrite:
        level.mov(5, 1)
    level.str_w(5, 4, o.fields[1])
    marks['fire_end'] = level.here()
    level.movs(0, 0x64).call_to('_Znwj').mov(5, 0).movs(2, 1).movw(3, 999).strd(6, 8, 13, 0).str_sp(6, 8).mov(0, 5)
    level.call_to(manager).str_w(5, 4, o.fields[2]).pop()
    pool = Asm(TEXT + POOL).data(*(values[15][m] for m in (0x8c, 0x90, 0x94, 0x98)))
    functions = {reader.ANDROID_INIT: asm, reader.ANDROID_LEVEL: level, '_pool': pool}
    return build(functions), marks, values


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class AndroidDamageParticles(unittest.TestCase):
    def test_encodings_decode_as_intended(self):
        import capstone
        from android_fixture import TEXT
        from android_thumb import Asm
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        asm = Asm(TEXT)
        cases = [(lambda: vmov_i32(asm, 5, 0), 'vmov.i32 q5, #0'), (lambda: vmov_i32(asm, 5, 1), 'vmov.i32 q5, #1'),
                 (lambda: vld1_64(asm, 8, 0), 'vld1.64 {d8, d9}, [r0:0x80]'), (lambda: vld1_64(asm, 16, 0), 'vld1.64 {d16, d17}, [r0:0x80]'),
                 (lambda: vst1_32(asm, 10, 0), 'vst1.32 {d10, d11}, [r0]'), (lambda: vst1_32(asm, 16, 3), 'vst1.32 {d16, d17}, [r3]'),
                 (lambda: adr(asm, 0, 0x18), 'adr r0, #0x18'), (lambda: str_index(asm, 1, 11, 0), 'str.w r1, [fp, r0]'),
                 (lambda: strd_neg(asm, 4, 9, 5, 0x50), 'strd r4, sb, [r5, #-0x50]'), (lambda: asm.addw(0, 15, 0x998), 'addw r0, pc, #0x998'),
                 (lambda: load(asm, 0, 0xffffff00), 'mvn r0, #0xff'), (lambda: load(asm, 0, 0xc0000000), 'mov.w r0, #-0x40000000')]
        for emit, expected in cases:
            start = len(asm.code)
            emit()
            decoded = list(decoder.disasm(bytes(asm.code[start:]), TEXT + start))
            self.assertEqual(['%s %s' % (i.mnemonic, i.op_str) for i in decoded], [expected])

    def test_sets_defaults_and_managers(self):
        lib, marks, values = android()
        data = reader.extract_damage_particles(lib)
        self.assertEqual(data['scope'], 'damage_particle_sprite_presets')
        for index, row in enumerate(data['presets']):
            preset = [15, 42][index]
            self.assertEqual((row['preset_id'], row['material_id']), (preset, [410, 420][index]))
            for field, key in reader.INTEGER_FIELDS.items():
                self.assertEqual(row[key], struct.unpack('<i', struct.pack('<I', values[preset][field]))[0] if key != 'flags' else values[preset][field])
            for field, key in reader.FLOAT_FIELDS.items():
                self.assertEqual(row[key], struct.unpack('<f', struct.pack('<I', values[preset][field]))[0])
            self.assertEqual(row['uv_rect'], [0, 0, 0.5, 0.5])
            self.assertEqual((row['start_rgba'], row['end_rgba']), (list(values[preset][0x38].to_bytes(4, 'big')), [255, 255, 255, 204]))
        self.assertEqual(data['emitter_defaults'], reader.emitter_defaults(0.0))
        self.assertEqual({key: (row['offset'] - lib.text['offset'] + lib.text['address'], row['bytes']) for key, row in data['provenance'].items()},
                         {'defaults': (marks['preamble'], marks['defaults'] - marks['preamble']), 'presets': (marks['presets'], marks['end'] - marks['presets']),
                          'smoke_material': (marks['smoke'], marks['smoke_end'] - marks['smoke']),
                          'fire_material': (marks['fire'], marks['fire_end'] - marks['fire'])})
        # Changed values are read, not assumed.
        self.assertEqual([row['animation_frames'] for row in reader.extract_damage_particles(android(frames=2)[0])['presets']], [2, 2])
        self.assertEqual([row['material_id'] for row in reader.extract_damage_particles(android(ids=(7, 8))[0])['presets']], [7, 8])
        for options in (dict(stride=0xa0), dict(vector_last=True)):
            self.assertEqual(reader.extract_damage_particles(android(**options)[0])['presets'], data['presets'], options)

    def test_each_broken_shape_is_unsupported(self):
        cases = {'r0 before this': dict(r0_written=True), 'two preambles': dict(preambles=2), 'two loops': dict(loops=2),
                 'entry': dict(entry='early'), 'back edge': dict(back='early'), 'vector default': dict(vector=1),
                 'scalar default': dict(scalar=1), 'set count': dict(count=42), 'short stride': dict(stride=0x98),
                 'object moved': dict(fp_moved=True), 'object moved before the uv store': dict(fp_moved=True, vector_last=True), 'jump into the code': dict(entry_jump=True),
                 'value across a call': dict(clobber=True), 'vector across a call': dict(d=16), 'overlap': dict(overlap=True),
                 'missing field': dict(missing=True), 'field twice': dict(twice=True), 'other call': dict(foreign=True),
                 'other store': dict(strb=True), 'loaded value': dict(loaded=True), 'vector half replaced': dict(high=True),
                 'vector not from the pool': dict(pool_base=9), 'renamed set': dict(rename=True), 'no next set': dict(end=False),
                 'level r0': dict(level_r0=True), 'level object': dict(level_this=1), 'camera': dict(camera=2), 'no index': dict(none=0xfffe),
                 'object rewritten': dict(rewrite=True), 'wide stack store': dict(wide_stack=True), 'arguments before a call': dict(args_early=True),
                 'arguments entered': dict(arg_target=True), 'two smoke managers': dict(fields=(0x78, 0x84, 0x78)),
                 'no fire manager': dict(fields=(0x78, 0x88, 0x74)), 'same material': dict(ids=(410, 410)),
                 'material range': dict(ids=(410, 65535)), 'invalid preset': dict(frames=0)}
        for name, options in cases.items():
            self.assertEqual(reader.extract_damage_particles(android(**options)[0]), {}, name)
        lib = android()[0]
        del lib.symbols[reader.ANDROID_LEVEL]
        self.assertEqual(reader.extract_damage_particles(lib), {})
