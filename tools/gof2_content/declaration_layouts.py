"""Match a complete set of bounded source proofs, never mixed compiler layouts."""
import hashlib
from .ship_models import section_bytes


def recognize(mach, origin, layouts, links=None, *, constants=(), reader=section_bytes):
    """Return provenance for exactly one matching layout relative to a file offset.

    Entries are (delta, size, hex) in text, or (section, delta, size, hex).
    Names in constants use the constant-data section for three-field entries.
    Links tie named entries to offsets established by independent readers.
    A bounded reader can support additional sections; sha256: proofs cover large
    constant tables without embedding their bytes in the importer.
    Only source extents leave this helper; matched executable bytes are discarded.
    """
    anchor = mach.text['address'] + origin - mach.slice_offset - mach.text['offset']
    accepted = []
    for layout in layouts:
        proof = {}
        for key, rule in layout.items():
            section, delta, size, expected = ('__const' if key in constants else '__text', *rule) if len(rule) == 3 else rule
            if links and key in links and links[key] != origin + delta:
                break
            hashed = expected.startswith('sha256:')
            raw = bytes.fromhex(expected[7:] if hashed else expected)
            if size <= 0 or len(raw) != (32 if hashed else size):
                break
            found = reader(mach, anchor + delta, size, section.encode('ascii'))
            if found is None or len(found[0]) != size:
                break
            if (hashlib.sha256(found[0]).digest() if hashed else found[0]) != raw:
                break
            proof[key] = {'offset': found[1], 'bytes': size}
        else:
            if proof and (not links or set(links) <= proof.keys()):
                accepted.append(proof)
    return accepted[0] if len(accepted) == 1 else {}


def literal_address(lib, address):
    """Address built by `ldr rN, [pc, #k]` at `address` and the next `add rN, pc`.

    The add must be the first later instruction that touches rN, within 40 bytes.
    """
    import capstone
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    decoder.detail = True
    found = section_bytes(lib, address, 44, b'__text')
    if found is None:
        return None
    instructions = list(decoder.disasm(found[0], address))
    if not instructions or instructions[0].mnemonic not in ('ldr', 'ldr.w') or len(instructions[0].operands) != 2:
        return None
    load = instructions[0]
    register, memory = load.operands
    if memory.type != capstone.arm.ARM_OP_MEM or memory.mem.base != capstone.arm.ARM_REG_PC or memory.mem.index:
        return None
    pool = section_bytes(lib, ((address + 4) & ~3) + memory.mem.disp, 4, b'__text')
    if pool is None:
        return None
    for ins in instructions[1:]:
        if ins.mnemonic == 'add' and [op.reg for op in ins.operands] == [register.reg, capstone.arm.ARM_REG_PC]:
            return (int.from_bytes(pool[0], 'little') + ins.address + 4) & 0xffffffff
        read, written = ins.regs_access()
        if register.reg in read or register.reg in written:
            return None
    return None


def data_bytes(lib, address, size):
    """Bytes of any mapped section (code, strings, constants, initialized data)."""
    for section in lib.sections:
        if section['address'] <= address and address + size <= section['address'] + section['length']:
            offset = section['offset'] + address - section['address']
            return lib.data[offset:offset + size], offset + lib.slice_offset
    return None


def recognize_symbols(lib, layout):
    """Android proofs: every span sits inside the named function that holds it.

    Entries are (symbol, delta, size, hex | sha256:) within that function, or
    (symbol, delta, size, hex | sha256:, 'literal', start) for constant data
    `start` bytes into the table whose address the PC-relative literal pair at
    symbol + delta builds. Code is found by name, never by its distance from
    other code. Provenance keeps the function's (or table's) file offset as
    `anchor`, so offset - anchor is the entry's delta (or start).
    """
    proof = {}
    for key, rule in layout.items():
        if len(rule) not in (4, 6) or (len(rule) == 6 and (rule[4] != 'literal' or type(rule[5]) is not int or rule[5] < 0)):
            return {}
        symbol, delta, size, expected = rule[:4]
        hashed = expected.startswith('sha256:')
        raw = bytes.fromhex(expected[7:] if hashed else expected)
        extent = getattr(lib, 'symbols', {}).get(symbol)
        if extent is None or size <= 0 or len(raw) != (32 if hashed else size):
            return {}
        start, length = extent
        if len(rule) == 6:
            if not 0 <= delta <= length - 4:
                return {}
            address = literal_address(lib, start + delta)
            found = None if address is None else data_bytes(lib, address + rule[5], size)
            anchor = None if found is None else found[1] - rule[5]
        else:
            if not 0 <= delta <= length - size:
                return {}
            found = section_bytes(lib, start + delta, size, b'__text')
            anchor = None if found is None else found[1] - delta
        if found is None or len(found[0]) != size or (hashlib.sha256(found[0]).digest() if hashed else found[0]) != raw:
            return {}
        proof[key] = {'offset': found[1], 'bytes': size, 'anchor': anchor}
    return proof
