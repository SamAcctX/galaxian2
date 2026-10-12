"""Read the hangar ship-height table from validated catalogue-indexed accesses.

This is declarative positioning data, not the original ship construction logic.
No executable bytes are emitted or executed. The surrounding hangar reader must
have independently identified the supported scene-declaration region first.

Android: Level::createScene creates the player's ship, stores it first in the
scene and moves it to (0, height[Ship::getIndex()], 0) through vtable slot 18.
"""
import re
import struct

from .ship_models import section_bytes


def literal(value):
    return re.escape(bytes.fromhex(value))


ANDROID = r"""call _ZN5Level10createShipEiiiP8Waypointbb
ldr (?P<t>\w+), =\w+
movs r3, #0
adr (?P=t), (?P<table>\w+)
add\.w (?P=t), (?P=t), (?P<index>\w+), lsl #2
vldr (?P<y>s\d+), \[(?P=t)\]
vcvt\.f32\.s32 (?P=y), (?P=y)
ldr\.w r1, \[(?P<level>\w+), #(?P<ships>\w+)\]
ldr r1, \[r1, #4\]
str r0, \[r1\]
vmov r2, (?P=y)
ldr\.w r0, \[(?P=level), #(?P=ships)\]
ldr r0, \[r0, #4\]
ldr r0, \[r0\]
ldr r1, \[r0\]
ldr (?P<f>\w+), \[r1, #0x48\]
movs r1, #0
blx (?P=f)
"""


def android_placement(lib, count):
    """The height table indexed by the ship index the scene reads before creating the ship."""
    from .android_listing import Listing, number
    scene = Listing(lib, '_ZN5Level11createSceneEv')
    found = scene.find(ANDROID)
    if len(found) != 1:
        return {}
    match = found[0]
    source = scene.definition(scene.index(match, 'index'), match['index'])
    if (source is None or scene.lines[source] != 'mov %s, r0' % match['index']
            or scene.lines[source - 2:source] != ['call _ZN6Status7getShipEv', 'call _ZN4Ship8getIndexEv']):
        return {}
    table = section_bytes(lib, number(match['table']), count * 4, b'__const')
    if table is None:
        return {}
    values = list(struct.unpack('<' + str(count) + 'i', table[0]))
    if any(abs(value) > 1000000 for value in values):
        return {}
    return {'y_positions': values, 'provenance': [{'offset': table[1], 'bytes': count * 4}, scene.match_span(match),
                                                  scene.span(source - 2, source)]}


def extract_ship_placement(mach, hangars, count):
    if not hangars or count not in (61, 64):
        return {}
    if mach.architecture == 'android-armv7':
        return android_placement(mach, count)
    section = mach.text
    region = hangars['provenance'][-1]
    offset = region['offset'] - mach.slice_offset
    if offset < section['offset'] or offset + region['bytes'] > section['offset'] + section['length']:
        return {}
    code = mach.data[offset:offset + region['bytes']]
    address = section['address'] + offset - section['offset']
    if mach.architecture == 'x86_64':
        pattern = (rb'\xe8(.{4})' + literal('89c3498b3e') + rb'\xe8.{4}' + literal('4889c7') + rb'\xe8.{4}'
                   + literal('4531ed4183bf14010000170f95c1c7042400000000440fb6c94c89ff89c631d289d94531c0')
                   + rb'\xe8.{4}' + literal('488d0d') + rb'(.{4})'
                   + literal('4863d3f30f2a0c91498b8f78010000488b4908488901498b8778010000488b4008488b38488b070f57c00f57d2ff9090000000'))
        getter_bytes = bytes.fromhex('554889e58b075dc3')
    else:
        pattern = (rb'(.{4})' + literal('824620682896') + rb'.{4}' + literal('2896') + rb'.{4}'
                   + literal('0146d5f8c0002896002217284ff0000018bf0120cdf80080019028465346cdf80880')
                   + rb'.{4}(.{4})' + literal('0023') + rb'(.{4})'
                   + literal('d5f8f8107a4402eb8a02496892ed000abbff00060860d5f8f800406810ee102a006801688c6c00212896a047'))
        getter_bytes = bytes.fromhex('00687047')
    results = []
    for match in re.finditer(pattern, code, re.S):
        if mach.architecture == 'x86_64':
            getter_address = address + match.start() + 5 + struct.unpack('<i', match[1])[0]
            table_address = address + match.start(2) + 4 + struct.unpack('<i', match[2])[0]
        else:
            if (offset + match.start()) % 2:
                continue
            import capstone
            decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
            decoder.detail = True
            call = list(decoder.disasm(match[1], address + match.start()))
            low = list(decoder.disasm(match[2], address + match.start(2)))
            high = list(decoder.disasm(match[3], address + match.start(3)))
            if len(call) != 1 or call[0].mnemonic != 'bl' or len(low) != 1 or len(high) != 1 \
                    or low[0].mnemonic != 'movw' or low[0].op_str.split(',')[0] != 'r2' \
                    or high[0].mnemonic != 'movt' or high[0].op_str.split(',')[0] != 'r2':
                continue
            getter_address = call[0].operands[0].imm
            table_address = low[0].operands[1].imm + (high[0].operands[1].imm << 16) + high[0].address + 12
        getter = section_bytes(mach, getter_address, len(getter_bytes), b'__text')
        table = section_bytes(mach, table_address, count * 4, b'__const')
        if getter is None or getter[0] != getter_bytes or table is None:
            continue
        values = list(struct.unpack('<' + str(count) + 'i', table[0]))
        if any(abs(value) > 1000000 for value in values):
            continue
        results.append({'y_positions': values, 'provenance': [
            {'offset': table[1], 'bytes': count * 4},
            {'offset': offset + match.start() + mach.slice_offset, 'bytes': len(match[0])},
            {'offset': getter[1], 'bytes': len(getter_bytes)}]})
    return results[0] if len(results) == 1 else {}
