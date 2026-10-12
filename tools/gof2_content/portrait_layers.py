"""Bounded portrait part IDs, stacking order and explicit placement tables.

Patterns recognize supported declaration layouts at import time only. Emitted
records contain numbers and provenance, never executable instructions.

Android: ImageFactory::loadImage reads the part bases and the named placement
tables IMAGE_OFFSETS_IPAD_HD, _IPAD_LARGE, _IPAD and IMAGE_OFFSETS behind the
iPadHD, iPadLarge and iPad flags; ImageFactory::loadChar loads four parts and
swaps the first and third.
"""
import struct
from .opening_loadout import template
from .speaker_bindings import data_region

MAC_LAYERS = """
554889e54157415653504863de4889de48c1e604488d05
{ref_17:4}
4801f04c63fa428b04b84531f685c00f88fe00000001c80fb7f0c745e400000000488d05
{ref_3f:4}
488b38488d55e4e8
{call_4b:4}
bf14000000e8
{call_55:4}
4989c6488d05
{ref_5f:4}
8a008b75e4240174174889d848c1e005488d0d
{ref_76:4}
4801c1428b14f9eb3a488d0d
{ref_86:4}
f601017409488d0d
{ref_92:4}
eb13488d0d
{ref_9b:4}
f601017526488d0d
{ref_a7:4}
4889da48c1e2054801ca428b14fa84c0742248c1e305488d05
{ref_c4:4}
eb524889d848c1e005488d0d
{ref_d4:4}
4801c1428b14f9488d05
{ref_e2:4}
f60001740d48c1e305488d05
{ref_f2:4}
eb24488d05
{ref_fb:4}
f60001740d48c1e305488d05
{ref_10b:4}
eb0b48c1e305488d05
{ref_118:4}
4801d84a8d44f8048b084c89f7e8
{call_12a:4}
4c89f04883c4085b415e415f5dc3
"""

MAC_ORDER = """
458b26418b4c9e0483f9ff74124489e689dae8
{call_13:4}
498b4f08488904d948ffc383fb0475dc498b4f08488b01488b5110488911498b4f0848894110
"""

ARM_LAYERS = """
f0b503af2de9000dadf1400424f00f04a54604f9ed8204f9efc290b0
{value_1c:4}
0d46
{value_22:4}
5e4978441e467944904600680024099003a80a915a490b9741f00101cdf834d079440c91
{call_4a:4}
{value_4e:4}
{value_52:4}
784400eb051050f82810002966db
{value_64:4}
3144
{value_6a:4}
01aa784401944ff0ff3489b2006800680494
{call_80:4}
14200494
{call_88:4}
{value_8c:4}
{value_90:4}
0290794409680e7801994eb1
{value_a0:4}
{value_a4:4}
784400eb451050f838202ce0
{value_b4:4}
{value_b8:4}
78440368
{value_c0:4}
{value_c4:4}
78441a78002a024617d1
{value_d2:4}
{value_d6:4}
7a4412681278002a09d0
{value_e4:4}
{value_e8:4}
7a4402eb451252f838202be0
{value_f8:4}
{value_fc:4}
7a4402eb4512002e52f8382020d0
{value_10e:4}
{value_112:4}
784400eb4510012600ebc800031d029800901b680496
{call_12c:4}
009c03a8
{call_134:4}
204610ac24f9ed8224f9efc2a7f11804a546bde8000df0bd1b78002be0d1
{value_156:4}
{value_15a:4}
78440068007828b1
{value_166:4}
{value_16a:4}
7844d2e7
{value_172:4}
{value_176:4}
7844cce7
"""

ARM_ORDER = """
56f8045b56f82430b3f1ff3f09d029462246cdf81080
{call_16:4}
0299496841f824000134042cedd1029c029841688b680a680b6040688260
"""


def extract_portrait_layers(mach):
    if mach.architecture == 'android-armv7':
        return android_layers(mach)
    import capstone
    mac = mach.architecture == 'x86_64'
    if not mac and mach.architecture != 'armv7': return {}
    text = mach.text
    code = mach.data[text['offset']:text['offset']+text['length']]
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    decoder.detail = True
    def unique(spec):
        matches = [m for m in template(spec).finditer(code) if mac or m.start()%2 == 0]
        if len(matches) != 1: raise ValueError('Missing or ambiguous portrait placement declaration')
        return matches[0]
    def relative(m, key):
        return text['address']+m.end(key)+struct.unpack('<i',m[key])[0]
    def immediate(m, key, mnemonic, register=None):
        instructions = list(decoder.disasm(m[key],text['address']+m.start(key)))
        if len(instructions) != 1: raise ValueError('Unknown portrait declaration instruction')
        ins = instructions[0]
        if ins.mnemonic != mnemonic or ins.operands[-1].type != 2: raise ValueError('Unknown portrait declaration scalar')
        if register is not None and (len(ins.operands) != 2 or ins.reg_name(ins.operands[0].reg) != register):
            raise ValueError('Portrait table register mismatch')
        return ins.operands[-1].imm
    def arm_ref(m, low, high, pc, register):
        delta = immediate(m,low,'movw',register)+(immediate(m,high,'movt',register)<<16)
        return (text['address']+m.start()+pc+delta)&0xffffffff
    def extent(m): return {'offset':mach.slice_offset+text['offset']+m.start(),'bytes':len(m[0])}
    try:
        layers = unique(MAC_LAYERS if mac else ARM_LAYERS)
        order = unique(MAC_ORDER if mac else ARM_ORDER)
        call = relative(order,'call_13') if mac else immediate(order,'call_16','bl')
        if call != text['address']+layers.start(): raise ValueError('Portrait order uses another layer definition')
        if mac:
            part_address = relative(layers,'ref_17')
            pairs = {'medium':('ref_76','ref_c4'), 'large':('ref_92','ref_f2'),
                     'expanded':('ref_d4','ref_10b'), 'baseline':('ref_a7','ref_118')}
            tables = {}
            for name,(first,second) in pairs.items():
                tables[name] = relative(layers,first)
                if tables[name] != relative(layers,second): raise ValueError('Inconsistent portrait placement tables')
            if relative(layers,'ref_86') != relative(layers,'ref_e2') or relative(layers,'ref_9b') != relative(layers,'ref_fb'):
                raise ValueError('Inconsistent portrait variant flags')
            flags = [relative(layers,k) for k in ['ref_5f','ref_86','ref_9b']]
        else:
            for key in layers.groupdict():
                if key.startswith('call_'):
                    immediate(layers,key,'blx' if key in ['call_4a','call_88','call_134'] else 'bl')
            arm_ref(layers,'value_1c','value_22',0x2c,'r0')
            arm_ref(layers,'value_64','value_6a',0x74,'r0')
            part_address = arm_ref(layers,'value_4e','value_52',0x5a,'r0')
            pairs = {'medium': [('value_a0','value_a4',0xac,'r0'), ('value_10e','value_112',0x11a,'r0')],
                     'large': [('value_c0','value_c4',0xcc,'r0')],
                     'expanded': [('value_e4','value_e8',0xf0,'r2'), ('value_166','value_16a',0x172,'r0')],
                     'baseline': [('value_f8','value_fc',0x104,'r2'), ('value_172','value_176',0x17e,'r0')]}
            tables = {}
            for name,refs in pairs.items():
                values = [arm_ref(layers,*ref) for ref in refs]
                if len(set(values)) != 1: raise ValueError('Inconsistent portrait placement tables')
                tables[name] = values[0]
            flags = [arm_ref(layers,'value_8c','value_90',0x9a,'r1'),
                     arm_ref(layers,'value_b4','value_b8',0xc0,'r0'),
                     arm_ref(layers,'value_d2','value_d6',0xde,'r2')]
            if flags[2] != arm_ref(layers,'value_156','value_15a',0x162,'r0'): raise ValueError('Inconsistent portrait variant flags')
        if len(set(flags)) != 3 or len(set(tables.values())) != 4: raise ValueError('Aliased portrait variant declarations')
        return layer_tables(mach, part_address, tables, {'selection':extent(layers), 'order':extent(order)})
    except (ValueError,IndexError,KeyError,struct.error):
        return {}


def layer_tables(mach, part_address, tables, provenance):
    try:
        addresses = {'part_bases':part_address, **tables}
        values = {}
        for name,address in addresses.items():
            size = 208 if name == 'part_bases' else 416
            source = data_region(mach,address,size)
            if source is None or address%4: raise ValueError('Missing portrait placement table')
            values[name] = list(struct.unpack('<'+str(size//4)+'i',source[0]))
            provenance[name] = {'offset':source[1], 'bytes':size}
        bases = values.pop('part_bases')
        if any(not -1 <= n <= 65534 for n in bases): raise ValueError('Invalid portrait part image ID')
        variants = {}
        for name,table in values.items():
            if any(n not in [0,16,32] for n in table[::2]) or any(not -8192 <= n <= 8192 for n in table[1::2]):
                raise ValueError('Unsupported portrait layer placement')
            variants[name] = [[{'anchor':table[f*8+p*2], 'y':table[f*8+p*2+1]} for p in range(4)] for f in range(13)]
        return {'part_bases':[bases[f*4:f*4+4] for f in range(13)],
                'draw_order':[2,1,0,3], 'variants':variants, 'provenance':provenance}
    except (ValueError,struct.error):
        return {}


# loadImage(family, part, index): base = part_bases[family][part] (16 bytes a
# family); the anchor and y come from the table the flags select (32 bytes a family).
ANDROID_LAYERS = """
push {r4, r5, r6, r7, lr}
add r7, sp, #0xc
sub sp, #0xc
ldr r0, [pc, #{&guard}]
mov r6, r1
ldr r1, [pc, #{&part_bases}]
mov r5, r2
add r0, pc
movs r4, #0
add r1, pc
ldr r2, [r0]
add.w r0, r1, r6, lsl #4
ldr.w r0, [r0, r5, lsl #2]
ldr r1, [r2]
str r1, [sp, #8]
cmp r0, #0
blt #{absent}
ldr r1, [pc, #{&canvas}]
add r0, r3
str r4, [sp, #4]
add r1, pc
ldr r2, [r1]
uxth r1, r0
ldr r0, [r2]
add r2, sp, #4
blx <_ZN11AbyssEngine11PaintCanvas13Image2DCreateEtRj>
movs r0, #0x14
blx <_Znwj>
mov r4, r0
ldr r0, [pc, #{&iPadHD}]
ldr r1, [sp, #4]
add r0, pc
ldr r0, [r0]
ldrb r0, [r0]
cbz r0, @large_x
ldr r0, [pc, #{&medium}]
add r0, pc
ldr r0, [r0]
add.w r0, r0, r6, lsl #5
add.w r0, r0, r5, lsl #3
ldr r2, [r0], #4
b @part
large_x: ldr r0, [pc, #{&iPadLarge}]
add r0, pc
ldr r0, [r0]
ldrb r0, [r0]
cbz r0, @expanded_x
ldr r0, [pc, #{&large}]
add r0, pc
b @x
expanded_x: ldr r0, [pc, #{&iPad}]
add r0, pc
ldr r0, [r0]
ldrb r0, [r0]
cbz r0, @baseline_x
ldr r0, [pc, #{&expanded}]
add r0, pc
b @x
baseline_x: ldr r0, [pc, #{&baseline}]
add r0, pc
x: ldr r2, [pc, #{&iPadLarge}]
ldr r0, [r0]
add r2, pc
add.w r0, r0, r6, lsl #5
add.w r0, r0, r5, lsl #3
ldr r3, [r2]
ldr r2, [r0]
ldrb r0, [r3]
cbz r0, @expanded_y
ldr r0, [pc, #{&large}]
add r0, pc
b @y
expanded_y: ldr r0, [pc, #{&iPad}]
add r0, pc
ldr r0, [r0]
ldrb r0, [r0]
cbz r0, @baseline_y
ldr r0, [pc, #{&expanded}]
add r0, pc
b @y
baseline_y: ldr r0, [pc, #{&baseline}]
add r0, pc
y: ldr r0, [r0]
add.w r0, r0, r6, lsl #5
add.w r0, r0, r5, lsl #3
adds r0, #4
part: ldr r3, [r0]
mov r0, r4
blx <_ZN9ImagePartC1Ejii>
"""
# loadChar: load each part that is not -1, then swap parts 0 and 2 (draw order 2, 1, 0, 3).
ANDROID_ORDER = """
ldr r4, [r5], #4
parts: ldr.w r3, [r5, r6, lsl #2]
cmp.w r3, #-1
beq @next
mov r1, r4
mov r2, r6
blx <_ZN12ImageFactory9loadImageEiii>
ldr.w r1, [r8, #4]
str.w r0, [r1, r6, lsl #2]
next: adds r6, #1
cmp r6, #4
bne @parts
ldr.w r0, [r8, #4]
ldr r2, [r0, #8]
ldr r1, [r0]
str r2, [r0]
ldr.w r0, [r8, #4]
str r1, [r0, #8]
"""
TABLES = {'medium': 'IMAGE_OFFSETS_IPAD_HD', 'large': 'IMAGE_OFFSETS_IPAD_LARGE', 'expanded': 'IMAGE_OFFSETS_IPAD', 'baseline': 'IMAGE_OFFSETS'}
FLAGS = {'iPadHD': '_ZN7Globals6iPadHDE', 'iPadLarge': '_ZN7Globals9iPadLargeE', 'iPad': '_ZN7Globals4iPadE'}


def android_layers(lib):
    from .android_blocks import find, got_symbol, offset
    layers = find(lib, '_ZN12ImageFactory9loadImageEiii', ANDROID_LAYERS)
    order = find(lib, '_ZN12ImageFactory8loadCharEPi', ANDROID_ORDER)
    if not layers or not order or layers['start'] != lib.symbols['_ZN12ImageFactory9loadImageEiii'][0]:
        return {}
    refs = layers['refs']
    if any(len(set(rows)) != 1 for rows in refs.values()):
        return {}
    # Flags and tables by the symbols their GOT slots are bound to.
    bound = {role: got_symbol(lib, refs[role][0]) for role in [*TABLES, *FLAGS]}
    if any(not bound[role] or bound[role][0] != name for role, name in [*TABLES.items(), *FLAGS.items()]):
        return {}
    if any(bound[role][2] != 416 for role in TABLES) or len({bound[role][1] for role in TABLES}) != 4:
        return {}
    extent = lambda block: {'offset': offset(lib, block['start']), 'bytes': block['end'] - block['start']}
    return layer_tables(lib, refs['part_bases'][0], {role: bound[role][1] for role in TABLES},
                        {'selection': extent(layers), 'order': extent(order)})
