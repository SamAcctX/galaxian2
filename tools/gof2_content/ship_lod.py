"""Read ordinary ship LOD declarations and bounded distance-selection contexts.

Only declarative mesh IDs, thresholds and provenance survive import. Special hull
factories and the owner of the source reference position/detail input are separate.

Android: Globals::getShipGroup's ordinary path counts the used body and child
ids of the ship's rows (two of three u32 columns, 0xffff = none), gives them
distances from 5000 in steps of 8000 through AEGeometry::setLodMeshes (or
setLodMeshesWithMeshIds) and setLodChildMeshes, and limits the last visible
distance through setLodLastVisibleDistance; both setters square the distances.
AEGeometry::updateLod culls at or beyond that limit and scales the distances by
the detail factor before comparing. Its selection loop starts at a constant 0
instead of the mesh count, so Android never selects a reduced mesh.
"""
import math
import struct
from .opening_loadout import template
from .ship_models import section_bytes


ANDROID_BODY = r"""ldr r0, =\w+
add\.w (?P<row>\w+), (?P<index>\w+), (?P=index), lsl #1
movs r1, #0
movw r2, #0xffff
adr r0, (?P<table>\w+)
mov\.w (?P<count>\w+), #0
add\.w r0, r0, (?P=row), lsl #2
(?P<head>ldr\.w r4, \[r0, r1, lsl #2\])
mov r6, (?P=count)
adds r5, r6, #1
adds r1, #1
cmp r4, r2
it ne
movne (?P=count), r5
cmp r1, #2
bne #(?P<loop>\w+)
cmp\.w (?P=count), #0
ble\.w #(?P<none>\w+)
"""
ANDROID_FILL = r"""ldr r0, =\w+
movw r1, #0xffff
cmp r4, r1
adr r0, (?P<table>\w+)
movw r1, #0x7dc8
(?P<add>add\.w r2, r0, (?P<row>\w+), lsl #2)
ldr r0, =\w+
add r1, sb
it ne
movne r6, r5
adr r0, \w+
str\.w (?P=row), \[sp, #8\]
str r3, \[sp, #0x24\]
movw (?P<distance>\w+), #(?P<seed>\w+)
ldr r0, \[r0\]
mov\.w (?P<offset>\w+), #0
str r0, \[sp, #0x1c\]
uxth r0, r1
str r0, \[sp, #0x14\]
str r2, \[sp, #0x18\]
ldr r4, \[sp, #0x10\]
ldr r0, \[sp, #0x28\]
ldrd sb, r5, \[sp, #0x1c\]
(?P<head>ldr\.w r1, \[r2, (?P=offset)\])
cmp r0, #0
strh r1, \[r4\]
str\.w (?P=distance), \[r3, (?P=offset)\]
bne #(?P<skip>\w+)
"""
ANDROID_STEP = r"""subs r6, #1
add\.w (?P<offset>\w+), (?P=offset), #4
add\.w (?P<distance>\w+), (?P=distance), #(?P<increment>\w+)
add\.w r4, r4, #2
bne #(?P<loop>\w+)
cmp r0, #0
beq\.w #(?P<ids>\w+)
ldr\.w fp, \[sp, #0xc\]
mov r2, r3
ldr\.w sb, \[sp, #0x10\]
mov r3, sl
mov r0, fp
mov r1, sb
call _ZN10AEGeometry12setLodMeshesEPtPii
b #(?P<done>\w+)
"""
ANDROID_STEP_IDS = r"""ldr\.w fp, \[sp, #0xc\]
ldr\.w sb, \[sp, #0x10\]
ldr r2, \[sp, #0x20\]
mov r0, fp
str\.w sl, \[sp\]
mov r1, sb
call _ZN10AEGeometry23setLodMeshesWithMeshIdsEPtPjPii
"""
ANDROID_CHILD = r"""ldr r0, =\w+
movs r2, #0
ldr\.w (?P<row>\w+), \[sp, #8\]
movw r6, #0xffff
adr r0, (?P<table>\w+)
movs r1, #0
add\.w r0, r0, (?P=row), lsl #2
(?P<head>ldr\.w r4, \[r0, r2, lsl #2\])
mov r5, r1
adds r3, r5, #1
adds r2, #1
cmp r4, r6
it ne
movne r1, r3
cmp r2, #2
bne #(?P<loop>\w+)
cmp r1, #0
ble #(?P<none>\w+)
"""
ANDROID_CHILD_COPY = r"""movw r0, #0xffff
cmp r4, r0
add\.w r0, r1, r1
it ne
movne r5, r3
cmp r0, r1
it lo
movlo\.w r0, #-1
call _Znaj
mov r4, r0
ldr r0, =\w+
movs r1, #0
adr r0, (?P<table>\w+)
add\.w r0, r0, (?P<row>\w+), lsl #2
(?P<head>ldr\.w r2, \[r0, r1, lsl #2\])
strh\.w r2, \[r4, r1, lsl #1\]
adds r1, #1
cmp r5, r1
bne #(?P<loop>\w+)
mov r0, fp
mov r1, r4
call _ZN10AEGeometry17setLodChildMeshesEPt
mov r0, r4
call _ZdaPv
"""
ANDROID_LIMIT = r"""mov r0, sb
call _ZdaPv
ldr r0, \[sp, #0x24\]
call _ZdaPv
(?P<set>movw r2, #(?P<low>\w+))
mov r0, fp
movt r2, #(?P<high>\w+)
movs r3, #0
call _ZN10AEGeometry25setLodLastVisibleDistanceEy
"""
ANDROID_SETTER = """umull ip, r1, r2, r2
mla r1, r2, r3, r1
mla r1, r2, r3, r1
strd ip, r1, [r0, #0x70]
bx lr
"""
ANDROID_SQUARE = r"""ldr(?:\.w)? r0, \[\w+, #0x64\]
add\.w r2, r0, (?P<i>\w+), lsl #3
ldr\.w r1, \[r0, (?P=i), lsl #3\]
ldr r3, \[r2, #4\]
umull r6, r5, r1, r1
mla r5, r1, r3, r5
str\.w r6, \[r0, (?P=i), lsl #3\]
mla r1, r1, r3, r5
str r1, \[r2, #4\]
"""
ANDROID_CULL = r"""vldr s0, \[fp, #0x78\]
vldr s2, \[fp, #0x7c\]
vmul\.f32 s0, s0, s0
vldr s4, \[fp, #0x80\]
vmul\.f32 s2, s2, s2
vmul\.f32 s4, s4, s4
vadd\.f32 s0, s0, s2
vadd\.f32 s0, s0, s4
vmov r0, s0
call __aeabi_f2ulz
strd r0, r1, \[fp, #0x68\]
ldrd r3, r2, \[fp, #0x70\]
orrs\.w r6, r3, r2
beq #(?P<unlimited>\w+)
subs r0, r0, r3
mov\.w r6, #0
sbcs\.w r0, r1, r2
it lo
movlo r6, #1
strb\.w r6, \[fp, #0x48\]
cmp r6, #0
beq\.w #(?P<hidden>\w+)
"""
ANDROID_DETAIL = r"""ldr\.w r1, \[fp, #0xc\]
(?P<input>vmov s18, r8)
ldr\.w r0, \[fp, #0x2c\]
add\.w r6, fp, #0x68
call _ZN11AbyssEngine11PaintCanvas21TransformGetTransformEj
(?P<high_load>vldr s2, =(?P<high>\w+))
vmov\.f32 s4, #(?P<middle>\S+)
vmov\.f32 s0, #(?P<last>\S+)
mvn r1, #7
vcmpe\.f32 s18, s2
(?P<low_load>vldr s2, =(?P<low>\w+))
vmrs apsr_nzcv, fpscr
vmov\.f32 s16, #(?P<first>\S+)
vcmpe\.f32 s18, s2
it ls
vmovls\.f32 s0, s4
vmrs apsr_nzcv, fpscr
mov\.w r5, #0
add\.w r4, r1, r5, lsl #3
it hi
vmovhi\.f32 s16, s0
ldrd sl, sb, \[r0, #0x110\]
"""
ANDROID_SELECT = r"""cmp r5, #1
blt #\w+
ldr\.w r0, \[fp, #0x64\]
subs r5, #1
adds r1, r0, r4
ldr r0, \[r0, r4\]
ldr r1, \[r1, #4\]
call __aeabi_ul2f
vmov s0, r0
ldrd r0, r1, \[r6\]
vmul\.f32 s18, s16, s0
call __aeabi_ul2f
vmov s0, r0
subs r4, #8
vcmpe\.f32 s0, s18
vmrs apsr_nzcv, fpscr
ble #(?P<loop>\w+)
"""


def android_lod(lib, count):
    from .android_listing import Listing, number, word_float
    group = Listing(lib, '_ZN7Globals12getShipGroupEiib')
    update = Listing(lib, '_ZN10AEGeometry9updateLodERKN11AbyssEngine6AEMath6VectorEf')
    setter = Listing(lib, '_ZN10AEGeometry25setLodLastVisibleDistanceEy')
    plain = Listing(lib, '_ZN10AEGeometry12setLodMeshesEPtPii')
    ids = Listing(lib, '_ZN10AEGeometry23setLodMeshesWithMeshIdsEPtPjPii')
    parts = {}
    for key, listing, shape in [('body', group, ANDROID_BODY), ('fill', group, ANDROID_FILL), ('step', group, ANDROID_STEP),
                                ('step_ids', group, ANDROID_STEP_IDS), ('child', group, ANDROID_CHILD),
                                ('child_copy', group, ANDROID_CHILD_COPY), ('limit', group, ANDROID_LIMIT),
                                ('square', plain, ANDROID_SQUARE), ('square_ids', ids, ANDROID_SQUARE),
                                ('cull', update, ANDROID_CULL), ('detail', update, ANDROID_DETAIL), ('select', update, ANDROID_SELECT)]:
        found = listing.find(shape)
        if len(found) != 1:
            return {}
        parts[key] = found[0]
    if not setter.text.startswith(ANDROID_SETTER):
        return {}
    body, fill, step, step_ids, child, copy, limit = (parts[k] for k in ('body', 'fill', 'step', 'step_ids', 'child', 'child_copy', 'limit'))
    cull, detail, select = parts['cull'], parts['detail'], parts['select']

    def address(listing, m, group_name=0):
        return listing.code[listing.index(m, group_name)].address

    def end(listing, m):
        last = listing.code[listing.last(m)]
        return last.address + last.size

    # The fill reads the body row (index * 3 words) again; the step continues the fill's loop.
    moved = group.definition(group.index(fill, 'add'), fill['row'])
    detail_input = update.definition(update.index(detail, 'input'), 'r8')
    if (moved is None or group.lines[moved] != 'mov %s, %s' % (fill['row'], body['row'])
            or group.definition(moved, body['row']) != group.index(body, 'row')
            or number(body['table']) != number(fill['table']) or number(child['table']) != number(copy['table'])
            or child['row'] != copy['row'] or step['offset'] != fill['offset'] or step['distance'] != fill['distance']
            or number(body['loop']) != address(group, body, 'head') or number(fill['skip']) != address(group, step)
            or number(step['loop']) != address(group, fill, 'head') or number(step['ids']) != address(group, step_ids)
            or number(step['done']) != address(group, child) or end(group, step_ids) != address(group, child)
            or end(group, child) != address(group, copy) or number(child['loop']) != address(group, child, 'head')
            or number(copy['loop']) != address(group, copy, 'head') or end(group, copy) != address(group, limit)
            or number(child['none']) != address(group, limit) or number(body['none']) != address(group, limit, 'set')
            or number(cull['unlimited']) != address(update, detail) or end(update, cull) != address(update, detail)
            or end(update, detail) != address(update, select) or number(select['loop']) != address(update, select)
            or update.lines[update.at(number(cull['hidden'])):][:2] != ['mov.w r0, #-1', 'str.w r0, [fp, #0x28]']
            or detail_input is None or update.lines[detail_input] != 'mov r8, r2'):
        return {}
    spans = {key: listing.match_span(parts[key]) for key, listing in [
        ('body', group), ('fill', group), ('step', group), ('step_ids', group), ('child', group), ('child_copy', group),
        ('limit', group), ('square', plain), ('square_ids', ids), ('cull', update), ('detail', update), ('select', update)]}
    spans['limit_setter'] = setter.span(0, ANDROID_SETTER.count('\n') - 1)
    for key, name in [('detail_low', 'low_load'), ('detail_high', 'high_load')]:
        load = update.code[update.index(detail, name)]
        spans[key] = {'offset': lib.text['offset'] + ((load.address + 4) & ~3) + load.operands[1].mem.disp - lib.text['address'],
                      'bytes': 4}
    seed, increment = number(fill['seed']), number(step['increment'])
    maximum = number(limit['low']) + (number(limit['high']) << 16)
    boundaries = [word_float(number(detail['low'])), word_float(number(detail['high']))]
    factors = [number(detail[k]) for k in ('first', 'middle', 'last')]
    if (not 0 < seed < seed + increment < maximum <= 1000000
            or not all(0 < v <= 1 for v in boundaries + factors)
            or boundaries != sorted(set(boundaries)) or factors != sorted(set(factors))):
        return {}
    tables = []
    for key, table in [('body_table', body['table']), ('child_table', child['table'])]:
        found = section_bytes(lib, number(table), count * 12, b'__const')
        if found is None:
            return {}
        spans[key] = {'offset': found[1], 'bytes': count * 12}
        rows = [list(struct.unpack_from('<2I', found[0], i * 12)) for i in range(count)]
        if not all(v <= 65535 for row in rows for v in row) or any(row[0] == 65535 and row[1] != 65535 for row in rows):
            return {}
        tables.append(rows)
    if not all(all(v == 65535 for v in c) or sum(v != 65535 for v in c) == sum(v != 65535 for v in b) for b, c in zip(*tables)):
        return {}
    return {'body_resource_ids': tables[0], 'child_resource_ids': tables[1], 'distances': [seed, seed + increment],
            'maximum_distance': maximum, 'detail_boundaries': boundaries, 'squared_distance_factors': factors,
            'threshold_comparison': 'greater', 'maximum_comparison': 'greater_or_equal', 'provenance': spans}


def extract_ship_lod(mach, models, lights):
    count = len(models.get('resource_ids', []))
    if not lights or not 1 <= count <= 64: return {}
    if mach.architecture == 'android-armv7': return android_lod(mach, count)
    if mach.architecture not in ['x86_64','armv7']: return {}
    import capstone
    mac = mach.architecture == 'x86_64'; prefix = 'MAC_' if mac else 'ARM_'
    text = mach.text; base = text['address']; file_base = text['offset'] + mach.slice_offset
    code = mach.data[text['offset']:text['offset']+text['length']]
    decoder = capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB); decoder.detail=True
    provenance = {}
    def require(ok):
        if not ok: raise ValueError('Unsupported ship LOD declaration')
    def instruction(m,key):
        rows=list(decoder.disasm(m[key],base+m.start(key)))
        require(len(rows)==1 and rows[0].size==len(m[key])); return rows[0]
    def find(key):
        name=prefix+key.upper(); matches=[m for m in template(globals()[name]).finditer(code) if mac or m.start()%2==0]
        if key in ['body','fill','step','child','child_copy','limit']:
            root=lights['provenance'][0]['offset']; matches=[m for m in matches if root<=file_base+m.start()<file_base+m.end()<=root+2400]
        require(len(matches)==1); m=matches[0]
        if not mac:
            for field,expected in ARM_FIELDS[name].items():
                i=instruction(m,field);require(i.mnemonic==expected['kind'])
                if 'register' in expected: require(i.reg_name(i.operands[0].reg)==expected['register'])
        provenance[key]={'offset':file_base+m.start(),'bytes':len(m[0])};return m
    def reference(m,key): return base+m.end(key)+int.from_bytes(m[key],'little',signed=True)
    def pair(m,low,high,pc):
        return instruction(m,low).operands[1].imm+(instruction(m,high).operands[1].imm<<16)+base+m.start()+pc+4
    def extent(key,address,size,section):
        found=section_bytes(mach,address,size,section);require(found is not None)
        provenance[key]={'offset':found[1],'bytes':size};return found[0]
    try:
        parts={key:find(key) for key in ['body','fill','step','child','child_copy','limit','select','cull','square']}
        root=lights['provenance'][0];begin=root['offset'];end=begin+2400
        ordered=[parts[k] for k in ['body','fill','step','child','child_copy','limit']]
        require(all(begin<=file_base+m.start()<file_base+m.end()<=end for m in ordered))
        require(all(a.end()<=b.start() for a,b in zip(ordered,ordered[1:])))
        body=parts['body'];fill=parts['fill'];step=parts['step'];child=parts['child'];copy=parts['child_copy'];limit=parts['limit']
        if mac:
            body_address=reference(body,'ref_b');require(body_address==reference(fill,'ref_0'))
            child_address=reference(child,'ref_0');require(child_address==reference(copy,'ref_0'))
            seed=int.from_bytes(fill['value'],'little',signed=True);increment=int.from_bytes(step['value'],'little',signed=True)
            maximum=int.from_bytes(limit['value'],'little',signed=True)
            helper=reference(step,'call_3d');setter=reference(limit,'call_8')
            expected=bytes.fromhex('554889e5480faff64889b7980000005dc3')
            detail=find('detail')
            require(parts['cull'].end()==detail.start() and detail.end()<=parts['select'].start())
            low=struct.unpack('<f',extent('detail_low',reference(detail,'ref_0'),4,b'__const'))[0]
            high=struct.unpack('<f',extent('detail_high',reference(detail,'ref_1f'),4,b'__const'))[0]
            first=struct.unpack('<f',extent('detail_first',reference(detail,'ref_15'),4,b'__const'))[0]
            last,middle=struct.unpack('<2f',extent('detail_pair',reference(detail,'ref_30'),8,b'__const'))
            boundaries=[low,high];factors=[first,middle,last]
        else:
            body_address=pair(body,'word_0','word_8',16)
            require(instruction(body,'word_c').operands[1].imm==65535)
            child_address=pair(child,'word_0','word_6',12)
            require(instruction(child,'word_e').operands[1].imm==65535)
            seed=instruction(fill,'word_c').operands[1].imm;increment=instruction(step,'word_6').operands[2].imm
            maximum=instruction(limit,'word_2').operands[1].imm+(instruction(limit,'word_a').operands[1].imm<<16)
            helper=instruction(step,'call_26').operands[0].imm;setter=instruction(limit,'call_14').operands[0].imm
            require(instruction(parts['select'],'call_10').operands[0].imm==instruction(parts['select'],'call_1a').operands[0].imm)
            expected=bytes.fromhex('b0b5a1fb014302af01fb023301fb0235c0e91c45b0bd')
            boundaries=[];factors=[1.0]
        require(helper<=base+parts['square'].start()<helper+512)
        require(parts['cull'].end()<=parts['select'].start()<=parts['cull'].end()+300)
        require(extent('limit_setter',setter,len(expected),b'__text')==expected)
        require(0<seed<seed+increment<maximum<=1000000)
        require(all(math.isfinite(v) and 0<v<=1 for v in factors+boundaries))
        require(boundaries==sorted(set(boundaries)) and factors==sorted(set(factors)))
        tables=[]
        for key,address in [('body_table',body_address),('child_table',child_address)]:
            raw=extent(key,address,count*12,b'__const');rows=[list(struct.unpack_from('<2I',raw,i*12)) for i in range(count)]
            require(all(0<=v<=65535 for row in rows for v in row))
            require(all(row[0]!=65535 or row[1]==65535 for row in rows));tables.append(rows)
        require(all(all(v==65535 for v in child_row) or sum(v!=65535 for v in child_row)==sum(v!=65535 for v in body_row) for body_row,child_row in zip(*tables)))
        return {'body_resource_ids':tables[0],'child_resource_ids':tables[1], 'distances':[seed,seed+increment],
                'maximum_distance':maximum,'detail_boundaries':boundaries,'squared_distance_factors':factors,
                'threshold_comparison':'greater','maximum_comparison':'greater_or_equal','provenance':provenance}
    except (ValueError,KeyError,IndexError,TypeError,OverflowError,struct.error): return {}

MAC_BODY = """
4b8d0c7648898d88feffff488d05
{ref_b:4}
488d04884531f631c94589f58b1c8881fbffff00000f95c2440fb6f24501ee48ffc183f90275e2
"""

MAC_FILL = """
488d05
{ref_0:4}
488b8d88feffff488d0488488985a0feffff8b859cfeffff05c87d00004531ffbb
{value:4}
0fb7c089859cfeffff488b85a0feffff66428b04b8664289047a43891cb8
"""

MAC_STEP = """
81c3
{value:4}
4983c40449ffc74539fd488b95b0feffff4c8b85a8feffff75948b85bcfeffff3c01751a4c8bad90feffff4c89ef4889d64c89c24489f1e8
{call_3d:4}
"""

MAC_CHILD = """
488d05
{ref_0:4}
488b8d88feffff488d0c8831c031d24189c78b1c9181fbffff00000f95c00fb6c04401f848ffc283fa0275e3
"""

MAC_CHILD_COPY = """
488d05
{ref_0:4}
81fbffff0000488b8d88feffff4c8d24880f95c00fb6c04101c731db66418b049c664189045e4c89ef4c89f6e8
{call_33:4}
48ffc34139df75e3
"""

MAC_LIMIT = """
4c89efbe
{value:4}
e8
{call_8:4}
"""

MAC_DETAIL = """
f30f1005
{ref_0:4}
f30f108d50ffffff0f2ec1720af30f1005
{ref_15:4}
eb1df30f1005
{ref_1f:4}
0f2ec10f93c00fb6c0488d0d
{ref_30:4}
f30f100481f30f118550ffffff
"""

MAC_SELECT = """
498b8d880000004801c1488b0cd94885c979184889ca48d1ea4883e1014809d1f3480f2ac1f30f58c0eb05f3480f2ac1498b8d90000000f30f598550ffffff4885c979184889ca48d1ea4883e1014809d1f3480f2ac9f30f58c9eb05f3480f2ac94c8d73ff0f2ec876874a8d04a500000000490345688b7498fc
"""

MAC_CULL = """
49898590000000498b8d980000004885c974194839c80f92c041884558720d41c74530ffffffffe9d3010000
"""

MAC_SQUARE = """
498b8688000000488b0c58480fafc948890c58
"""

ARM_BODY = """
{word_0:4}
0aeb4a02
{word_8:4}
{word_c:4}
7844002600eb82030020cdf814a053f82040b2460af1010501308c4218bf2e460228f4d10793
"""

ARM_FILL = """
05990346
{word_4:4}
079a0844
{word_c:4}
4546069380b20590099852f82b1043f82b4020f81b10
"""

ARM_STEP = """
0bf1010b0435
{word_6:4}
da45d4d10a98012840f0a3804ff0ff3149984b911a4609999a463346
{call_26:4}
"""

ARM_CHILD = """
{word_0:4}
0023
{word_6:4}
04997844
{word_e:4}
00eb8105002155f823200e46701c0133a24218bf0146022bf5d1
"""

ARM_CHILD_COPY = """
55f8240028f814000134a642f8d149984ff0ff314b914146
{call_18:4}
"""

ARM_LIMIT = """
499c
{word_2:4}
4ff0ff30
{word_a:4}
4b9000222046
{call_14:4}
"""

ARM_SELECT = """
dbf86400013e00eb080150f808004968
{call_10:4}
0546d4e90001
{call_1a:4}
40ec100ba8f1080845ec115bb4eec10af1ee10fae3dd
"""

ARM_CULL = """
cbe91a01dbe91c2352ea030610d090424ff000004ff0000638bf0120994238bf012608bf06468bf84860002e00f07e80
"""

ARM_SQUARE = """
706e00eb080250f808105368a1fb015401fb034440f8085001fb03415160
"""

ARM_FIELDS = {'ARM_BODY': {'word_0': {'kind': 'movw', 'register': 'r0'}, 'word_8': {'kind': 'movt', 'register': 'r0'}, 'word_c': {'kind': 'movw', 'register': 'r1'}}, 'ARM_FILL': {'word_4': {'kind': 'movw', 'register': 'r0'}, 'word_c': {'kind': 'movw', 'register': 'r4'}}, 'ARM_STEP': {'word_6': {'kind': 'add.w', 'register': 'r4'}, 'call_26': {'kind': 'bl'}}, 'ARM_CHILD': {'word_0': {'kind': 'movw', 'register': 'r0'}, 'word_6': {'kind': 'movt', 'register': 'r0'}, 'word_e': {'kind': 'movw', 'register': 'r4'}}, 'ARM_CHILD_COPY': {'call_18': {'kind': 'bl'}}, 'ARM_LIMIT': {'word_2': {'kind': 'movw', 'register': 'r1'}, 'word_a': {'kind': 'movt', 'register': 'r1'}, 'call_14': {'kind': 'bl'}}, 'ARM_SELECT': {'call_10': {'kind': 'blx'}, 'call_1a': {'kind': 'blx'}}, 'ARM_CULL': {}, 'ARM_SQUARE': {}}
