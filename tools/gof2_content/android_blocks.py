"""Exact Thumb instruction shapes inside named Android functions. Static reading only.

A shape lists one instruction per line as Capstone prints it. `label:` names
the line's address, `@label` is a branch target, `<symbol>` a call target
(checked by name), `{name}` an immediate read from the code, `{&role}` the
pc-relative literal of an `ldr rN, [pc, #..]` whose address the following
`add rN, pc` completes, and a tbb/tbh line ends with its inline case table
`{name:bytes}`. Readers find code by function name, never by distance.
"""
import re
import struct

HOLE = r'(-?(?:0x[0-9a-f]+|[0-9]+))'


def find(lib, symbol, shape):
    """The one place in the named function whose instructions read exactly as `shape`, or None."""
    found = matches(lib, symbol, shape)
    return found[0] if len(found) == 1 else None


def matches(lib, symbol, shape):
    """Every place in the named function whose instructions read exactly as `shape`."""
    from .android_library import instructions
    code = instructions(lib, symbol) or []
    lines = shape.strip().splitlines()
    first = lines[0].rpartition(': ')[2].split()[0]
    return [block for block in (match(lib, symbol, lines, ins.address) for ins in code if ins.mnemonic == first) if block]


def match(lib, symbol, lines, address):
    """`lines` read from `address` inside the named function: {'values', 'at' (line address
    of each hole), 'labels', 'tables', 'refs' ({role: [addresses]}), 'start', 'end'} or None."""
    import capstone
    from .android_library import callee
    if isinstance(lines, str):
        lines = lines.strip().splitlines()
    start, size = lib.symbols[symbol]
    end = start + size
    if not start <= address < end:
        return None
    decoder = lib.__dict__.get('_shapes')
    if decoder is None:
        decoder = lib.__dict__['_shapes'] = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
        decoder.detail = True
    text = lib.text
    block = {'values': {}, 'at': {}, 'labels': {}, 'tables': {}, 'refs': {}, 'start': address}
    branches, pending, stream = [], {}, None
    for line in lines:
        label, _, line = line.rpartition(': ')
        if label:
            block['labels'][label] = address
        table = re.fullmatch(r'(.*) \{(\w+):(\d+)\}', line)
        if table:
            line = table[1]
        if stream is None:
            # One decoder pass between case tables keeps IT-block conditions.
            at = text['offset'] + address - text['address']
            stream = decoder.disasm(lib.data[at:text['offset'] + min(end, address + 4 * len(lines)) - text['address']], address)
        ins = next(stream, None)
        if ins is None:
            return None
        pieces = re.split(r'(\{&?\w+\}|@\w+|<\w+>)', line)
        pattern = ''.join(HOLE if p.startswith('{') else '#(0x[0-9a-f]+)' if p.startswith(('@', '<')) else re.escape(p) for p in pieces)
        read = re.fullmatch(pattern, (ins.mnemonic + ' ' + ins.op_str).strip())
        if not read:
            return None
        for name, value in zip(pieces[1::2], read.groups()):
            if name[0] == '@':
                branches.append((name[1:], int(value, 16)))
            elif name[0] == '<':
                if callee(lib, ins) != name[1:-1]:
                    return None
            elif name[1] == '&':
                pool = ((ins.address + 4) & ~3) + int(value, 0)
                if not text['address'] <= pool <= text['address'] + text['length'] - 4:
                    return None
                pending[ins.operands[0].reg] = (name[2:-1], struct.unpack_from('<I', lib.data, text['offset'] + pool - text['address'])[0])
            else:
                block['values'][name[1:-1]] = int(value, 0)
                block['at'][name[1:-1]] = address
        if ins.mnemonic == 'add' and ins.op_str.endswith(', pc') and ins.operands[0].reg in pending:
            role, word = pending.pop(ins.operands[0].reg)
            block['refs'].setdefault(role, []).append((word + ins.address + 4) & 0xffffffff)
        address += ins.size
        if table:
            # Case tables in these shapes have even sizes: code resumes right after them.
            at = text['offset'] + address - text['address']
            block['tables'][table[2]] = (address, lib.data[at:at + int(table[3])])
            address += int(table[3])
            stream = None
    if pending or any(block['labels'][name] != target for name, target in branches):
        return None
    block['end'] = address
    return block


def offset(lib, address):
    """File offset of a .text address."""
    return lib.text['offset'] + address - lib.text['address']
