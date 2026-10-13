"""Static smoke/fire sprite declarations and bounded emitter defaults.

Only bounded literal assignments and material constructor arguments are read.
Only the supported fields of two presets are emitted, never executable bytes.

Android: ParticleSettings::init first fills all 48 particle sets (0x9c bytes,
an 8-byte name, then the Mac's fields 8 bytes lower) with defaults in a loop,
then assigns each set's name and fields; Level::init constructs the smoke and
fire ParticleSystemManagers (kept at Level+0x78 and +0x84) with their materials.
"""
import math
import re
import struct
from .opening_loadout import template
from .android_listing import Listing, number
from .ship_models import section_bytes

INTEGER_FIELDS = {0x10:'flags',0x14:'capacity',0x1c:'size_jitter',
    0x2c:'lifetime_ms',0x34:'even_spacing',0x40:'fade_in_ms',
    0x48:'size_growth_per_second',0x4c:'scatter_xz',0x50:'scatter_y',
    0x54:'velocity_scatter',0xa0:'animation_frames'}
FLOAT_FIELDS = {0x18:'size',0x30:'emission_per_second',
    0x68:'relative_velocity_factor',0x74:'local_velocity_z',
    0x80:'local_offset_y',0x84:'local_offset_z',0x88:'local_offset_z_jitter'}

def parameters(row):
    """Bound the supported sprite configuration without fixture-value fallback."""
    if row['flags'] != 0x02000021 or row['even_spacing'] != 1:return False
    for name,low,high in [('capacity',1,4096),('lifetime_ms',1,60000),
        ('size_jitter',0,32767),('fade_in_ms',0,row['lifetime_ms']),
        ('size_growth_per_second',-32768,32767),('scatter_xz',0,32767),
        ('scatter_y',0,32767),('velocity_scatter',0,32767),('animation_frames',1,256)]:
        if not low<=row[name]<=high:return False
    if not all(math.isfinite(row[key]) for key in FLOAT_FIELDS.values()):return False
    if not 0<row['size']<=32767 or row['size']+row['size_jitter']>32767:return False
    if not 0<row['emission_per_second']<=10000:return False
    if any(abs(row[key])>1e6 for key in FLOAT_FIELDS.values()):return False
    if row['local_offset_z_jitter']<0:return False
    u0,v0,u1,v1=row['uv_rect']
    return all(math.isfinite(v) for v in row['uv_rect']) and 0<=u0<u1<=1 and 0<=v0<v1<=1 and (u1-u0)*(v1-v0)*row['animation_frames']<=1.000001

def emitter_defaults(zero):
    return {'auxiliary_sizes':[zero,zero], 'velocity_size_factor':zero,
            'initial_fade_ms':int(zero), 'velocity_base':[zero,zero,zero],
            'local_velocity_xy':[zero,zero], 'local_offset_x':zero,
            'minimum_squared_speed':int(zero)}

def preset_rows(values,ids):
    """Rows of presets 15 and 42 from their fields (Mac offsets -> words), or None."""
    records=[]
    for index,preset in enumerate([15,42]):
        data=values[preset];row={'preset_id':preset,'material_id':ids[index]}
        for offset,name in INTEGER_FIELDS.items():
            value=data[offset]
            row[name]=value if name=='flags' else struct.unpack('<i',struct.pack('<I',value))[0]
        for offset,name in FLOAT_FIELDS.items():row[name]=struct.unpack('<f',struct.pack('<I',data[offset]))[0]
        for key,offset in [('start_rgba',0x38),('end_rgba',0x3c)]:row[key]=list(data[offset].to_bytes(4,'big'))
        row['uv_rect']=[struct.unpack('<f',struct.pack('<I',data[offset]))[0] for offset in [0x8c,0x90,0x94,0x98]]
        if not parameters(row):return None
        records.append(row)
    return records

def disjoint(provenance):
    spans=sorted((p['offset'],p['offset']+p['bytes']) for p in provenance.values())
    return all(a[1]<=b[0] for a,b in zip(spans,spans[1:]))

def extract_damage_particles(mach):
    if mach.architecture=='android-armv7':return android_particles(mach)
    if mach.architecture not in ['x86_64','armv7']:return {}
    import capstone
    mac=mach.architecture=='x86_64';prefix='MAC_' if mac else 'ARM_'
    sec=mach.text;base=sec['address'];file_base=mach.slice_offset+sec['offset']
    code=mach.data[sec['offset']:sec['offset']+sec['length']]
    md=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);md.detail=True
    provenance={}
    def require(value):
        if not value:raise ValueError('Unsupported damage particle declarations')
    def instruction(m,key):
        rows=list(md.disasm(m[key],base+m.start(key)))
        require(len(rows)==1 and rows[0].size==len(m[key]));return rows[0]
    def match(key):
        name=prefix+key.upper()
        matches=[m for m in template(globals()[name]).finditer(code) if mac or m.start()%2==0]
        require(len(matches)==1);m=matches[0]
        if not mac:
            for field,(kind,register) in ARM_FIELDS[name].items():
                i=instruction(m,field);require(i.mnemonic==kind)
                if register:require(i.reg_name(i.operands[0].reg)==register and i.operands[1].type==2)
        provenance[key]={'offset':file_base+m.start(),'bytes':len(m[0])};return m
    def literal(m,key):
        if mac:return int.from_bytes(m[key],'little')
        i=instruction(m,key);v=i.operands[1].imm
        return (~v if i.mnemonic=='mvn' else v)&0xffffffff
    def target(m,key):
        return base+m.end(key)+int.from_bytes(m[key],'little',signed=True) if mac else instruction(m,key).operands[0].imm
    try:
        declarations=match('presets');smoke=match('smoke_material');fire=match('fire_material')
        defaults=match('defaults')
        if mac:
            zeros=[int.from_bytes(defaults[key],'little') for key in ['v_24','v_1c','v_44','v_7c','v_6c','v_64','v_5c','v_9c']]
        else:
            zeros=[instruction(defaults,key).operands[1].imm for key in ['vector_tail','vector_defaults','scalar_defaults']]
        # These layouts declare zero in eleven fields used by the supported
        # emission path. Nonzero variants require further behavior recovery.
        require(all(value==0 for value in zeros))
        defaults=emitter_defaults(float(zeros[0]))
        require(target(smoke,'call_1d' if mac else 'call_12')==target(fire,'call_1d' if mac else 'call_12'))
        ids=[literal(smoke,'material'),literal(fire,'material')]
        require(all(0<=v<65535 for v in ids) and ids[0]!=ids[1])
        values={15:{},42:{}}
        for field,expression in DATA_FIELDS[prefix+'PRESETS'].items():
            preset,offset=map(int,field.split(':'));v=literal(declarations,expression[0])
            if len(expression)==2:v=(v&65535)|(literal(declarations,expression[1])<<16)
            values[preset][offset]=v
        records=preset_rows(values,ids);require(records)
        require(disjoint(provenance))
        return {'scope':'damage_particle_sprite_presets','presets':records,
                'emitter_defaults':defaults,'provenance':provenance}
    except (ValueError,KeyError,TypeError,IndexError,OverflowError,struct.error):return {}

MAC_PRESETS = """
4d8da5d80900004c89e74889dee8
{call_d:4}
488dbdb8feffffe8
{call_19:4}
41c785e8090000
{v_1e:4}
41c785040a0000
{v_29:4}
41c785080a0000
{v_34:4}
41c785ec090000
{v_3f:4}
41c785f0090000
{v_4a:4}
488d9da8feffff488d35
{ref_5c:4}
41c785f4090000
{v_63:4}
41c785100a0000
{v_6e:4}
41c785140a0000
{v_79:4}
41c785180a0000
{v_84:4}
41c785200a0000
{v_8f:4}
41c7852c0a0000
{v_9a:4}
41c7854c0a0000
{v_a5:4}
41c785580a0000
{v_b0:4}
41c7855c0a0000
{v_bb:4}
41c785240a0000
{v_c6:4}
41c785600a0000
{v_d1:4}
41c785280a0000
{v_dc:4}
41c785400a0000
{v_e7:4}
41c7850c0a0000
{v_f2:4}
41c785640a0000
{v_fd:4}
41c785680a0000
{v_108:4}
41c7856c0a0000
{v_113:4}
41c785700a0000
{v_11e:4}
41c785780a0000
{v_129:4}
4889df31d2e8
{call_139:4}
498dbd901b00004889dee8
{call_148:4}
488dbda8feffffe8
{call_154:4}
41c785a01b0000
{v_159:4}
41c785bc1b0000
{v_164:4}
41c785c01b0000
{v_16f:4}
41c785a41b0000
{v_17a:4}
41c785a81b0000
{v_185:4}
4d8db5780c000041c785ac1b0000
{v_197:4}
41c785c81b0000
{v_1a2:4}
41c785cc1b0000
{v_1ad:4}
41c785d01b0000
{v_1b8:4}
41c785d81b0000
{v_1c3:4}
41c785e41b0000
{v_1ce:4}
41c785041c0000
{v_1d9:4}
41c785101c0000
{v_1e4:4}
41c785141c0000
{v_1ef:4}
41c785dc1b0000
{v_1fa:4}
41c785181c0000
{v_205:4}
41c785e01b0000
{v_210:4}
41c785f81b0000
{v_21b:4}
41c785c41b0000
{v_226:4}
41c7851c1c0000
{v_231:4}
41c785201c0000
{v_23c:4}
41c785241c0000
{v_247:4}
41c785281c0000
{v_252:4}
41c785301c0000
{v_25d:4}
"""

MAC_SMOKE_MATERIAL = """
c70424000000004c89ffba01000000b9
{material:4}
4531c041b9ffff0000e8
{call_1d:4}
4d89be90000000
"""

MAC_FIRE_MATERIAL = """
c70424000000004c89ffba01000000b9
{material:4}
4531c041b9ffff0000e8
{call_1d:4}
4d89bea8000000
"""

ARM_PRESETS = """
05f6241008902146
{call_8:4}
23a8
{v_e:4}
4894
{call_14:4}
{ref_18:4}
{v_1c:2}
{ref_1e:4}
0a9d
{v_24:4}
{v_28:2}
{v_2a:2}
7944c5f82c09
{v_32:4}
c5f84809
{v_3a:2}
{v_3c:4}
c5f84c09
{v_44:2}
c5f83009
{v_4a:4}
{v_4e:4}
c5f83409
{v_56:2}
c5f83809
{v_5c:4}
c5f85449c5f85809
{v_68:4}
c5f85c39c5f86409
{v_74:2}
{v_76:4}
c5f87029c5f89029c5f89c29c5f8a009
{v_8a:2}
{v_8c:4}
c5f86839c5f8a409
{v_98:4}
c5f86c39c5f88409
{v_a4:2}
c5f85009
{v_aa:4}
c5f8a829c5f8ac290022c5f8b009c5f8b409
{v_c0:2}
c5f8bc09489421ac2046
{call_cc:4}
1420489041f6981028442146
{call_dc:4}
0a9d21a84ff0ff3805f62c160596cdf82081
{call_f2:4}
{v_f6:2}
4ff4cd50
{v_fc:4}
{v_100:2}
295041f6bc10
{v_108:4}
2950
{v_10e:2}
4ff4ce50
{v_114:4}
{v_118:2}
295041f6a410
{v_120:2}
2950
{v_124:2}
41f6a810
{v_12a:4}
05f69434295041f6ac10
{v_138:2}
295041f6c810
{v_140:4}
295041f6cc10
{v_14a:4}
295041f6d010
{v_154:2}
295041f6d8102a5041f6e410
{v_162:2}
2b5041f60420
{v_16a:4}
2b5041f610202b5041f614202a5041f6dc10295041f618202a504ff4cf502950
{v_18e:2}
41f6f810
{v_194:4}
295041f6c410
{v_19e:2}
295041f61c20
{v_1a6:4}
2b504ff4d1502b5041f62420295041f62820295041f63020
{v_1c2:2}
2950
"""

ARM_SMOKE_MATERIAL = """
00224ff6ff738de80c00
{material:4}
02920122
{call_12:4}
ddf81480
{ref_1a:4}
{ref_1e:4}
4ff0ff3478440568259806998867
"""

ARM_FIRE_MATERIAL = """
00224ff6ff738de80c00
{material:4}
02920122
{call_12:4}
26980699c1f88400
"""


ARM_FIELDS = {'ARM_PRESETS': {'call_8': ('bl', ''),
                 'v_e': ('mov.w', 'r4'),
                 'call_14': ('bl', ''),
                 'ref_18': ('movw', 'r1'),
                 'v_1c': ('movs', 'r0'),
                 'ref_1e': ('movt', 'r1'),
                 'v_24': ('movt', 'r0'),
                 'v_28': ('movs', 'r3'),
                 'v_2a': ('movs', 'r2'),
                 'v_32': ('movw', 'r0'),
                 'v_3a': ('movs', 'r0'),
                 'v_3c': ('movt', 'r0'),
                 'v_44': ('movs', 'r0'),
                 'v_4a': ('movw', 'r0'),
                 'v_4e': ('movt', 'r0'),
                 'v_56': ('movs', 'r0'),
                 'v_5c': ('mvn', 'r0'),
                 'v_68': ('movw', 'r0'),
                 'v_74': ('movs', 'r0'),
                 'v_76': ('movt', 'r0'),
                 'v_8a': ('movs', 'r0'),
                 'v_8c': ('movt', 'r0'),
                 'v_98': ('mov.w', 'r0'),
                 'v_a4': ('movs', 'r0'),
                 'v_aa': ('mov.w', 'r0'),
                 'v_c0': ('movs', 'r0'),
                 'call_cc': ('bl', ''),
                 'call_dc': ('bl', ''),
                 'call_f2': ('bl', ''),
                 'v_f6': ('movs', 'r1'),
                 'v_fc': ('movt', 'r1'),
                 'v_100': ('movs', 'r2'),
                 'v_108': ('mov.w', 'r1'),
                 'v_10e': ('movs', 'r1'),
                 'v_114': ('movt', 'r1'),
                 'v_118': ('movs', 'r3'),
                 'v_120': ('movs', 'r1'),
                 'v_124': ('movs', 'r1'),
                 'v_12a': ('movt', 'r1'),
                 'v_138': ('movs', 'r1'),
                 'v_140': ('mvn', 'r1'),
                 'v_14a': ('mvn', 'r1'),
                 'v_154': ('movs', 'r1'),
                 'v_162': ('movs', 'r2'),
                 'v_16a': ('movt', 'r2'),
                 'v_18e': ('movs', 'r1'),
                 'v_194': ('movt', 'r1'),
                 'v_19e': ('movs', 'r1'),
                 'v_1a6': ('mov.w', 'r1'),
                 'v_1c2': ('movs', 'r1')},
 'ARM_SMOKE_MATERIAL': {'material': ('movw', 'r3'),
                        'call_12': ('bl', ''),
                        'ref_1a': ('movw', 'r0'),
                        'ref_1e': ('movt', 'r0')},
 'ARM_FIRE_MATERIAL': {'material': ('movw', 'r3'), 'call_12': ('bl', '')}}


DATA_FIELDS = {'MAC_PRESETS': {'15:16': ['v_1e'],
                 '15:44': ['v_29'],
                 '15:48': ['v_34'],
                 '15:20': ['v_3f'],
                 '15:24': ['v_4a'],
                 '15:28': ['v_63'],
                 '15:56': ['v_6e'],
                 '15:60': ['v_79'],
                 '15:64': ['v_84'],
                 '15:72': ['v_8f'],
                 '15:84': ['v_9a'],
                 '15:116': ['v_a5'],
                 '15:128': ['v_b0'],
                 '15:132': ['v_bb'],
                 '15:76': ['v_c6'],
                 '15:136': ['v_d1'],
                 '15:80': ['v_dc'],
                 '15:104': ['v_e7'],
                 '15:52': ['v_f2'],
                 '15:140': ['v_fd'],
                 '15:144': ['v_108'],
                 '15:148': ['v_113'],
                 '15:152': ['v_11e'],
                 '15:160': ['v_129'],
                 '42:16': ['v_159'],
                 '42:44': ['v_164'],
                 '42:48': ['v_16f'],
                 '42:20': ['v_17a'],
                 '42:24': ['v_185'],
                 '42:28': ['v_197'],
                 '42:56': ['v_1a2'],
                 '42:60': ['v_1ad'],
                 '42:64': ['v_1b8'],
                 '42:72': ['v_1c3'],
                 '42:84': ['v_1ce'],
                 '42:116': ['v_1d9'],
                 '42:128': ['v_1e4'],
                 '42:132': ['v_1ef'],
                 '42:76': ['v_1fa'],
                 '42:136': ['v_205'],
                 '42:80': ['v_210'],
                 '42:104': ['v_21b'],
                 '42:52': ['v_226'],
                 '42:140': ['v_231'],
                 '42:144': ['v_23c'],
                 '42:148': ['v_247'],
                 '42:152': ['v_252'],
                 '42:160': ['v_25d']},
 'ARM_PRESETS': {'15:16': ['v_1c', 'v_24'],
                 '15:44': ['v_32'],
                 '15:48': ['v_3a', 'v_3c'],
                 '15:20': ['v_44'],
                 '15:24': ['v_4a', 'v_4e'],
                 '15:28': ['v_56'],
                 '15:56': ['v_e'],
                 '15:60': ['v_5c'],
                 '15:64': ['v_28'],
                 '15:72': ['v_68'],
                 '15:84': ['v_2a'],
                 '15:116': ['v_2a'],
                 '15:128': ['v_2a'],
                 '15:132': ['v_74', 'v_76'],
                 '15:76': ['v_28'],
                 '15:136': ['v_8a', 'v_8c'],
                 '15:80': ['v_28'],
                 '15:104': ['v_98'],
                 '15:52': ['v_a4'],
                 '15:140': ['v_2a'],
                 '15:144': ['v_2a'],
                 '15:148': ['v_aa'],
                 '15:152': ['v_aa'],
                 '15:160': ['v_c0'],
                 '42:16': ['v_f6', 'v_fc'],
                 '42:44': ['v_108'],
                 '42:48': ['v_10e', 'v_114'],
                 '42:20': ['v_120'],
                 '42:24': ['v_124', 'v_12a'],
                 '42:28': ['v_138'],
                 '42:56': ['v_140'],
                 '42:60': ['v_14a'],
                 '42:64': ['v_154'],
                 '42:72': ['v_100'],
                 '42:84': ['v_118'],
                 '42:116': ['v_118'],
                 '42:128': ['v_118'],
                 '42:132': ['v_162', 'v_16a'],
                 '42:76': ['v_154'],
                 '42:136': ['v_162', 'v_16a'],
                 '42:80': ['v_154'],
                 '42:104': ['v_18e', 'v_194'],
                 '42:52': ['v_19e'],
                 '42:140': ['v_118'],
                 '42:144': ['v_118'],
                 '42:148': ['v_1a6'],
                 '42:152': ['v_1a6'],
                 '42:160': ['v_1c2']}}

MAC_DEFAULTS = """
4c89eb41ffc44183fc2f0f8f170100004c89f7488d35
{ref_13:4}
31d2e8
{call_1c:4}
4889df4c89f6e8
{call_27:4}
4c8dbba80000004c89f7e8
{call_36:4}
c7431010000000c7431401000000c743180000c84248c74324
{v_24:4}
48c7431c
{v_1c:4}
c7432c64000000c743300000fa43c7433400000000c74338ff00ff00c7433cff00ff00c7434000000000c74344
{v_44:4}
c74348f401000048c7838c0000000000000048c783840000000000000048c7437c
{v_7c:4}
48c743740000000048c7436c
{v_6c:4}
48c74364
{v_64:4}
48c7435c
{v_5c:4}
48c743540000000048c7434c00000000c7839400000000007c42c7839800000000007c42c7839c000000
{v_9c:4}
c783a0000000000000004c89fbe9edfeffff
"""

ARM_DEFAULTS = """
{vector_tail:4}
8c34
{vector_defaults:4}
45ae4ff0ff380125002003e0
{ref_16:4}
{ref_1a:4}
0b9030460c940022cdf82081
{ref_2a:4}
{ref_2e:4}
7944
{call_34:4}
4895a4f18c003146
{call_40:4}
45ae4ff0ff38cdf820813046
{call_50:4}
0c9c10200125
{scalar_defaults:2}
44f8840c0020c4f2c82044f8805c44f87c0ca4f1780000f98f8a642044f8680c0020c4f2fa3044f8640c4ff0ff1044f8601c44f85c0c44f8580c4ff4fa7044f8541c44f8501c44f84c0ca4f1180000f98f8aa4f1280000f98f8aa4f1380000f98f8aa4f1480000f98f8a0020c4f27c2044f8041c44f8081c206060600b9884ed02ab9c34013030289bdb
"""

ARM_FIELDS['ARM_DEFAULTS'] = {
    'vector_tail': ('vmov.i32','d10'), 'vector_defaults': ('vmov.i32','q4'),
    'scalar_defaults': ('movs','r1'),
    'ref_2a': ('movw','r1'), 'ref_2e': ('movt','r1'),
    'call_34': ('bl',''), 'call_40': ('bl',''), 'call_50': ('bl','')}


ANDROID_INIT = '_ZN16ParticleSettings4initEv'
ANDROID_LEVEL = '_ZN5Level4initEv'
ANDROID_MANAGER = '_ZN21ParticleSystemManagerC1EPN11AbyssEngine11PaintCanvasEN16ParticleSettings9CameraSetEtbtb'
ANDROID_NAME = 'call _ZN11AbyssEngine6StringaSERKS0_'
ANDROID_STRINGS = {ANDROID_NAME, 'call _ZN11AbyssEngine6StringC1EPKcb', 'call _ZN11AbyssEngine6StringD1Ev'}
# Level fields of the two managers (as on iOS); a set's Mac field m lies at set + m - 8.
ANDROID_MANAGERS = {'smoke_material': 0x78, 'fire_material': 0x84}
ANDROID_FIELDS = sorted([*INTEGER_FIELDS, *FLOAT_FIELDS, 0x38, 0x3c, 0x8c, 0x90, 0x94, 0x98])
CALLER_SAVED = r'r[0-3]|ip|d[0-7]|d1[6-9]|d[23]\d'

# ParticleSettings::init: `this` in fp, the default vector (q5 = d10:d11) and
# scalar (r4), then a branch over a literal pool into the loop below.
ANDROID_PREAMBLE = r"""mov fp, r0
ldr r0, =\w+
vmov\.i32 q5, #(?P<vector>\w+)
movw sl, #0
adr r0, \w+
add\.w r5, fp, #0x8c
add r6, sp, #0x24
movs r4, #(?P<scalar>\w+)
ldr r0, \[r0\]
mov\.w sb, #0x1f4
movt sl, #0x427c
mov\.w r8, #0
ldr r0, \[r0\]
str r0, \[sp, #0x2c\]
adr r0, #0x18
vld1\.64 \{d8, d9\}, \[r0:0x80\]
b #(?P<loop>\w+)
"""
# One set per pass (r5 = set + 0x8c): the name, then the defaults; Mac fields
# 0x1c-0x2b take the vector, 0x44 and 0x9c the scalar, 0x4c-0x93 are cleared.
ANDROID_LOOP = r"""ldr r1, =\w+
mov r0, r6
movs r2, #0
adr r1, \w+
call _ZN11AbyssEngine6StringC1EPKcb
sub\.w r0, r5, #0x8c
mov r1, r6
call _ZN11AbyssEngine6StringaSERKS0_
mov r0, r6
call _ZN11AbyssEngine6StringD1Ev
movs r0, #0x10
movs r1, #0x48
str r0, \[r5, #-0x84\]
movs r0, #1
str r0, \[r5, #-0x80\]
movs r0, #0
movt r0, #0x42c8
str r0, \[r5, #-0x7c\]
sub\.w r0, r5, #0x78
vst1\.32 \{d10, d11\}, \[r0\]
movs r0, #0x64
str r0, \[r5, #-0x68\]
movs r0, #0
movt r0, #0x43fa
str r0, \[r5, #-0x64\]
sub\.w r0, r5, #0x60
vst1\.32 \{d8, d9\}, \[r0\]
sub\.w r0, r5, #0x48
strd r4, sb, \[r5, #-0x50\]
call __aeabi_memclr4
strd sl, sl, \[r5\]
add\.w r8, r8, #1
strd r4, r4, \[r5, #8\]
adds r5, #(?P<stride>\w+)
cmp\.w r8, #(?P<count>\w+)
blt #(?P<back>\w+)
"""


class Flow:
    """Register contents read backwards through code with one entry (nothing is executed)."""

    def __init__(self, listing):
        from capstone.arm_const import ARM_OP_IMM
        from .android_library import is_jump
        self.listing, self.lines, self.used = listing, listing.lines, set()
        self.jumps = [(ins.address, ins.operands[-1].imm) for ins in listing.code
                      if ins.id and is_jump(ins) and ins.operands and ins.operands[-1].type == ARM_OP_IMM]
        self.targets = {target for _, target in self.jumps}

    def source(self, index, register, keep=True):
        """The last earlier instruction writing `register`, when no jump from elsewhere
        lands in between and (for a caller-saved register) no call intervenes."""
        found = self.listing.definition(index, register)
        if found is None:
            raise ValueError(register)
        low, high = self.listing.code[found].address, self.listing.code[index].address
        if (any(low < target <= high and not low < origin < high for origin, target in self.jumps)
                or re.fullmatch(CALLER_SAVED, register) and any(line.startswith('call ') for line in self.lines[found + 1:index])):
            raise ValueError(register)
        if keep:
            self.used.add(found)
        return found

    def value(self, index, register):
        """The constant word `register` holds at `index`."""
        found = self.source(index, register)
        line = self.lines[found]
        m = re.fullmatch(r'(movs|movw|mov\.w|mvn|movt) %s, #(-?\w+)' % register, line)
        if m:
            word = number(m[2]) & 0xffffffff
            if m[1] == 'movt':
                return self.value(found, register) & 0xffff | word << 16
            return ~word & 0xffffffff if m[1] == 'mvn' else word
        raise ValueError(line)

    def this(self, index, register):
        """`register` still holds the incoming r0 (the object)."""
        found = self.source(index, register, keep=False)
        if self.lines[found] != 'mov %s, r0' % register or self.listing.definition(found, 'r0') is not None:
            raise ValueError(register)

    def address(self, index, register):
        """The offset from the object (fp) that `register` holds."""
        found = self.source(index, register)
        line = self.lines[found]
        m = re.fullmatch(r'addw %s, fp, #(\w+)' % register, line)
        if m or line == 'add %s, fp' % register:
            self.this(found, 'fp')
            return number(m[1]) if m else self.value(found, register)
        m = re.fullmatch(r'mov %s, (\w+)' % register, line)
        if m:
            return self.address(found, m[1])
        raise ValueError(line)

    def vector(self, index, low, high):
        """Four words loaded into `low`:`high` from the function's literal pool."""
        found = self.source(index, low)
        m = re.fullmatch(r'vld1\.64 \{%s, %s\}, \[(\w+):0x80\]' % (low, high), self.lines[found])
        if self.source(index, high) != found:
            raise ValueError(high)
        pool = self.source(found, m[1])
        n = re.fullmatch(r'addw %s, pc, #(\w+)' % m[1], self.lines[pool])
        words = section_bytes(self.listing.lib, (self.listing.code[pool].address + 4 & ~3) + number(n[1]), 16, b'__text')
        return list(struct.unpack('<4I', words[0]))

    def stores(self, index):
        """(offset from the object in fp, word) of each word one store writes."""
        line = self.lines[index]
        m = re.fullmatch(r'str\.w (\w+), \[fp, (#?)(\w+)\]', line)
        if m:
            self.this(index, 'fp')
            return [(number(m[3]) if m[2] else self.value(index, m[3]), self.value(index, m[1]))]
        m = re.fullmatch(r'vst1\.32 \{(\w+), (\w+)\}, \[(\w+)\]', line)
        if m:
            at = self.address(index, m[3])
            return [(at + 4 * k, word) for k, word in enumerate(self.vector(index, m[1], m[2]))]
        raise ValueError(line)

    def stack(self, index, slot):
        """(word, store index) of [sp, #slot] as set by the straight-line code before the call at `index`."""
        for at in range(index - 1, -1, -1):
            line = self.lines[at]
            if line.startswith('call ') or self.listing.code[at + 1].address in self.targets:
                break
            pair = re.fullmatch(r'strd (\w+), (\w+), \[sp\]', line)
            single = re.fullmatch(r'str (\w+), \[sp, #(\w+)\]', line)
            if pair and slot in (0, 4):
                return self.value(at, pair[1 + slot // 4]), at
            if single and number(single[2]) == slot:
                return self.value(at, single[1]), at
            if not (pair or single) and line.startswith(('st', 'vst', 'push')) and 'sp' in line:
                break
        raise ValueError(slot)


def android_set(flow, calls, names, preset, stride):
    """Mac field offset -> word of one set: its stores between its name and the next
    name assignment (`calls`: every String::operator=; `names`: offset -> those into it)."""
    base = preset * stride
    own = names.get(base, [])
    later = [i for i in calls if own and i > own[0]]
    if len(own) != 1 or not later:
        raise ValueError(preset)
    fields = {}
    for i in range(own[0] + 1, later[0]):
        line = flow.lines[i]
        if line.startswith('call ') and line not in ANDROID_STRINGS:
            raise ValueError(line)
        if line.startswith(('st', 'vst')):
            for at, word in flow.stores(i):
                if at in fields or at >= base + stride:
                    raise ValueError(at)
                fields[at] = word
            last = i
    values = {at - base + 8: word for at, word in fields.items()}
    if sorted(values) != ANDROID_FIELDS:
        raise ValueError(preset)
    return values, last


def android_manager(flow, field):
    """(material, first, last instruction index) of the one manager Level::init keeps at `field`."""
    lines, found = flow.lines, []
    for i, line in enumerate(lines):
        if line != 'call ' + ANDROID_MANAGER:
            continue
        held = re.fullmatch(r'mov r0, (\w+)', lines[flow.source(i, 'r0')])[1]
        j = next(j for j in range(i + 1, len(lines)) if lines[j].startswith(('str %s, [' % held, 'str.w %s, [' % held)))
        m = re.fullmatch(r'str(?:\.w)? %s, \[(\w+), #(\w+)\]' % held, lines[j])
        if flow.source(j, held) > i:
            raise ValueError(held)
        flow.this(j, m[1])
        if number(m[2]) == field:
            found.append((i, j))
    if len(found) != 1:
        raise ValueError(field)
    i, j = found[0]
    arguments = [flow.stack(i, slot) for slot in (0, 4, 8)]
    if flow.value(i, 'r2') != 1 or [word for word, _ in arguments] != [0, 0xffff, 0]:
        raise ValueError(field)
    first = min([at for _, at in arguments] + [flow.source(i, register) for register in ('r0', 'r2', 'r3')])
    return flow.value(i, 'r3'), first, j


def android_particles(lib):
    """Sets 15 and 42 (their stores and every constant those read), the defaults
    loop, and the two managers' constructions; values as the Mac reader emits them."""
    init, level = Listing(lib, ANDROID_INIT), Listing(lib, ANDROID_LEVEL)
    preambles, loops = init.find(ANDROID_PREAMBLE), init.find(ANDROID_LOOP)
    if len(preambles) != 1 or len(loops) != 1:
        return {}
    preamble, loop = preambles[0], loops[0]
    start = init.code[init.index(loop)].address
    if (number(preamble['loop']) != start or number(loop['back']) != start or number(preamble['vector'])
            or number(preamble['scalar']) or number(loop['count']) <= 42):
        return {}
    try:
        flow, calls, names = Flow(init), [i for i, line in enumerate(init.lines) if line == ANDROID_NAME], {}
        for i in calls:
            try:
                names.setdefault(flow.address(i, 'r0'), []).append(i)
            except ValueError:
                pass
        flow.used = set()
        (set15, last15), (set42, last42) = (android_set(flow, calls, names, preset, number(loop['stride'])) for preset in (15, 42))
        provenance = {'presets': init.span(min(flow.used), max(last15, last42))}
        level_flow, ids = Flow(level), []
        for key, field in ANDROID_MANAGERS.items():
            material, first, last = android_manager(level_flow, field)
            ids.append(material)
            provenance[key] = level.span(first, last)
    except (ValueError, TypeError, StopIteration):
        return {}
    provenance['defaults'] = init.span(init.index(preamble), init.last(loop))
    records = preset_rows({15: set15, 42: set42}, ids) if all(0 <= v < 65535 for v in ids) and ids[0] != ids[1] else None
    if not records or not disjoint(provenance):
        return {}
    return {'scope': 'damage_particle_sprite_presets', 'presets': records,
            'emitter_defaults': emitter_defaults(0.0), 'provenance': provenance}
