"""Declarative handling and maneuverability-equipment constants, read statically.

Android: Ship::getHandling adds a bonus per tagged upgrade to the ship's base
handling (no conversion, as on iOS); PlayerEgo's constructor stores it and
scales it by (1 + Ship::getAgility() / percent) x response scale;
Ship::refreshValue assigns the agility from Item::getAttribute when its
Item::getSort switch reaches the equipment type; Item::init takes the sort
from the item's third attribute value.
"""
import math
import re
import struct
from .steering import PC, code_span, lit, pool_float, shape_at, sole_definition
from .ship_models import section_bytes


ANDROID_CONSTRUCTOR = '_ZN9PlayerEgoC2EP6Player'
ANDROID_HANDLING = '_ZN4Ship11getHandlingEv'
ANDROID_AGILITY = '_ZN4Ship10getAgilityEv'
ANDROID_REFRESH = '_ZN4Ship12refreshValueEv'
ANDROID_ATTRIBUTE = '_ZN4Item12getAttributeEi'
ANDROID_SORT = '_ZN4Item7getSortEv'
ANDROID_INIT = '_ZN4Item4initEv'
# Sum the bonus over upgrades with the tag, then add the ship's base handling unconverted.
HANDLING = [('ldr', r'r2, \[r0, #0x78\]'), ('vldr', 's0, ' + PC), ('cbz', 'r2, @18'), ('ldr.w', r'ip, \[r2\]'),
            ('cmp.w', 'ip, #0'), ('beq', '@18'), ('ldr', r'r2, \[r2, #4\]'), ('movs', 'r3, #0'), ('vldr', 's0, ' + PC),
            ('vldr', 's2, ' + PC), ('vadd.f32', 's4, s0, s2'), ('ldr.w', r'r1, \[r2, r3, lsl #2\]'), ('adds', 'r3, #1'),
            ('cmp', r'r1, #(\d+|0x[0-9a-f]+)'), ('it', 'eq'), ('vmoveq.f32', 's0, s4'), ('cmp', 'r3, ip'), ('blo', '@10'),
            ('vldr', r's2, \[r0, #0x18\]'), ('vadd.f32', 's0, s0, s2'), ('vmov', 'r0, s0'), ('bx', 'lr')]
# Search the attribute (key, value) pairs; a missing key gives 0xc5997825.
GET_ATTRIBUTE = [('push', '{r7, lr}'), ('ldr', r'r2, \[r0, #0x30\]'), ('movw', 'r0, #0x7825'), ('movt', 'r0, #0xc599'),
                 ('ldr.w', r'ip, \[r2\]'), ('cmp.w', 'ip, #0'), ('it', 'eq'), ('popeq', '{r7, pc}'), ('ldr.w', r'lr, \[r2, #4\]'),
                 ('movs', 'r2, #0'), ('ldr.w', r'r3, \[lr, r2, lsl #2\]'), ('cmp', 'r3, r1'), ('beq', '@17'), ('adds', 'r2, #2'),
                 ('cmp', 'r2, ip'), ('blo', '@10'), ('b', '@19'), ('add.w', 'r0, lr, r2, lsl #2'), ('ldr', r'r0, \[r0, #4\]'),
                 ('pop', '{r7, pc}')]
HANDLING_SETUP = [('blx', '.*'), ('str.w', r'r0, \[r4, #0x154\]')]
# handling += handling x agility / percent (s16); handling x= scale.
RESPONSE_SETUP = [('blx', '.*'), ('vmov', 's0, r0'), ('vmov.f32', 's4, #.+'), ('vcvt.f32.s32', 's0, s0'), ('vdiv.f32', 's2, s0, s16'),
                  ('vstr', r's0, \[r4, #0x254\]'), ('vldr', r's0, \[r4, #0x154\]'), ('vmul.f32', 's2, s0, s2'),
                  ('vadd.f32', 's0, s0, s2'), ('vmul.f32', 's0, s0, s4'), ('vstr', r's0, \[r4, #0x154\]')]
SELECTOR = [('blx', '.*'), ('cmp', 'r0, #0x1d'), ('bhi.w', '#0x[0-9a-f]+'), ('tbb', r'\[pc, r0\]')]
ASSIGNMENT = [('ldr', r'r0, \[r4, #0x6c\]'), ('movs', r'r1, #(\d+|0x[0-9a-f]+)'), ('ldr', r'r0, \[r0, #4\]'),
              ('ldr', r'r0, \[r0, r5\]'), ('blx', '.*'), ('str', r'r0, \[r4, #0x40\]')]
AGILITY = [('ldr', r'r0, \[r0, #0x40\]'), ('bx', 'lr')]
SORT = [('ldr', r'r0, \[r0, #8\]'), ('bx', 'lr')]
# The item's index, type and sort are the values (odd words) of its first three attribute pairs.
ITEM_INIT = [('ldr', r'r1, \[r0, #0x30\]'), ('cbz', 'r1, #0x[0-9a-f]+'), ('ldr', r'r1, \[r1, #4\]'), ('vmov.i32', 'q8, #0'),
             ('ldr', r'r2, \[r1, #4\]'), ('str', r'r2, \[r0\]'), ('ldr', r'r2, \[r1, #0xc\]'), ('str', r'r2, \[r0, #4\]'),
             ('ldr', r'r2, \[r1, #0x14\]'), ('str', r'r2, \[r0, #8\]')]


def android_vehicle(lib):
    from .android_library import callee, instructions
    code = {name: instructions(lib, name) for name in (ANDROID_CONSTRUCTOR, ANDROID_HANDLING, ANDROID_AGILITY, ANDROID_REFRESH,
                                                        ANDROID_ATTRIBUTE, ANDROID_SORT, ANDROID_INIT)}
    if not all(code.values()):
        return {}
    provenance = {}

    def whole(key, name, shape):
        """The named function starts with `shape` (all of it but a trailing pool, except Item::init)."""
        if shape_at(code[name], shape)[:1] != [0]:
            return False
        provenance[key] = code_span(lib, code[name], 0, len(shape) - 1)
        return True

    def single(name, shape, target):
        rows = [i for i in shape_at(code[name], shape) if callee(lib, code[name][i + [m for m, _ in shape].index('blx')]) == target]
        return rows[0] if len(rows) == 1 else None
    if not (whole('handling_getter', ANDROID_HANDLING, HANDLING) and whole('equipment_getter', ANDROID_AGILITY, AGILITY)
            and whole('type_getter', ANDROID_SORT, SORT) and whole('property_getter', ANDROID_ATTRIBUTE, GET_ATTRIBUTE)
            and whole('item_type_layout', ANDROID_INIT, ITEM_INIT)):
        return {}
    getter = code[ANDROID_HANDLING]
    zeros, upgrade = [pool_float(lib, ANDROID_HANDLING, getter[i]) for i in (1, 8)], pool_float(lib, ANDROID_HANDLING, getter[9])
    if None in zeros or upgrade is None or any(v != 0 for _, v in zeros):
        return {}
    provenance['upgrade_bonus'] = {'offset': upgrade[0], 'bytes': 4}
    tag = getter[13].operands[1].imm
    constructor = code[ANDROID_CONSTRUCTOR]
    handling, setup = single(ANDROID_CONSTRUCTOR, HANDLING_SETUP, ANDROID_HANDLING), single(ANDROID_CONSTRUCTOR, RESPONSE_SETUP, ANDROID_AGILITY)
    if handling is None or setup is None or handling > setup:
        return {}
    provenance['handling_setup'] = code_span(lib, constructor, handling, handling + 1)
    provenance['response_setup'] = code_span(lib, constructor, setup, setup + len(RESPONSE_SETUP) - 1)
    provenance['response_scale'] = code_span(lib, constructor, setup + 2, setup + 2)
    scale = constructor[setup + 2].operands[1].fp
    # The percent divisor is s16's only definition before the setup.
    load = sole_definition(constructor, setup, ('s16', 'd8', 'q4'))
    if load is None or shape_at(constructor[load:load + 1], [('vldr', 's16, ' + PC)]) != [0]:
        return {}
    percent = pool_float(lib, ANDROID_CONSTRUCTOR, constructor[load])
    if percent is None:
        return {}
    provenance['percent_load'] = code_span(lib, constructor, load, load)
    provenance['percent_divisor'] = {'offset': percent[0], 'bytes': 4}
    refresh = code[ANDROID_REFRESH]
    selector, assignment = single(ANDROID_REFRESH, SELECTOR, ANDROID_SORT), single(ANDROID_REFRESH, ASSIGNMENT, ANDROID_ATTRIBUTE)
    if selector is None or assignment is None:
        return {}
    provenance['equipment_selector'] = code_span(lib, refresh, selector, selector + 3)
    provenance['equipment_assignment'] = code_span(lib, refresh, assignment, assignment + 5)
    property_id = refresh[assignment + 1].operands[1].imm
    # tbb: case n branches to the tbb address + 4 + 2 x table[n]; cases 0-29.
    table = refresh[selector + 3].address + 4
    offset = lib.text['offset'] + table - lib.text['address']
    rows = lib.data[offset:offset + 30]
    provenance['equipment_table'] = {'offset': offset, 'bytes': 30}
    type_ids = [i for i, row in enumerate(rows) if table + 2 * row == refresh[assignment].address]
    if len(type_ids) != 1 or not (0 < upgrade[1] <= 10 and 0 < percent[1] <= 10000 and 0 < scale):
        return {}
    return {'base_add': 0.0, 'base_divisor': 1.0, 'base_scale': 1.0, 'base_offset': 0.0,
            'upgrade_tag': tag, 'upgrade_bonus': upgrade[1], 'equipment_type': type_ids[0], 'item_type_value_index': 5,
            'equipment_percent_property': property_id, 'percent_divisor': percent[1], 'response_scale': scale,
            'equipment_rule': 'last_matching', 'provenance': provenance}


def extract_vehicle_response(mach, pilot):
    if pilot and mach.architecture == 'android-armv7':
        return android_vehicle(mach)
    if not pilot or mach.architecture not in ('x86_64', 'armv7'):
        return {}
    mac = mach.architecture == 'x86_64'
    text = mach.text
    code = mach.data[text['offset']:text['offset'] + text['length']]
    base = text['address']
    provenance = {}
    if not mac:
        import capstone
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        decoder.detail = True
    def unique(pattern):
        rows = [m for m in re.finditer(pattern, code, re.S) if mac or m.start() % 2 == 0]
        return rows[0] if len(rows) == 1 else None
    def region(name, address, length, expected=None):
        found = section_bytes(mach, address, length, b'__text')
        if found is None or expected is not None and found[0] != expected:
            raise ValueError('Unsupported linked layout')
        provenance[name] = {'offset': found[1], 'bytes': length}
        return found[0]
    def matched(name, match):
        if match is None: raise ValueError('Missing or ambiguous layout')
        region(name, base + match.start(), len(match[0]))
        return match
    def branch(match, group):
        address = base + match.start(group)
        if mac:
            return address + 4 + struct.unpack('<i', match[group])[0]
        ins = list(decoder.disasm(match[group], address))
        if len(ins) != 1 or ins[0].mnemonic != 'bl': raise ValueError('Unsupported call')
        return ins[0].operands[0].imm
    def constant(name, address, raw, register=None):
        if mac:
            target = address + 4 + struct.unpack('<i', raw)[0]
        else:
            ins = list(decoder.disasm(raw, address))
            if len(ins) != 1 or ins[0].mnemonic != 'vldr' or ins[0].op_str.split(',')[0] != register \
                    or len(ins[0].operands) != 2 or ins[0].operands[1].type != capstone.arm.ARM_OP_MEM \
                    or ins[0].operands[1].mem.base != capstone.arm.ARM_REG_PC:
                raise ValueError('Unsupported constant load')
            target = ((address + 4) & ~3) + ins[0].operands[1].mem.disp
        sections = [s for s in mach.sections if s['segment'] == b'__TEXT' and s['offset'] > 0
                    and s['address'] <= target and target + 4 <= s['address'] + s['length']]
        if len(sections) != 1: raise ValueError('Unbacked constant')
        s = sections[0]; offset = s['offset'] + target - s['address']
        if offset + 4 > len(mach.data): raise ValueError('Truncated constant')
        value = struct.unpack_from('<f', mach.data, offset)[0]
        if not math.isfinite(value): raise ValueError('Nonfinite constant')
        provenance[name] = {'offset': mach.slice_offset + offset, 'bytes': 4}
        return value
    def load(name, match, group, register=None):
        return constant(name, base + match.start(group), match[group], register)
    try:
        if mac:
            getter = matched('handling_getter', unique(lit('554889e5488b8f880000000f57c94885c9742b8b010f57c985c07422488b49080f57c931d2f30f1005') + rb'(.{4})' + lit('833c91') + rb'(.)' + lit('7504f30f58c848ffc239c272eff30f104718f30f5805') + rb'(.{4})' + lit('f30f5e05') + rb'(.{4})' + lit('f30f5905') + rb'(.{4})' + lit('f30f5805') + rb'(.{4})' + lit('f30f58c15dc3')))
            upgrade = load('upgrade_bonus', getter, 1)
            tag = getter[2][0]
            conversion = [load(name, getter, group) for name, group in [('base_add', 3), ('base_divisor', 4), ('base_scale', 5), ('base_offset', 6)]]
            setup = matched('response_setup', unique(lit('e8') + rb'(.{4})' + lit('0f57c0f30f2ac0f30f1183f0020000f30f5e05') + rb'(.{4})' + lit('f30f108ba4010000f30f59c1f30f58c1f30f5905') + rb'(.{4})' + lit('f30f1183a4010000')))
            region('equipment_getter', branch(setup, 1), 9, bytes.fromhex('554889e58b47405dc3'))
            percent = load('percent_divisor', setup, 2)
            scale = load('response_scale', setup, 3)
            stores = list(re.finditer(lit('e8') + rb'(.{4})' + lit('f30f1183a4010000'), code[max(0, setup.start()-512):setup.start()], re.S))
            links = [m for m in stores if base + max(0, setup.start()-512) + m.start(1) + 4 + struct.unpack('<i',m[1])[0] == base + getter.start()]
            if len(links) != 1: raise ValueError('Handling setup link missing')
            region('handling_setup', base + max(0, setup.start()-512) + links[0].start(), len(links[0][0]))
            equipment = matched('equipment_assignment', unique(lit('498b4770488b40084a8b3c30be') + rb'(.{4})' + lit('e8') + rb'(.{4})' + lit('41894740')))
            property_id = struct.unpack('<I', equipment[1])[0]
            region('property_getter', branch(equipment, 2), 42, bytes.fromhex('554889e5488b4f388b3931d2eb044883c202b8257899c539fa730d488b410839349075ea8b4490045dc3'))
            selector = matched('equipment_selector', unique(lit('e8') + rb'(.{4})' + lit('83f81d0f87') + rb'.{4}' + lit('89c0486304834801d8ffe0')))
            region('type_getter', branch(selector, 1), 9, bytes.fromhex('554889e58b47085dc3'))
            # The table is relative to the LEA target established before this selector.
            window_start = max(0, selector.start()-128)
            tables = list(re.finditer(lit('488d1d') + rb'(.{4})', code[window_start:selector.start()], re.S))
            if len(tables) != 1: raise ValueError('Ambiguous equipment table')
            table_load = tables[0]
            address = base + window_start + table_load.start()
            table = address + 7 + struct.unpack('<i', table_load[1])[0]
            region('equipment_table_load', address, 7)
            rows = struct.unpack('<30i', region('equipment_table', table, 120))
            type_ids = [i for i, offset in enumerate(rows) if table+offset == base+equipment.start()]
            matched('item_type_layout', unique(lit('554889e5488b47384885c0747d488b48088b4904890f488b48088b490c894f04488b48088b4914894f08')))
        else:
            setup = matched('response_setup', unique(rb'(.{4})' + lit('40ec300bbbff2006') + rb'(.{4})' + lit('80ee0a1a85ed940a95ed540a40ff110d40ef200d00ffb20d85ed540a')))
            getter_pattern = lit('826f002a1cbfd2f80090b9f1000f02d1c0ef10000ee0c0ef10005268') + rb'(.{4})' + lit('002352f823100133') + rb'(.)' + lit('2908bf40ef800d4b45f6d390ed060a00ef800d10ee100a7047')
            targets = []
            for at in range(max(0, setup.start()-512), setup.start(), 2):
                if code[at+4:at+8] != bytes.fromhex('c5f85001'): continue
                ins = list(decoder.disasm(code[at:at+4], base+at))
                if len(ins)==1 and ins[0].mnemonic=='bl': targets.append(ins[0].operands[0].imm)
            getters = [g for g in re.finditer(getter_pattern,code,re.S) if base+g.start() in targets and g.start()%2==0]
            getter = matched('handling_getter',getters[0] if len(getters)==1 else None)
            upgrade = load('upgrade_bonus', getter, 1, 's0')
            tag = getter[2][0]
            conversion = [0.0, 1.0, 1.0, 0.0]  # Recognized direct-base getter, no conversion.
            region('equipment_getter', branch(setup, 1), 4, bytes.fromhex('006c7047'))
            ins = list(decoder.disasm(setup[2], base+setup.start(2)))
            if len(ins)!=1 or ins[0].mnemonic!='vmov.f32' or ins[0].op_str.split(',')[0]!='d18' \
                    or len(ins[0].operands)!=2 or ins[0].operands[1].type!=capstone.arm.ARM_OP_FP:
                raise ValueError('Unsupported response scale')
            scale = ins[0].operands[1].fp
            region('response_scale', base+setup.start(2), 4)
            # A unique s20 literal load supplies the denominator in this setup region.
            start = max(0,setup.start()-512)
            loads=[];links=[]
            for at in range(start,setup.start(),2):
                raw=code[at:at+4]
                decoded=list(decoder.disasm(raw,base+at))
                if len(decoded)==1 and decoded[0].mnemonic=='vldr' and decoded[0].op_str.startswith('s20, [pc,'):
                    loads.append(at)
                if code[at+4:at+8] == bytes.fromhex('c5f85001') and len(decoded)==1 and decoded[0].mnemonic=='bl' and decoded[0].operands[0].imm==base+getter.start():
                    links.append(at)
            if len(loads)!=1 or len(links)!=1: raise ValueError('Missing handling/denominator setup')
            region('percent_load',base+loads[0],4)
            percent=constant('percent_divisor',base+loads[0],code[loads[0]:loads[0]+4],'s20')
            region('handling_setup',base+links[0],8)
            equipment = matched('equipment_assignment', unique(lit('e06e') + rb'(.)' + lit('2140688059') + rb'(.{4})' + lit('2064')))
            property_id=equipment[1][0]
            region('property_getter',branch(equipment,2),48,bytes.fromhex('026bd2f80090b9f1000f08d05268002352f82300884207d002334b45f8d347f62500ccf29950704702eb830040687047'))
            selector_pattern = rb'(.{4})' + lit('1d2800f2') + rb'.{2}' + lit('dfe800f0')
            selectors=[]
            for candidate in re.finditer(selector_pattern,code,re.S):
                if candidate.start()%2: continue
                table=base+candidate.end()
                found=section_bytes(mach,table,30,b'__text')
                if found is not None and any(table+x*2==base+equipment.start() for x in found[0]): selectors.append(candidate)
            selector = matched('equipment_selector',selectors[0] if len(selectors)==1 else None)
            region('type_getter',branch(selector,1),4,bytes.fromhex('80687047'))
            table=base+selector.end()
            rows=region('equipment_table',table,30)
            type_ids=[i for i,offset in enumerate(rows) if table+offset*2==base+equipment.start()]
            matched('item_type_layout',unique(lit('016b002908bf70474968c0ef50004a680260ca6842604a698260')))
        if len(type_ids)!=1: raise ValueError('Missing equipment type binding')
        if not (0<upgrade<=10 and 0<percent<=10000 and 0<scale<=10000 and 0<=tag<=255 and 0<=property_id<=65535):
            raise ValueError('Unsupported vehicle constants')
        if not all(math.isfinite(v) and abs(v)<=100 for v in conversion) or conversion[1]<=0 or conversion[2]<=0:
            raise ValueError('Unsupported base conversion')
        return {'base_add':conversion[0],'base_divisor':conversion[1],'base_scale':conversion[2],'base_offset':conversion[3],
                'upgrade_tag':tag,'upgrade_bonus':upgrade,'equipment_type':type_ids[0],'item_type_value_index':5,
                'equipment_percent_property':property_id,'percent_divisor':percent,'response_scale':scale,
                'equipment_rule':'last_matching','provenance':provenance}
    except (ValueError,struct.error,IndexError):
        return {}
