"""Bounded ordinary NPC flight tuning; original code is never emitted.

Android: PlayerFighter's constructor stores the bank limit and gain;
PlayerFighter::update (vtable slot 13 of the class the activation resolves)
turns by elapsed x 48 / 65536, snaps the heading below an L1 step of 0.0625,
signs the bank angle at pi/2, averages five bank samples, scales them by gain
and limit, slews by elapsed x 1.25 / 3.9 and rolls by bank x pi / 4096.
"""
import math
import struct
from .opening_loadout import template
from .npc_initialization import MAC_ACTOR_WRAPPER, ARM_ACTOR_WRAPPER

LAYOUTS = {'x86_64': {'bank': ('constructor', 2272, 24, '41c78424fc020000 {bank_limit:4} 41c7842400030000 {bank_gain:4}'),
            'turn': ('update', 12248, 19, '416bc5 {turn_numerator:1} 0f57c0f30f2ac0f30f5905 {ref_b:4}'),
            'snap': ('update', 12480, 13, 'f30f100d {ref_0:4} 0f2ec8760f'),
            'sign': ('update', 12726, 13, 'f30f100d {ref_0:4} 0f2ec8770a'),
            'history': ('update',
                        12764,
                        222,
                        '49638618030000f3410f11948604030000418a861c030000240174280f57d231c9f3410f58948e0403000048ffc183f90575eef30f5e15 '
                        '{ref_33:4} '
                        '418b8e18030000eb3c418b8e1803000085c9750bffc141898e18030000eb4b0f57d27e160f57d231d2f3410f5894960403000048ffc239ca7cef0f57c0f30f2ac1f30f5ed0ffc141898e1803000083f9057c1741c786180300000000000084c0750841c6861c03000001f3410f1086fc020000f30f59d0f3410f599600030000f3410f1196740200000f2ed0770c0f5705 '
                        '{ref_c9:4} 0f2ec27609f3410f118674020000'),
            'reset': ('update', 13279, 30, '41c786740200000000000041c786180300000000000041c6861c03000000'),
            'slew': ('update', 13355, 21, 'f3410f2acdf30f590d {ref_5:4} f30f5e0d {ref_d:4}'),
            'radians': ('update', 13609, 16, 'f30f5915 {ref_0:4} f30f5915 {ref_8:4}'),
            'travel': ('update', 13723, 28, '0f57c0f3410f2ac5f3410f598650020000f30f2cc00f57c0f30f2ac0')},
 'armv7': {'bank': ('constructor',
                    1794,
                    52,
                    '{limit_low:4}  {limit_high:4} c2f8f4000020159ac2f80402159ac2f80802159ac2f80c02159ac2f88c32 '
                    '{gain_low:4} 159a {gain_high:4} c2f89032'),
           'turn': ('update', 11936, 28, '{ref_0:4} cdf8a05800eb4000000140ec300b2046fbff200600ff900d'),
           'snap': ('update', 12102, 32, '{ref_0:4} b5eec00af1ee10fad8bfb9ff800700ef800db4eec20af1ee10fa08d5'),
           'sign': ('update', 12324, 22, '{ref_0:4} 40ec110bb4eec01af1ee10fa48bfb9ff8887'),
           'history': ('update',
                       12346,
                       198,
                       'daf8a8020aeb800080eda58a9af8ac0220ef100198b180ef10000af5257100228b180432142a93ed001a00ef010df7d181ef141fdaf8a81280ee018a16e0daf8a81209b380ef1000012909db0af525720023b2ec011a013300ef010d8b42f8db41ec301bbbff201680ee018a4a1ccaf8a82204290bdb00210028caf8a81204bf01208af8ac0202e00120caf8a8029aeda30a34469aeda41a48ff100d00ff911db4eec01a8aed811af1ee10fa02dd8aed810a08e0b9ff8007b4eec01af1ee10fa48bf8aed810a'),
           'reset': ('update', 11832, 14, '0020caf80402caf8a8028af8ac02'),
           'slew': ('update',
                    12742,
                    32,
                    '44ec324b {ref_4:4} fbff2226 {slew_numerator:4} b4eec20af1ee10fa02ffb01d81ee041a'),
           'radians': ('update',
                       12916,
                       42,
                       '{ref_0:4} cfac {ref_6:4} '
                       'c0ef500040ff122d211d4ff07e50c0adcf90002241f98f0a04f1180102ff910d'),
           'travel': ('update',
                      13122,
                      40,
                      '9aed780a40ec300bfbff200640ff900d9eed550a0df5806e9eed561a0df5806efbff2007fbff2006')}}


ANDROID_BANK = """
movw r2, #{gain_low}
movw r3, #{limit_low}
str.w r0, [fp, #0xf4]
movs r0, #0
movt r2, #{gain_high}
movt r3, #{limit_high}
vmov.i32 q8, #0
strd r0, r0, [fp, #0x204]
str.w r0, [fp, #0x20c]
strd r3, r2, [fp, #0x28c]
"""
# PlayerFighter::update: `this` in r4, elapsed milliseconds in r8 (as the Mac reader,
# the update's other paths are not followed).
ANDROID_TURN = """
add.w r0, r8, r8, lsl #{triple}
vldr s2, ={turn_scale}
lsls r0, r0, #{scale}
vmov s0, r0
mov r0, r6
vcvt.f32.s32 s0, s0
vmul.f32 s0, s0, s2
vmov r1, s0
call _ZN11AbyssEngine6AEMath6VectormLEf
"""
ANDROID_SNAP = """
vldr s2, [r4, #0x170]
vldr s8, [sp, #0xd4]
vldr s0, [r4, #0x16c]
vsub.f32 s2, s2, s8
vldr s6, [sp, #0xd0]
vldr s4, [r4, #0x174]
vsub.f32 s0, s0, s6
vldr s10, [sp, #0xd8]
vsub.f32 s4, s4, s10
vcmpe.f32 s2, #0
vmrs apsr_nzcv, fpscr
vneg.f32 s6, s2
vcmpe.f32 s0, #0
vneg.f32 s8, s0
vneg.f32 s10, s4
it gt
vmovgt.f32 s6, s2
vmrs apsr_nzcv, fpscr
vcmpe.f32 s4, #0
vldr s2, ={snap}
it gt
vmovgt.f32 s8, s0
vmrs apsr_nzcv, fpscr
vadd.f32 s0, s8, s6
it gt
vmovgt.f32 s10, s4
vadd.f32 s0, s0, s10
vcmpe.f32 s0, s2
vmrs apsr_nzcv, fpscr
bpl {@keep}
add r1, sp, #0xd0
mov r0, r6
call _ZN11AbyssEngine6AEMath6VectoraSERKS1_
keep: add r5, sp, #0x150
"""
ANDROID_SIGN = """
call _ZN11AbyssEngine6AEMath5ACosfEf
vldr s0, ={sign}
vmov s2, r0
vneg.f32 s4, s16
vcmpe.f32 s2, s0
vmrs apsr_nzcv, fpscr
it mi
vmovmi.f32 s16, s4
"""
# Samples at 0x294, next index at 0x2a8, full flag at 0x2ac; limit 0x28c, gain 0x290.
ANDROID_HISTORY = """
ldr.w r0, [r4, #0x2a8]
add.w r0, r4, r0, lsl #2
vstr s16, [r0, #0x294]
ldrb.w r0, [r4, #0x2ac]
cbz r0, {@partial}
vldr s0, ={zero_full}
add.w r1, r4, #0x294
movs r2, #0
sum: adds r3, r1, r2
adds r2, #4
cmp r2, #{window}
vldr s2, [r3]
vadd.f32 s0, s0, s2
bne {@sum}
vmov.f32 s2, #{samples}
ldr.w r1, [r4, #0x2a8]
b {@average}
partial: ldr.w r1, [r4, #0x2a8]
cbz r1, {@first}
vldr s0, ={zero_partial}
cmp r1, #1
blt {@count}
add.w r2, r4, #0x294
movs r3, #0
add: vldr s2, [r2]
adds r3, #1
adds r2, #4
cmp r3, r1
vadd.f32 s0, s0, s2
blt {@add}
count: vmov s2, r1
vcvt.f32.s32 s2, s2
average: vdiv.f32 s16, s0, s2
adds r2, r1, #1
str.w r2, [r4, #0x2a8]
cmp r1, #{last}
blt {@gain}
movs r1, #0
cmp r0, #0
str.w r1, [r4, #0x2a8]
bne {@gain}
movs r0, #1
strb.w r0, [r4, #0x2ac]
b {@gain}
first: movs r0, #1
str.w r0, [r4, #0x2a8]
gain: vldr s0, [r4, #0x28c]
vldr s2, [r4, #0x290]
vmul.f32 s4, s16, s0
vmul.f32 s2, s4, s2
vcmpe.f32 s2, s0
vstr s2, [r4, #0x204]
vmrs apsr_nzcv, fpscr
ble {@low}
vstr s0, [r4, #0x204]
b {@done}
low: vneg.f32 s0, s0
vcmpe.f32 s2, s0
vmrs apsr_nzcv, fpscr
it mi
vstrmi s0, [r4, #0x204]
done: add r5, sp, #0x150
"""
ANDROID_RESET = """
movs r0, #0
str.w r0, [r4, #0x204]
str.w r0, [r4, #0x2a8]
strb.w r0, [r4, #0x2ac]
"""
ANDROID_SLEW = """
vldr s2, [r4, #0x204]
vldr s0, [r4, #0x208]
vcmpe.f32 s0, s2
vmrs apsr_nzcv, fpscr
beq {}
vmov s6, r8
vmov.f32 s4, #{slew_numerator}
vcvt.f32.s32 s6, s6
vcmpe.f32 s0, s2
vmrs apsr_nzcv, fpscr
vmul.f32 s4, s6, s4
vldr s6, ={slew_divisor}
vdiv.f32 s4, s4, s6
"""
ANDROID_RADIANS = """
vldr s4, ={angle_scale}
vmov.i32 q8, #0
vldr s2, ={pi}
addw r0, pc, #{}
vmul.f32 s0, s0, s4
orr r1, fp, #4
vld1.64 {d18, d19}, [r0:0x80]
mov.w r0, #0x3f800000
add r5, sp, #0xd0
movs r2, #0
str r0, [sp, #0x150]
movs r3, #0
vst1.32 {d16, d17}, [r1]
add.w r1, fp, #0x18
str r0, [sp, #0x164]
vmul.f32 s0, s0, s2
"""
ANDROID_TRAVEL = """
vmov s0, r8
vcvt.f32.s32 s0, s0
vldr s2, [r4, #0x1e0]
vmul.f32 s0, s0, s2
vcvt.s32.f32 s0, s0
vcvt.f32.s32 s0, s0
"""


def android_flight(lib):
    from .android_shapes import Listing, relocation, vtable_slot
    method = relocation(lib, vtable_slot(lib, '_ZTV13PlayerFighter', 13))
    if method is None:
        return {}
    update = Listing(lib, method[0])
    shapes = {key: update.unique(template) for key, template in [
        ('turn', ANDROID_TURN), ('snap', ANDROID_SNAP), ('sign', ANDROID_SIGN), ('history', ANDROID_HISTORY),
        ('reset', ANDROID_RESET), ('slew', ANDROID_SLEW), ('radians', ANDROID_RADIANS), ('travel', ANDROID_TRAVEL)]}
    shapes['bank'] = Listing(lib, '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb').unique(ANDROID_BANK)
    if None in shapes.values():
        return {}
    history, bank = shapes['history'], shapes['bank']
    samples = history.value('window') // 4
    if not (history.value('samples') == samples == history.value('last') + 1 and history.value('zero_full') == history.value('zero_partial') == 0):
        return {}
    floats = {}
    proof = {'virtual_update': method[1], **{key: shape.span() for key, shape in shapes.items()}}
    for key, block, name in [('turn_scale', 'turn', 'turn_scale'), ('heading_snap_l1', 'snap', 'snap'), ('bank_sign_angle', 'sign', 'sign'),
                             ('bank_slew_divisor', 'slew', 'slew_divisor'), ('bank_angle_scale', 'radians', 'angle_scale'), ('pi', 'radians', 'pi')]:
        word, proof[key] = shapes[block].pool(name)
        floats[key] = struct.unpack('<f', struct.pack('<I', word))[0]
    word = lambda stem: struct.unpack('<f', struct.pack('<I', bank.value(stem + '_high') << 16 | bank.value(stem + '_low')))[0]
    numerator = (1 + (1 << shapes['turn'].value('triple'))) << shapes['turn'].value('scale')
    result = {'turn_numerator': numerator, 'turn_scale': floats['turn_scale'], 'heading_snap_l1': floats['heading_snap_l1'],
              'bank_sign_angle': floats['bank_sign_angle'], 'bank_samples': samples, 'bank_limit': word('limit'),
              'bank_gain': word('gain'), 'bank_slew_numerator': shapes['slew'].value('slew_numerator'),
              'bank_slew_divisor': floats['bank_slew_divisor'], 'bank_angle_scale': floats['bank_angle_scale'], 'pi': floats['pi']}
    # (1 + 2^a) << b is at least 2; NaN and infinities fail the range.
    if numerator > 127 or not all(0 < v <= 100000 for v in result.values()):
        return {}
    if result['heading_snap_l1'] > 1 or result['turn_scale'] > 1 or result['bank_angle_scale'] > 1:
        return {}
    if result['pi'] != struct.unpack('<f', struct.pack('<f', math.pi))[0] or result['bank_sign_angle'] != struct.unpack('<f', struct.pack('<f', math.pi / 2))[0]:
        return {}
    result['provenance'] = proof
    return result


def extract_npc_flight(mach, actors):
    if mach.architecture == 'android-armv7':
        initial = actors.get('npc_initialization')
        return android_flight(mach) if initial and initial.get('activation') else {}
    import capstone
    mac = mach.architecture == 'x86_64'
    if mach.architecture not in LAYOUTS: return {}
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    decoder.detail = True
    proof = {}
    def require(ok):
        if not ok: raise ValueError('Unsupported ordinary NPC flight declaration')
    def address(span):
        offset = span['offset'] - mach.slice_offset
        sections = [s for s in mach.sections if s['offset'] <= offset and offset+span['bytes'] <= s['offset']+s['length']]
        require(len(sections)==1)
        return sections[0]['address']+offset-sections[0]['offset']
    def read(key, at, size, segment=b'__TEXT', name=b'__text'):
        sections = [s for s in mach.sections if s['name']==name and s['segment']==segment and s['address']<=at and at+size<=s['address']+s['length']]
        require(len(sections)==1)
        offset = sections[0]['offset']+at-sections[0]['address']
        raw = mach.data[offset:offset+size]
        require(len(raw)==size)
        proof[key] = {'offset':offset+mach.slice_offset,'bytes':size}
        return raw
    def match(key, at, size, pattern):
        row = template(pattern).fullmatch(read(key,at,size))
        require(row is not None)
        return row
    def instruction(row, key, at, mnemonic, register=None):
        rows = list(decoder.disasm(row[key],at+row.start(key)))
        require(len(rows)==1 and rows[0].size==len(row[key]) and rows[0].mnemonic==mnemonic)
        i = rows[0]
        if register: require(i.reg_name(i.operands[0].reg)==register)
        return i
    def immediate(row, key, at, mnemonic, register):
        i = instruction(row,key,at,mnemonic,register)
        require(i.operands[-1].type==capstone.arm.ARM_OP_IMM)
        return i.operands[-1].imm
    def target(row, key, at):
        return at+row.end(key)+int.from_bytes(row[key],'little',signed=True) if mac else immediate(row,key,at,'bl',None)
    try:
        initial = actors['npc_initialization']
        require(initial and initial['activation'])
        wrapper_at = address(initial['provenance']['actor_wrapper'])
        wrapper = match('actor_wrapper',wrapper_at,14 if mac else 60,MAC_ACTOR_WRAPPER if mac else ARM_ACTOR_WRAPPER)
        constructor = target(wrapper,'constructor',wrapper_at)
        slot = address(initial['activation']['provenance']['virtual_activation'])+(80 if mac else 40)
        pointer = int.from_bytes(read('virtual_update',slot,8 if mac else 4,b'__DATA',b'__const'),'little')
        if not mac: require(pointer&1==1)
        update = pointer if mac else pointer&~1
        bases = {'constructor':constructor,'update':update}
        positions = {}; rows = {}
        for key,(base,delta,size,pattern) in LAYOUTS[mach.architecture].items():
            positions[key] = bases[base]+delta
            rows[key] = match(key,positions[key],size,pattern)
        def literal(block, field, key):
            row = rows[block]; at = positions[block]
            if mac: location = target(row,field,at)
            else:
                register = {'turn':'s0','snap':'s4','sign':'s0','slew':'s8','radians':'s4' if field=='ref_0' else 's2'}[block]
                i = instruction(row,field,at,'vldr',register)
                op = i.operands[-1]
                require(op.type==capstone.arm.ARM_OP_MEM and i.reg_name(op.mem.base)=='pc')
                location = ((i.address+4)&~3)+op.mem.disp
            return struct.unpack('<f',read(key,location,4,name=b'__const' if mac else b'__text'))[0]
        bank = rows['bank']; bank_at = positions['bank']
        def bank_value(key):
            if mac: raw = bank['bank_'+key]
            else:
                stem = 'limit' if key=='limit' else 'gain'
                low = immediate(bank,stem+'_low',bank_at,'movw','r3')
                high = immediate(bank,stem+'_high',bank_at,'movt','r3')
                raw = struct.pack('<I',low+(high<<16))
            return struct.unpack('<f',raw)[0]
        if mac:
            numerator = int.from_bytes(rows['turn']['turn_numerator'],'little',signed=True)
            slew_numerator = literal('slew','ref_5','slew_numerator')
            require(literal('history','ref_33','history_divisor')==5)
            sign_at = target(rows['history'],'ref_c9',positions['history'])
            require(read('sign_mask',sign_at,16,name=b'__const')==struct.pack('<4I',*[0x80000000]*4))
        else:
            numerator = 48  # The recognized integer add/shift expression is 3*16.
            i = instruction(rows['slew'],'slew_numerator',positions['slew'],'vmov.f32','d16')
            require(i.operands[-1].type==capstone.arm.ARM_OP_FP)
            slew_numerator = i.operands[-1].fp
        result = {'turn_numerator':numerator,
                  'turn_scale':literal('turn','ref_b' if mac else 'ref_0','turn_scale'),
                  'heading_snap_l1':literal('snap','ref_0','heading_snap_l1'),
                  'bank_sign_angle':literal('sign','ref_0','bank_sign_angle'),
                  'bank_samples':5,'bank_limit':bank_value('limit'),'bank_gain':bank_value('gain'),
                  'bank_slew_numerator':slew_numerator,
                  'bank_slew_divisor':literal('slew','ref_d' if mac else 'ref_4','bank_slew_divisor'),
                  'bank_angle_scale':literal('radians','ref_0','bank_angle_scale'),
                  'pi':literal('radians','ref_8' if mac else 'ref_6','pi')}
        require(1<=numerator<=127)
        for key,value in result.items(): require(math.isfinite(value) and 0<value<=100000)
        require(result['heading_snap_l1']<=1 and result['turn_scale']<=1 and result['bank_angle_scale']<=1)
        require(result['pi']==struct.unpack('<f',struct.pack('<f',math.pi))[0])
        require(result['bank_sign_angle']==struct.unpack('<f',struct.pack('<f',math.pi/2))[0])
        spans = sorted((r['offset'],r['offset']+r['bytes']) for r in proof.values())
        require(all(a[1]<=b[0] for a,b in zip(spans,spans[1:])))
        result['provenance'] = proof
        return result
    except (ValueError,TypeError,KeyError,IndexError,OverflowError,struct.error): return {}
