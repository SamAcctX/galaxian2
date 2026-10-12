"""Recover hangar declarations with bounded, independently checked access patterns.

Only constants, catalogue selectors and source offsets are emitted. These readers
recognize supported compiler layouts; they neither execute nor translate routines.
The returned geometry is not a complete scene (lights/cameras remain separate).

Android: Level::createScene picks the hangar row by station 101, station 100,
else the system's race, reads four ids per row from a 16-byte-row table, turns
each layer by a constant Y rotation and adds the row's extra meshes from a
first-id and a count table.
"""
import math
import re
import struct

from .ship_models import section_bytes


def one(pattern, data):
    matches = list(re.finditer(pattern, data, re.S))
    return matches[0] if len(matches) == 1 else None


def integers(mach, address, count):
    value = section_bytes(mach, address, count * 4, b'__const')
    return (list(struct.unpack('<' + str(count) + 'i', value[0])), value[1]) if value else None


def getter(mach, address, expected):
    value = section_bytes(mach, address, len(expected), b'__text')
    return value is not None and value[0] == expected


def mac_access(mach, code, start, address):
    # This bounded layout carries the same row through selector, root table and
    # extra mesh loops. Relocations vary; register/data-flow relationships do not.
    begin = start - 416
    if begin < 0:
        return None
    window = code[begin:start + 320]
    origin = address + begin
    selector = one(rb'\xe8(.{4})\xb9(.{4})\x83\xf8(.)\x74(.)'
                   rb'\x48\x8d\x05.{4}\x48\x8b\x38\xe8.{4}\x48\x89\xc7\xe8(.{4})'
                   rb'\xb9(.{4})\x83\xf8(.)\x74(.)'
                   rb'\x48\x8d\x05.{4}\x48\x8b\x38\xe8.{4}\x48\x89\xc7\xe8(.{4})\x89\xc1\x41\x89\xcc', window)
    rotation = one(rb'\xc7\x45\xc8\x00{4}\xc7\x45\xcc(.{4})\xc7\x45\xd0\x00{4}\x4c\x89\xef\x48\x8d\x75\xc8\xe8.{4}', window)
    counts = one(rb'\x48\x8d\x05(.{4})\x46\x8b\x3c\xb0\x45\x31\xe4', window)
    extras = one(rb'\x48\x8d\x05(.{4})\x42\x8b\x04\xb0\x44\x01\xe0\x0f\xb7\xf0', window)
    # Same selector passed to the four-column loop (signed -1 means absent).
    flow = bytes.fromhex('44 89 e3 89 5d b0 4c 63 f3') in window
    if not all((selector, rotation, counts, extras, flow)):
        return None
    def call_target(group):
        return origin + selector.start(group) + 4 + struct.unpack('<i', selector[group])[0]
    if not all(getter(mach, call_target(n), bytes.fromhex('554889e58b47105dc3')) for n in (1, 5)) \
            or not getter(mach, call_target(9), bytes.fromhex('554889e58b47285dc3')):
        return None
    # Both station comparisons must jump to the single selector join.
    join = selector.end() - 3
    for n in (4, 8):
        if selector.start(n) + 1 + struct.unpack('<b', selector[n])[0] != join:
            return None
    result = {'station_overrides': [
        {'station_id': selector[3][0], 'row': struct.unpack('<I', selector[2])[0]},
        {'station_id': selector[7][0], 'row': struct.unpack('<I', selector[6])[0]}],
        'rotation_y': struct.unpack('<f', rotation[1])[0],
        'counts_address': origin + counts.start() + 7 + struct.unpack('<i', counts[1])[0],
        'extras_address': origin + extras.start() + 7 + struct.unpack('<i', extras[1])[0],
        'reader_start': begin, 'reader_bytes': len(window)}
    return result


def arm_access(mach, code, start, address, decoder):
    begin = start - 544
    if begin < 0:
        return None
    window = code[begin:start + 288]
    origin = address + begin
    def instructions(match):
        return list(decoder.disasm(match[0], origin + match.start())) if match else []
    def pair_value(ins, low, high):
        return ins[low].operands[1].imm + (ins[high].operands[1].imm << 16)
    # Exact instruction roles, variable station/row constants and relocations.
    pattern = rb'(.\x28.\xd1\x0b\x95.\x20.\xe0)'
    selectors = list(re.finditer(pattern, window, re.S))
    if len(selectors) != 2:
        return None
    overrides = []
    joins = []
    for match in selectors:
        ins = instructions(match)
        if len(ins) != 5 or ins[0].mnemonic != 'cmp' or ins[1].mnemonic != 'bne' or ins[4].mnemonic != 'b':
            return None
        # The immediately preceding call must read the original station ID.
        call = list(decoder.disasm(window[match.start() - 4:match.start()], origin + match.start() - 4))
        if len(call) != 1 or call[0].mnemonic != 'bl' or not getter(mach, call[0].operands[0].imm, bytes.fromhex('80687047')):
            return None
        overrides.append({'station_id': ins[0].operands[1].imm, 'row': ins[3].operands[1].imm})
        joins.append(ins[4].operands[0].imm)
    if joins[0] != joins[1]:
        return None
    first, second = (instructions(m) for m in selectors)
    if first[1].operands[0].imm != origin + selectors[1].start() - 14 \
            or second[1].operands[0].imm != origin + selectors[1].end():
        return None
    join = joins[0] - origin
    if window[join:join + 2] != bytes.fromhex('1090'):
        return None
    fallback = window[selectors[1].end():join]
    if not re.fullmatch(rb'\x28\x68\x0b\x95\x4f\xf0\xff\x35\x28\x95.{4}\x28\x95.{4}', fallback, re.S):
        return None
    ins = list(decoder.disasm(fallback, origin + selectors[1].end()))
    if ins[-1].mnemonic != 'bl' or not getter(mach, ins[-1].operands[0].imm, bytes.fromhex('c0697047')):
        return None
    counts = one(rb'.{4}.{4}\x11\x9d\x78\x44\x01\x35\x50\xf8\x24\x00\x85\x42', window)
    extras = one(rb'.{4}\x00\x25.{4}\x78\x44\x50\xf8\x24\x00', window)
    rotation = one(rb'.{4}\x00\x25.{4}\x12\xa9\x12\x95\x13\x90\x4f\xf0\xff\x36\x20\x46\x14\x95', window)
    parsed = [instructions(m) for m in (counts, extras, rotation)]
    for ins, high in zip(parsed, (1, 2, 2)):
        if not ins or ins[0].mnemonic != 'movw' or ins[0].op_str.split(',')[0] != 'r0' \
                or ins[high].mnemonic != 'movt' or ins[high].op_str.split(',')[0] != 'r0':
            return None
    return {'station_overrides': overrides,
            'rotation_y': struct.unpack('<f', struct.pack('<I', pair_value(parsed[2], 0, 2)))[0],
            'counts_address': pair_value(parsed[0], 0, 1) + parsed[0][3].address + 4,
            'extras_address': pair_value(parsed[1], 0, 2) + parsed[1][3].address + 4,
            'reader_start': begin, 'reader_bytes': len(window)}


SELECTION = r"""ldr r0, =\w+
adr r0, (?P<status>\w+)
ldr r0, \[r0\]
ldr r0, \[r0\]
"""
OVERRIDE = SELECTION + r"""call _ZN6Status10getStationEv
call _ZN7Station8getIndexEv
cmp r0, #(?P<station>\w+)
bne(?:\.w)? #(?P<next>\w+)
movs r0, #(?P<row>\w+)
b(?:\.w)? #(?P<join>\w+)
"""
FALLBACK = SELECTION + r"""call _ZN6Status9getSystemEv
call _ZN11SolarSystem7getRaceEv
str r0, \[sp, #(?P<slot>\w+)\]
"""
ROWS = r"""adr (?P<t>r\d+), (?P<table>\w+)
add\.w (?P=t), (?P=t), (?P<row>r\d+), lsl #4
str (?P=t), \[sp, #(?P<keep>\w+)\]
"""
COLUMN = r"""ldr r0, \[sp, #(?P<keep>\w+)\]
ldr\.w (?P<id>r\d+), \[r0, (?P<column>r\d+), lsl #2\]
cmp (?P=id), #0
blt #(?P<skip>\w+)
"""
NEXT_COLUMN = r"""add\.w (?P<column>r\d+), (?P=column), #1
cmp\.w (?P=column), #4
blt #(?P<loop>\w+)
"""
ROTATION = r"""movw (?P<value>r\d+), #(?P<low>\w+)
movs (?P<zero>r\d+), #0
movt (?P=value), #(?P<high>\w+)
add r1, sp, #(?P<vector>\w+)
str (?P=zero), \[sp, #(?P=vector)\]
strd (?P=value), (?P=zero), \[sp, #(?P<y>\w+)\]
mov r0, \w+
call _ZN10AEGeometry11setRotationERKN11AbyssEngine6AEMath6VectorE
"""
COUNT = r"""ldr r0, \[sp, #(?P<slot>\w+)\]
adds (?P<index>r\d+), #1
ldr\.w r0, \[(?P<t>\w+), r0, lsl #2\]
cmp (?P=index), r0
blt #\w+
"""
EXTRA = r"""adr (?P<t>r\d+), (?P<table>\w+)
ldr\.w (?P<first>\w+), \[(?P=t), (?P<row>r\d+), lsl #2\]
movs r0, #0xc0
call _Znwj
mov (?P<child>r\d+), r0
add\.w r0, (?P=first), \w+
ldr\.w r2, \[\w+\]
uxth r1, r0
mov r0, (?P=child)
movs r3, #0
call _ZN10AEGeometryC1EtPN11AbyssEngine11PaintCanvasEb
ldr r1, \[(?P=child), #0xc\]
mov r0, \w+
call _ZN10AEGeometry8addChildEj
"""


def android_access(lib):
    """Selection chain, table addresses and rotation from Level::createScene."""
    from .android_listing import Listing, number, word_float
    scene = Listing(lib, '_ZN5Level11createSceneEv')
    overrides, fallback = scene.find(OVERRIDE), scene.find(FALLBACK)
    if len(overrides) != 2 or len(fallback) != 1:
        return None
    fallback = fallback[0]
    start = {m: scene.code[scene.index(m)].address for m in overrides + [fallback]}
    first, second = overrides if number(overrides[0]['next']) == start[overrides[1]] else overrides[::-1]
    # station A ? row : station B ? row : system race, all stored to one slot.
    if (number(first['next']) != start[second] or number(second['next']) != start[fallback]
            or {number(m['join']) for m in overrides} != {scene.code[scene.last(fallback)].address}
            or len({m['status'] for m in overrides + [fallback]}) != 1):
        return None
    slot = fallback['slot']

    def from_slot(match, group):
        """The match's `group` register holds the selected row, reloaded from its slot."""
        at = scene.definition(scene.index(match, group), match[group])
        return at is not None and scene.lines[at] == 'ldr %s, [sp, #%s]' % (match[group], slot)

    rows = [m for m in scene.find(ROWS) if from_slot(m, 'row')]
    columns = [m for m in scene.find(COLUMN) if rows and m['keep'] == rows[0]['keep']]
    counts = [m for m in scene.find(COUNT) if m['slot'] == slot]
    extras = [m for m in scene.find(EXTRA) if from_slot(m, 'row')]
    rotations = [m for m in scene.find(ROTATION) if number(m['y']) == number(m['vector']) + 4]
    if len(rows) != 1 or len(columns) != 1 or len(counts) != 1 or len(extras) != 1 or len(rotations) != 1:
        return None
    column = columns[0]
    advance = [m for m in scene.find(NEXT_COLUMN) if scene.code[scene.index(m)].address == number(column['skip'])
               and m['column'] == column['column'] and number(m['loop']) == scene.code[scene.index(column)].address]
    count = scene.definition(scene.index(counts[0], 't'), counts[0]['t'])
    if len(advance) != 1 or count is None or not scene.lines[count].startswith('adr %s, ' % counts[0]['t']):
        return None
    matches = overrides + [fallback] + rows + columns + advance + counts + extras + rotations
    rotation = rotations[0]
    return {'station_overrides': [{'station_id': number(m['station']), 'row': number(m['row'])} for m in (first, second)],
            'rotation_y': word_float(number(rotation['low']) | number(rotation['high']) << 16),
            'table_address': number(rows[0]['table']), 'counts_address': number(scene.lines[count].split(', ')[1]),
            'extras_address': number(extras[0]['table']),
            'region': scene.span(min([count] + [scene.index(m) for m in matches]), max(scene.last(m) for m in matches))}


def extract_hangars(mach, registrations):
    anchors = []
    for suffix in ('', '_add', '_alpha'):
        name = 'resources/data/assets/main/3d/meshes/hangars/hangar_terran' + suffix + '.aem'
        ids = {row['id'] for row in registrations if row['resource'] == name and row['kind'] == 'mesh' and row['registration_type'] == 4}
        if len(ids) != 1:
            return {}
        anchors.append(next(iter(ids)))
    section = mach.text
    code = mach.data[section['offset']:section['offset'] + section['length']]
    references = []
    if mach.architecture == 'android-armv7':
        access = android_access(mach)
        # (reader start, table address, decoder) elsewhere; the whole access here.
        references = [(None, access['table_address'], access)] if access else []
    elif mach.architecture == 'x86_64':
        for match in re.finditer(rb'\x4c\x89\xf0\x48\xc1\xe0\x04\x48\x8d\x0d(.{4})\x48\x01\xc8\x42\x8b\x1c\xa8', code, re.S):
            references.append((match.start(), section['address'] + match.start() + 14 + struct.unpack('<i', match[1])[0], None))
    else:
        import capstone
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        decoder.detail = True
        for match in re.finditer(rb'.{4}\x00\x21.{4}\x10\x9c\x78\x44\x00\xeb\x04\x10\x0a\x90', code, re.S):
            ins = list(decoder.disasm(match[0], section['address'] + match.start()))
            if match.start() % 2 or len(ins) != 7 or ins[0].mnemonic != 'movw' or ins[2].mnemonic != 'movt' \
                    or ins[0].op_str.split(',')[0] != 'r0' or ins[2].op_str.split(',')[0] != 'r0':
                continue
            # Require the matching four-byte column access, not just the row.
            if code[match.end() + 14:match.end() + 20] != bytes.fromhex('0a9850f82150'):
                continue
            references.append((match.start(), ins[0].operands[1].imm + (ins[2].operands[1].imm << 16) + ins[4].address + 4, decoder))
    results = []
    for start, address, decoder in references:
        table = integers(mach, address, 40)
        if not table or table[0][:4] != anchors + [-1] or any(not -1 <= v < 65535 for v in table[0]):
            continue
        if mach.architecture == 'android-armv7':
            access = decoder
        elif decoder is None:
            access = mac_access(mach, code, start, section['address'])
        else:
            access = arm_access(mach, code, start, section['address'], decoder)
        if not access:
            continue
        counts = integers(mach, access['counts_address'], 4)
        extras = integers(mach, access['extras_address'], 4)
        if not counts or not extras or counts[0][1] != 0 or any(not 0 <= v <= 128 for v in counts[0]) \
                or any(c and not 0 <= first <= 65534 - c + 1 for c, first in zip(counts[0], extras[0])):
            continue
        if not math.isfinite(access['rotation_y']) or abs(access['rotation_y']) > math.tau \
                or len({o['station_id'] for o in access['station_overrides']}) != 2 \
                or any(not 0 <= o['row'] < 10 or not 0 <= o['station_id'] < 4096 for o in access['station_overrides']):
            continue
        rows = [{'resource_ids': table[0][i * 4:i * 4 + 4],
                 'extra_resource_ids': list(range(extras[0][i], extras[0][i] + counts[0][i])) if i < 4 else []} for i in range(10)]
        result = {'rows': rows, 'rotation_y': access['rotation_y'],
                  'station_overrides': access['station_overrides'], 'system_field': 2,
                  'provenance': [{'offset': table[1], 'bytes': 160}, {'offset': counts[1], 'bytes': 16},
                                 {'offset': extras[1], 'bytes': 16},
                                 access.get('region') or {'offset': section['offset'] + mach.slice_offset + access['reader_start'], 'bytes': access['reader_bytes']}]}
        results.append(result)
    # Never choose a seemingly plausible occurrence from conflicting readers.
    return results[0] if len(results) == 1 else {}
