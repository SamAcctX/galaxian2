"""Static font-to-texture/group declarations, independent of texture filenames.

Android: BuildResourceList declares the font records and, behind its iPadHD
and retinaDisplay guards, the atlas variants; GameText::setLanguage(short, int)
names the language files; Globals::loadFont selects fonts (font_selection).
"""
import re
import struct
from .opening_loadout import template
from .opening_dialogue import Declaration
from .ship_models import section_bytes

MAC_LANGUAGE = '0fbf55f689d683fa0f4889b580feffff0f87 {outside:4} 488d05 {table:4} 488b8d80feffff48630c88488d0401ffe0'
MAC_LANGUAGE_ALTERNATE = MAC_LANGUAGE.replace('48630c88488d0401ffe0', '486314884801c2ffe2')
ARM_LANGUAGE = 'bdf924120f295490539100f2 {outside:2} 5399dfe811f0'
MAC_GUARDS = {'medium': '488d05 {flag:4} f600010f84 {other:4}',
              'large': '488d05 {flag:4} 8a18bf18000000e8 {allocate:4} 4989c7f6c3010f84 {other:4}'}
ARM_GUARDS = {'medium': '{low:4} {high:4} 7844016808780028 {other:4}',
              'large': '{low:4} {high:4} 7844006804784ff0ff30c8f870051020 {allocate:4} {record:4} 002c {other:4}'}

MAC_RECORD = '''bf18000000e8 {record_allocate:4} 4889c3bf04000000e8 {payload_allocate:4}
66c700 {texture:2} 66c74002 {group:2} 66c703 {id:2}
c7430401000000c74308ffffffff48894310'''


def font_records(mach):
    """Recognize complete finite type-1 records, never execute declarations."""
    if mach.architecture == 'android-armv7':
        return android_font_records(mach)
    text = mach.text
    code = mach.data[text['offset']:text['offset'] + text['length']]
    rows = []
    if mach.architecture == 'x86_64':
        for match in template(MAC_RECORD).finditer(code):
            targets = [match.end(key) + struct.unpack('<i', match[key])[0] for key in ('record_allocate', 'payload_allocate')]
            if targets[0] != targets[1]: continue
            rows.append({'id': int.from_bytes(match['id'], 'little'),
                         'texture_id': int.from_bytes(match['texture'], 'little'),
                         'font_group': int.from_bytes(match['group'], 'little'),
                         'source_offset': mach.slice_offset + text['offset'] + match.start(),
                         'source_bytes': len(match[0])})
    elif mach.architecture == 'armv7':
        import capstone
        decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        decoder.detail = True
        # The four-byte font payload is returned in r0; every record field and
        # repeated record-pointer reload must agree before it is accepted.
        for match in re.finditer(bytes.fromhex('0420'), code):
            if match.start() % 2: continue
            start = text['address'] + match.start()
            try:
                d = Declaration(mach, start, decoder, bound=96)
                d.take('movs', 'r0, #4')
                allocator = d.call('blx')
                d.take('add', 'r6, sp, #0xc')
                texture = d.number('r2')
                d.take('add.w', 'r1, r6, #0x1020')
                group = 0
                ins = d.take()
                if ins.mnemonic == 'movt' and ins.op_str.startswith('r2, #'):
                    group = ins.operands[1].imm
                    ins = d.take()
                if ins.mnemonic not in ('movw', 'movs', 'mov.w') or ins.operands[0].reg != capstone.arm.ARM_REG_R3 or ins.operands[1].type != capstone.arm.ARM_OP_IMM: continue
                identifier = ins.operands[1].imm
                scratch = d.take()
                if (scratch.mnemonic, scratch.op_str) not in [('add.w', 'r6, sp, #0x5000'), ('add', 'r6, sp, #0x4c')]: continue
                d.take('mov', 'r5, r1')
                load = d.take('ldr.w')
                if not load.op_str.startswith('r1, [r5, #'): continue
                memory = load.op_str.split(', ', 1)[1]
                d.take('str', 'r2, [r0]')
                d.take('ldr.w', 'r2, ' + memory)
                d.take('strh', 'r3, [r2]')
                d.take('movs', 'r3, #1')
                d.take('ldr.w', 'r2, ' + memory)
                d.take('str', 'r3, [r2, #4]')
                d.take('mov.w', 'r3, #-1')
                d.take('ldr.w', 'r2, ' + memory)
                d.take('str', 'r3, [r2, #8]')
                d.take('ldr.w', 'r2, ' + memory)
                d.take('str', 'r0, [r2, #0xc]')
                end = d.end
                # The preceding allocation must produce this same record slot.
                p = Declaration(mach, start - 22, decoder, bound=32)
                p.take('movs', 'r0, #0x10')
                marker = p.take('str.w')
                if not marker.op_str.endswith(', [r4, #0x570]'): continue
                if p.call('blx') != allocator: continue
                p.take('str.w', 'r0, ' + memory)
                p.number('r0')
                p.take('str.w', 'r0, [r4, #0x570]')
                if p.end != start: continue
                rows.append({'id': identifier, 'texture_id': texture, 'font_group': group,
                             'source_offset': mach.slice_offset + text['offset'] + match.start() - 22,
                             'source_bytes': end - start + 22})
            except (ValueError, StopIteration, IndexError):
                continue
    # Conflicts are not guessed away, and partial records never become a font.
    if len(rows) > 256 or any(not 0 <= row['id'] < 65535 or not 0 <= row['texture_id'] < 65535 or not 0 <= row['font_group'] < 32 for row in rows): return []
    if len({row['id'] for row in rows}) != len(rows): return []
    return sorted(rows, key=lambda row: row['id'])


def language_files(mach):
    """Read the finite language-index/filename dispatch, without following code."""
    if mach.architecture == 'android-armv7':
        return android_language_files(mach)
    import capstone
    mac = mach.architecture == 'x86_64'
    if not mac and mach.architecture != 'armv7': return {}
    decoder = capstone.Cs(capstone.CS_ARCH_X86 if mac else capstone.CS_ARCH_ARM,
                          capstone.CS_MODE_64 if mac else capstone.CS_MODE_THUMB)
    decoder.detail = True
    section = mach.text
    code = mach.data[section['offset']:section['offset'] + section['length']]
    pattern = template((MAC_LANGUAGE, MAC_LANGUAGE_ALTERNATE) if mac else ARM_LANGUAGE)
    matches = [m for m in pattern.finditer(code) if mac or m.start() % 2 == 0]
    if len(matches) != 1: return {}
    match = matches[0]
    address = section['address'] + match.start()
    if mac:
        table = address + match.end('table') - match.start() + struct.unpack('<i', match['table'])[0]
    else:
        table = address + len(match[0])
    found = section_bytes(mach, table, 64 if mac else 32, b'__text')
    if found is None or len(found[0]) != (64 if mac else 32): return {}
    targets = [table + delta * (1 if mac else 2) for delta in struct.unpack('<16i' if mac else '<16H', found[0])]
    rows, calls = [], set()
    for index, target in enumerate(targets):
        try:
            d = Declaration(mach, target, decoder, bound=64)
            if mac:
                ins = d.take('lea')
                if not ins.op_str.startswith('rdi, [rbp - '): return {}
                d.take('xor', 'edx, edx')
                ins = d.take('lea')
                if not ins.op_str.startswith('rsi, [rip + '): return {}
                string_address = ins.address + ins.size + ins.operands[1].mem.disp
                calls.add(d.call('call'))
            else:
                d.number('r0')
                d.take('str', 'r0, [sp, #0x230]')
                lo = d.number('r1')
                hi = d.take('movt')
                if not hi.op_str.startswith('r1, #'): return {}
                pc = d.take('add', 'r1, pc')
                string_address = (hi.operands[1].imm << 16 | lo) + pc.address + 4
                ins = d.take('add')
                if not ins.op_str.startswith('r0, sp, #'): return {}
                d.take('movs', 'r2, #0')
                calls.add(d.call('bl'))
            string = section_bytes(mach, string_address, 9, b'__cstring')
            if string is None: return {}
            name = string[0].split(b'\0', 1)[0]
            if not re.fullmatch(rb'[a-z]{2,3}\.lang', name): return {}
            rows.append({'language_id': index, 'file': name.decode('ascii'),
                         'source_offset': mach.slice_offset + section['offset'] + target - section['address'],
                         'source_bytes': d.end - target,
                         'string_offset': string[1], 'string_bytes': len(name) + 1})
        except (ValueError, StopIteration, IndexError): return {}
    if len(calls) != 1 or len({row['file'] for row in rows}) != 16: return {}
    return {'rows': rows, 'provenance': {
        'dispatch': {'offset': mach.slice_offset + section['offset'] + match.start(), 'bytes': len(match[0])},
        'table': {'offset': found[1], 'bytes': len(found[0])}}}


def font_texture_choices(mach, records, registrations, flags):
    """Associate font atlases with their source registration branches, not names."""
    if mach.architecture == 'android-armv7':
        return android_texture_choices(mach, records, registrations, flags)
    import capstone
    mac = mach.architecture == 'x86_64'
    if not mac and mach.architecture != 'armv7': return {}
    decoder = capstone.Cs(capstone.CS_ARCH_X86 if mac else capstone.CS_ARCH_ARM,
                          capstone.CS_MODE_64 if mac else capstone.CS_MODE_THUMB)
    decoder.detail = True
    section = mach.text
    code = mach.data[section['offset']:section['offset'] + section['length']]
    specs = MAC_GUARDS if mac else ARM_GUARDS
    guards = {}
    for kind, spec in specs.items():
        candidates = []
        for match in template(spec).finditer(code):
            if not mac and match.start() % 2: continue
            address = section['address'] + match.start()
            if mac:
                flag = address + 7 + struct.unpack('<i', match['flag'])[0]
                other = address + len(match[0]) + struct.unpack('<i', match['other'])[0]
            else:
                ins = list(decoder.disasm(match['low'] + match['high'], address))
                if len(ins) != 2 or ins[0].mnemonic != 'movw' or ins[1].mnemonic != 'movt' or any(not i.op_str.startswith('r0, #') for i in ins): continue
                pointer = address + 12 + (ins[1].operands[1].imm << 16 | ins[0].operands[1].imm)
                # iOS accesses these globals through its static pointer section.
                slot = next((s for s in mach.sections if s['address'] <= pointer and pointer + 4 <= s['address'] + s['length'] and s['offset']), None)
                if slot is None: continue
                at = slot['offset'] + pointer - slot['address']
                flag = struct.unpack_from('<I', mach.data, at)[0]
                branch = list(decoder.disasm(match['other'], address + len(match[0]) - 4))
                if len(branch) != 1 or branch[0].mnemonic != 'beq.w': continue
                other = branch[0].operands[0].imm
                if kind == 'large':
                    call = list(decoder.disasm(match['allocate'], address + match.start('allocate') - match.start()))
                    if len(call) != 1 or call[0].mnemonic != 'blx': continue
                    ins = list(decoder.disasm(match['record'], address + match.start('record') - match.start()))
                    if len(ins) != 1 or ins[0].mnemonic != 'str.w' or not ins[0].op_str.startswith('r0, [sl, #'): continue
            if flag != flags[kind] or not address + len(match[0]) < other < section['address'] + section['length']: continue
            candidates.append({'address': address, 'begin': address + len(match[0]), 'other': other,
                               'source_offset': mach.slice_offset + section['offset'] + match.start(), 'source_bytes': len(match[0])})
        if len(candidates) != 1: return {}
        guards[kind] = candidates[0]
    # iOS has one stack bookkeeping store at the start of the second branch.
    if guards['large']['address'] - guards['medium']['other'] != (0 if mac else 2): return {}
    wanted = {row['texture_id'] for row in records}
    choices = []
    for identifier in sorted(wanted):
        declarations = [r for r in registrations if r['id'] == identifier]
        if len(declarations) != 3 or any(r['kind'] != 'texture' or r['registration_type'] != 2 for r in declarations): return {}
        variants = {}
        offsets = {}
        for row in declarations:
            at = section['address'] + row['source_offset'] - mach.slice_offset - section['offset']
            if guards['medium']['begin'] <= at < guards['medium']['other']: mode = 'medium'
            elif guards['large']['begin'] <= at < guards['large']['other']: mode = 'large'
            elif at >= guards['large']['other']: mode = 'baseline'
            else: return {}
            if mode in variants: return {}
            variants[mode] = row['resource']
            offsets[mode] = row['source_offset']
        if set(variants) != {'baseline', 'medium', 'large'}: return {}
        choices.append({'texture_id': identifier, 'variants': variants, 'source_offsets': offsets})
    return {'rows': choices, 'provenance': {name: {'offset': row['source_offset'], 'bytes': row['source_bytes']} for name, row in guards.items()}}


def extract_font_bindings(mach, registrations):
    from .font_selection import extract_font_selection
    records = font_records(mach)
    languages = language_files(mach)
    selection = extract_font_selection(mach)
    if not records or not languages or not selection: return {}
    flags = selection.pop('_profile_globals')
    textures = font_texture_choices(mach, records, registrations, flags)
    if not textures: return {}
    wanted = {selection[key] for key in ['default_font_id', 'secondary_font_id', 'language_font_id']}
    wanted.update(row['font_id'] for row in selection['overrides'])
    if wanted != {row['id'] for row in records}: return {}
    return {'records': records, 'languages': languages, 'selection': selection, 'textures': textures}


BUILD = '_Z17BuildResourceListPN11AbyssEngine6EngineE'


def android_font_records(lib):
    """BuildResourceList's 16-byte type-1 records (u16 id, 1, -1, payload) whose
    4-byte payload holds the u16 texture id and u16 font group, read along
    straight-line code; provenance is the record's allocation call."""
    import capstone
    from .android_library import decode_function, interpret, literal_references
    from .android_blocks import offset
    extent = lib.symbols.get(BUILD)
    if extent is None:
        return []
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    decoder.detail = True
    # Decoded as the registration reader does: aligned at each resource literal.
    anchors = [at for at in literal_references(lib) if extent[0] <= at < sum(extent)]
    objects = interpret(lib, decode_function(lib, decoder, *extent, anchors) or [])
    rows = []
    for item in objects:
        fields = item['fields']
        if item['size'] != 16 or fields.get(4) != (('value', 1), 4):
            continue
        link = fields.get(12, (None,))[0]
        holder = objects[link[1]] if link and link[0] == 'object' and link[2] == 0 else {'size': 0}
        payload = holder.get('fields', {})
        if (item['poisoned'] or sorted(fields) != [0, 4, 8, 12] or fields[8] != (('value', 0xffffffff), 4)
                or holder['size'] != 4 or holder['poisoned'] or sorted(payload) != [0, 2]
                or any(field[1] != 2 or not field[0] or field[0][0] != 'value' for field in [fields[0], *payload.values()])):
            return []
        rows.append({'id': fields[0][0][1], 'texture_id': payload[0][0][1], 'font_group': payload[2][0][1],
                     'source_offset': offset(lib, item['address']), 'source_bytes': 4})
    if any(row['id'] == 65535 or row['texture_id'] == 65535 or row['font_group'] >= 32 for row in rows): return []
    if len({row['id'] for row in rows}) != len(rows): return []
    return sorted(rows, key=lambda row: row['id'])


LANGUAGE_DISPATCH = """
cmp r6, #0xf
bhi.w #{default}
tbh [pc, r6, lsl #1] {cases:32}
"""
LANGUAGE_CASE = """
{ldr|ldr.w} r1, [pc, #{&file}]
add r1, pc
add r0, sp, #4
movs r2, #0
blx <_ZN11AbyssEngine6StringC1EPKcb>
"""


def android_language_files(lib):
    """setLanguage's 16 cases each build the file name String from one literal.
    Android loads gb.lang for the languages it dropped (10 and 11)."""
    from .android_blocks import find, match, offset
    symbol = '_ZN8GameText11setLanguageEsi'
    dispatch = find(lib, symbol, LANGUAGE_DISPATCH)
    if dispatch is None:
        return {}
    table, cases = dispatch['tables']['cases']
    rows = []
    for index, (case,) in enumerate(struct.iter_unpack('<H', cases)):
        target = table + 2 * case
        block = match(lib, symbol, LANGUAGE_CASE, target)
        if block is None:
            return {}
        string = section_bytes(lib, block['refs']['file'][0], 9, b'__cstring')
        name = string and string[0].split(b'\0', 1)[0]
        if not name or not re.fullmatch(rb'[a-z]{2,3}\.lang', name):
            return {}
        rows.append({'language_id': index, 'file': name.decode('ascii'), 'source_offset': offset(lib, target),
                     'source_bytes': block['end'] - target, 'string_offset': string[1], 'string_bytes': len(name) + 1})
    files = [row['file'] for row in rows]
    # A file repeats only as the fallback to language 0's.
    if any(name != files[0] for index, name in enumerate(files) if name in files[:index]):
        return {}
    return {'rows': rows, 'provenance': {
        'dispatch': {'offset': offset(lib, dispatch['start']), 'bytes': dispatch['end'] - dispatch['start'] - len(cases)},
        'table': {'offset': offset(lib, table), 'bytes': len(cases)}}}


# The register-held flag selects the branch; the large guard allocates the
# branch's first record before it tests the flag.
TEXTURE_GUARDS = {'medium': """
ldr.w r0, [pc, #{&flag}]
add r0, pc
ldr r0, [r0]
ldrb r0, [r0]
cmp r0, #0
beq.w #{other}
""", 'large': """
ldr.w r0, [pc, #{&flag}]
add r0, pc
ldr r0, [r0]
ldrb r4, [r0]
movs r0, #0x10
blx <_Znwj>
mov r6, r0
mov sl, r8
cmp r4, #0
beq.w #{other}
"""}


def path_references(lib, symbol):
    """{resource path: addresses of the `add rN, pc` completing its literal} in a function."""
    from .android_library import instructions
    text, pending, found = lib.text, {}, {}
    for ins in instructions(lib, symbol) or []:
        if ins.mnemonic in ('ldr', 'ldr.w') and ins.op_str.split(', ', 1)[1].startswith('[pc, #'):
            pool = ((ins.address + 4) & ~3) + ins.operands[1].mem.disp
            pending[ins.operands[0].reg] = struct.unpack_from('<I', lib.data, text['offset'] + pool - text['address'])[0]
        elif ins.mnemonic == 'add' and ins.op_str.endswith(', pc') and ins.operands[0].reg in pending:
            path = lib.resource_string((pending.pop(ins.operands[0].reg) + ins.address + 4) & 0xffffffff)
            if path:
                found.setdefault(path, []).append(ins.address)
    return found


def android_texture_choices(lib, records, registrations, flags):
    """Each atlas's three registrations sit behind the profile flags: the first load
    of its path literal after its record allocation lies in the iPadHD branch, the
    retinaDisplay branch or after both."""
    from .android_blocks import matches, offset
    guards = {}
    for kind, shape in TEXTURE_GUARDS.items():
        found = [block for block in matches(lib, BUILD, shape) if block['refs']['flag'] == [flags[kind]]]
        if len(found) != 1:
            return {}
        guards[kind] = found[0]
    medium, large = guards['medium'], guards['large']
    if large['start'] != medium['values']['other']:
        return {}
    references = path_references(lib, BUILD)

    def mode(at):
        if medium['end'] <= at < medium['values']['other']: return 'medium'
        if large['end'] <= at < large['values']['other']: return 'large'
        return 'baseline' if at >= large['values']['other'] else None
    choices = []
    for identifier in sorted({row['texture_id'] for row in records}):
        declarations = [r for r in registrations if r['id'] == identifier]
        if len(declarations) != 3 or any(r['kind'] != 'texture' or r['registration_type'] != 2 for r in declarations): return {}
        variants, offsets = {}, {}
        for row in declarations:
            allocation = row['source_offset'] - offset(lib, 0)
            found = mode(min((at for at in references.get(row['source_path'], []) if at > allocation), default=-1))
            if found is None or found in variants: return {}
            variants[found], offsets[found] = row['resource'], row['source_offset']
        choices.append({'texture_id': identifier, 'variants': variants, 'source_offsets': offsets})
    return {'rows': choices, 'provenance': {kind: {'offset': offset(lib, block['start']), 'bytes': block['end'] - block['start']}
                                            for kind, block in guards.items()}}
