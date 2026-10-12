"""Read the geometry-manager refresh clock and its linked batch-selection path.

Android: LODManager's constructor starts the clock at 1001 ms; LODManager::update
adds the elapsed time and, once the clock passes 1000, resets it to 0 and
tail-calls LODManager::forceUpdate(0, false) through a long-branch veneer, which
calls AEGeometry::updateLod for every registered geometry.
"""
import re
import struct
from .opening_loadout import template
from .ship_models import section_bytes

ANDROID_INITIAL = r"""movw r0, #(?P<seed>\w+)
str r1, \[r5, #8\]
str r6, \[r5\]
str r5, \[r4\]
str r0, \[r4, #0x10\]
"""
ANDROID_TICK = r"""ldr r2, \[r0, #0x10\]
add r1, r2
str r1, \[r0, #0x10\]
cmp\.w r1, #(?P<threshold>\w+)
it le
bxle lr
movs r1, #0
movs r2, #0
str r1, \[r0, #0x10\]
b\.w #(?P<jump>\w+)
"""
ANDROID_BATCH = r"""mov sb, r0
ldr r0, =\w+
mov r8, r2
ldr r2, =\w+
adr r0, \w+
ldr r1, =\w+
adr r2, \w+
ldr r0, \[r0\]
adr r1, \w+
ldr r2, \[r2\]
ldr r1, \[r1\]
ldr r0, \[r0\]
str r0, \[sp, #0xc\]
ldr r4, \[r2\]
vldr s16, \[r1, #0x28\]
mov r0, r4
call _ZN11AbyssEngine11PaintCanvas16CameraGetCurrentEv
mov r1, r0
mov r0, r4
call _ZN11AbyssEngine11PaintCanvas14CameraGetLocalEj
mov r4, sp
mov r1, r0
mov r0, r4
call _ZN11AbyssEngine6AEMath17MatrixGetPositionERKNS0_6MatrixE
add\.w fp, sb, #4
mov r1, r4
mov r0, fp
call _ZN11AbyssEngine6AEMath6VectoraSERKS1_
ldr\.w r0, \[sb\]
ldr r1, \[r0\]
cbz r1, #(?P<done>\w+)
vmov r5, s16
movs r6, #0
mov sl, sp
(?P<loop>ldr r0, \[r0, #4\])
cmp\.w r8, #1
ldr\.w r4, \[r0, r6, lsl #2\]
bne #(?P<own>\w+)
mov r0, sl
mov r1, r4
call _ZN10AEGeometry17getParentPositionEv
b #(?P<update>\w+)
(?P<camera>vldr d16, \[fp\])
ldr\.w r0, \[fp, #8\]
str r0, \[sp, #8\]
vstr d16, \[sp\]
(?P<call>mov r0, r4)
mov r1, sl
mov r2, r5
call _ZN10AEGeometry9updateLodERKN11AbyssEngine6AEMath6VectorEf
ldr\.w r0, \[sb\]
adds r6, #1
ldr r1, \[r0\]
cmp r6, r1
blo #(?P<next>\w+)
"""
# bx pc ; nop ; ldr ip, [pc] ; add pc, ip, pc ; then the offset word (from the add's pc).
VENEER = bytes.fromhex('7847c04600c09fe50ff08ce0')
UPDATE_LOD = '_ZN10AEGeometry9updateLodERKN11AbyssEngine6AEMath6VectorEf'


def android_refresh(lib, lod):
    from .android_listing import Listing, names, number
    initial, tick, batch = (Listing(lib, name) for name in ('_ZN10LODManagerC1Ev', '_ZN10LODManager6updateEi',
                                                            '_ZN10LODManager11forceUpdateEib'))
    seeds, loops = initial.find(ANDROID_INITIAL), batch.find(ANDROID_BATCH)
    clock = re.match(ANDROID_TICK, tick.text)
    if len(seeds) != 1 or len(loops) != 1 or not clock:
        return {}
    seed, loop = seeds[0], loops[0]
    at = lambda m, name: batch.code[batch.index(m, name)].address
    last = batch.code[batch.last(loop)]
    veneer = section_bytes(lib, number(clock['jump']), 16, b'__text')
    target = number(clock['jump']) + 16 + struct.unpack('<i', veneer[0][12:])[0] if veneer else None
    # The selector the batch calls holds the ship LOD cull.
    start, size = lib.symbols.get(UPDATE_LOD, (0, 0))
    cull = lod['provenance']['cull']['offset'] - lib.text['offset'] + lib.text['address']
    if (not veneer or veneer[0][:12] != VENEER
            or (lib.imports.get(target) or names(lib).get(target & ~1)) != '_ZN10LODManager11forceUpdateEib'
            or number(loop['next']) != at(loop, 'loop') or number(loop['own']) != at(loop, 'camera')
            or number(loop['update']) != at(loop, 'call') or number(loop['done']) != last.address + last.size
            or not start <= cull < start + size):
        return {}
    threshold = number(clock['threshold'])
    if threshold >= 1000000:
        return {}
    return {'initial_milliseconds': number(seed['seed']), 'refresh_at_milliseconds': threshold + 1, 'reset_milliseconds': 0,
            'time_unit': 'milliseconds', 'forced_refresh_resets_clock': False,
            'provenance': {'initial': initial.match_span(seed), 'tick': tick.match_span(clock), 'batch': batch.match_span(loop)}}


def extract_lod_refresh(mach, lod):
    if not lod: return {}
    if mach.architecture == 'android-armv7': return android_refresh(mach, lod)
    if mach.architecture not in ['x86_64','armv7']: return {}
    import capstone
    mac=mach.architecture=='x86_64';prefix='MAC_' if mac else 'ARM_';text=mach.text
    base=text['address'];file_base=text['offset']+mach.slice_offset
    code=mach.data[text['offset']:text['offset']+text['length']]
    decoder=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);decoder.detail=True
    provenance={}
    def require(ok):
        if not ok: raise ValueError('Unsupported LOD refresh context')
    def instruction(m,key):
        rows=list(decoder.disasm(m[key],base+m.start(key)));require(len(rows)==1 and rows[0].size==len(m[key]));return rows[0]
    def find(key):
        name=prefix+key.upper();matches=[m for m in template(globals()[name]).finditer(code) if mac or m.start()%2==0]
        require(len(matches)==1);m=matches[0]
        if not mac:
            for field,expected in ARM_FIELDS[name].items():
                i=instruction(m,field);require(i.mnemonic==expected['kind'])
                if 'register' in expected: require(i.reg_name(i.operands[0].reg)==expected['register'])
        provenance[key]={'offset':file_base+m.start(),'bytes':len(m[0])};return m
    def target(m,key):
        return base+m.end(key)+int.from_bytes(m[key],'little',signed=True) if mac else instruction(m,key).operands[0].imm
    try:
        initial=find('initial');tick=find('tick');batch=find('batch')
        require(initial.end()<batch.start()<batch.end()<=tick.start())
        require(tick.end()-initial.start()<1024)
        require(target(tick,'jump_1e' if mac else 'jump_14')==base+batch.start())
        seed=int.from_bytes(initial['seed'],'little',signed=True) if mac else instruction(initial,'word_6').operands[1].imm
        threshold=int.from_bytes(tick['threshold'],'little',signed=True) if mac else instruction(tick,'word_6').operands[1].imm+1
        selector=target(batch,'call_bf' if mac else 'call_8a')
        cull=lod['provenance']['cull']['offset']-file_base+base
        require(selector<=cull<selector+512)
        require(0<threshold<=1000000 and 0<=seed<=1000000)
        return {'initial_milliseconds':seed,'refresh_at_milliseconds':threshold,'reset_milliseconds':0,
                'time_unit':'milliseconds','forced_refresh_resets_clock':False,'provenance':provenance}
    except (ValueError,KeyError,IndexError,TypeError,OverflowError): return {}

MAC_INITIAL = """
49891e41c74614
{seed:4}
"""

MAC_TICK = """
554889e503771489771481fe
{threshold:4}
7d025dc3c747140000000031d25de9
{jump_1e:4}
"""

MAC_BATCH = """
554889e54157415641554154534883ec2889d34989fe488d05
{ref_16:4}
f30f104028f30f1145b4488d05
{ref_27:4}
4c8b384c89ffe8
{call_34:4}
4c89ff89c6e8
{call_3e:4}
4889c7e8
{call_46:4}
4d8d7e08488d75c8f30f114dd0f30f1145c8660f70c001f30f1145cc4c89ffe8
{call_6a:4}
498b0683380074584531e4488b40084e8b2ce080fb01751e4c89efe8
{call_8a:4}
f30f114dc0f30f1145b8660f70c001f30f1145bceb0e418b47088945c0498b07488945b84c89ef488d75b8f30f1045b4e8
{call_bf:4}
498b0649ffc4443b2072ab4883c4285b415c415d415e415f5dc3
"""

ARM_INITIAL = """
0298019c0260
{word_6:4}
21602061
"""

ARM_TICK = """
026911440161
{word_6:4}
d8bf7047002100220161
{jump_14:4}
"""

ARM_BATCH = """
f0b503af2de9000d2ded028b86b08246
{word_10:4}
{word_14:4}
{word_18:4}
{word_1c:4}
7844794490460068096890ed0a8a0c682046
{call_32:4}
01462046
{call_3a:4}
03ac01462046
{call_44:4}
0af1040621463046
{call_50:4}
daf800000168f1b10024eb464068b8f1010f50f8245004d158462946
{call_70:4}
05e0d6ed000bb0680290cded000b18ee102a28465946
{call_8a:4}
daf80000013401688c42e2d306b0bdec028bbde8000df0bd00bf
"""

ARM_FIELDS = {'ARM_INITIAL': {'word_6': {'kind': 'movw', 'register': 'r0'}}, 'ARM_TICK': {'word_6': {'kind': 'cmp.w', 'register': 'r1'}, 'jump_14': {'kind': 'b.w'}}, 'ARM_BATCH': {'word_10': {'kind': 'movw', 'register': 'r0'}, 'word_14': {'kind': 'movt', 'register': 'r0'}, 'word_18': {'kind': 'movw', 'register': 'r1'}, 'word_1c': {'kind': 'movt', 'register': 'r1'}, 'call_32': {'kind': 'bl'}, 'call_3a': {'kind': 'bl'}, 'call_44': {'kind': 'bl'}, 'call_50': {'kind': 'bl'}, 'call_70': {'kind': 'bl'}, 'call_8a': {'kind': 'bl'}}}
