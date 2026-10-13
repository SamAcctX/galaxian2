"""Recover the ordinary type-zero projectile pool capacity, without running code.

Android: Level::createGun dispatches the weapon kind; kind zero's Gun::Gun takes
the slot count as its fourth argument, one slot for the alternate-launch items.
"""
import struct
from .opening_loadout import template
from .ship_models import section_bytes

MAC_RANGE = '''488b45d08d40 {first:1} bb0100000083f8 {count:1} 7217b801000000488b4dd081f9 {single:4} bb {slots:4} 0f44d8'''
ARM_RANGE = '''{first:4} {count:2} 1e462946 {single_branch:4} 0d914ff0010a {join:2}'''
ARM_SINGLE = '''{slots:4} {single:2} 0d9108bf4ff0010a'''
MAC_CALL = '''44897dac8b45108904244c89f74589e74489fe8b55c489d94589e8448b4d180f57c90f57d20f57db0f57e4e8 {ctor:4} 4c89f7488b75d0e8 {item:4} 8b45ac418986a0000000'''
ARM_CALL = '''03220c9611980021289204915a4605915346069107910891099179698ded038a029401912946cdf8008020ef1001 {ctor:4} 4ff0ff35119c28950d992046 {item:4} 11980c99c165'''


# Level::createGun keeps the incoming index (r1) at [sp, #0x34] and the kind (r3) in r6.
ANDROID_ENTRY = """
strd r2, r1, [sp, #0x30]
mov r6, r3
"""
ANDROID_KINDS = """
cmp r6, #{kinds}
bhi.w {}
mov.w fp, #0
tbh [pc, r6, lsl #1]
"""
# Kind zero: the slot count in r4, one for the alternate items; kind 3 aside,
# the ordinary constructor follows.
ANDROID_RANGE = """
ldr.w r0, ={}
mov sl, ip
ldr r5, [sp, #0x34]
add r0, pc
ldr.w r0, [r0, r5, lsl #2]
cmp r0, #0
blt.w {}
vmov s0, r8
strd r0, r4, [sp, #0x28]
sub.w r0, r5, #{first}
movs r4, #{slots}
cmp r0, #{count}
vcvt.f32.s32 s16, s0
it lo
movlo r4, #1
mov.w r0, #0x114
cmp r5, #{single}
it eq
moveq r4, #1
call _Znwj
mov fp, r0
cmp r6, #3
bne.w {ordinary}
"""
ANDROID_CONSTRUCTOR = """
movs r0, #0
ldr r2, [r7, #0x1c]
strd r0, r0, [sp, #0x10]
mov r3, r4
strd r0, r0, [sp, #0x18]
strd r0, r0, [sp, #0x20]
ldr.w r8, [sp, #0x30]
ldr r0, [r7, #0x24]
vstr s16, [sp, #0xc]
str.w sl, [sp, #8]
mov r1, r8
str r0, [sp, #4]
ldr r0, [r7, #0x18]
str r0, [sp]
mov r0, fp
call _ZN3GunC1EiiiiiifN11AbyssEngine6AEMath6VectorES2_
mov r0, fp
mov r1, r5
call _ZN3Gun8setIndexEi
"""


def android_capacity(lib, weapon):
    from .android_shapes import Listing
    factory = Listing(lib, '_ZN5Level9createGunEiiiiiiii')
    entry, kinds = factory.unique(ANDROID_ENTRY), factory.unique(ANDROID_KINDS)
    if entry is None or kinds is None or factory.writes(0, entry.first - 1, 'r1') or not factory.holds('r6', kinds.last, 'r3'):
        return {}
    selection = factory.at(ANDROID_RANGE, factory.case(kinds.last, 0))
    construction = factory.follow(selection, 'ordinary', ANDROID_CONSTRUCTOR)
    if construction is None:
        return {}
    first, count, single, slots = (selection.value(k) for k in ('first', 'count', 'single', 'slots'))
    launch = weapon['launch_modes']
    # The narrow move holds at most 255 slots.
    if list(range(first, first + count)) + [single] != launch['alternate_item_ids'] or slots < 1:
        return {}
    table = factory.span(kinds.last, kinds.last)['offset'] + 4
    return {'slots': slots, 'provenance': {'factory_entry': entry.span(), 'type_selector': kinds.span(), 'kind_zero': {'offset': table, 'bytes': 2},
                                           'range': selection.span(), 'constructor_call': construction.span(),
                                           'factory_call': dict(weapon['provenance']['tail']), 'item_classification': dict(launch['provenance']['classification'])}}


def extract_weapon_capacity(mach, weapon, factory):
    if not weapon.get('launch_modes'): return {}
    if mach.architecture == 'android-armv7':
        return android_capacity(mach, weapon)
    import capstone
    mac=mach.architecture=='x86_64';section=mach.text;base=section['address']
    code=mach.data[section['offset']:section['offset']+section['length']]
    decoder=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);decoder.detail=True
    provenance={}
    def require(test):
        if not test: raise ValueError('Unsupported weapon capacity')
    def record(key,address,size):
        row=section_bytes(mach,address,size,b'__text');require(row is not None)
        provenance[key]={'offset':row[1],'bytes':size};return row[0]
    def one(key,spec):
        matches=[m for m in template(spec).finditer(code) if mac or m.start()%2==0]
        require(len(matches)==1);m=matches[0];record(key,base+m.start(),len(m[0]));return m
    def instruction(m,key,name,registers):
        rows=list(decoder.disasm(m[key],base+m.start(key)))
        require(len(rows)==1 and rows[0].size==len(m[key]))
        i=rows[0];require(i.mnemonic==name and i.operands[-1].type==capstone.arm.ARM_OP_IMM)
        require([i.reg_name(op.reg) for op in i.operands[:-1]]==registers)
        return i.operands[-1].imm
    def call(m,key):
        return base+m.end(key)+int.from_bytes(m[key],'little',signed=True) if mac else instruction(m,key,'bl',[])
    try:
        require(record('factory_entry',factory,4)==bytes.fromhex('554889e5' if mac else 'f0b503af'))
        selection=one('range',MAC_RANGE if mac else ARM_RANGE)
        construction=one('constructor_call',MAC_CALL if mac else ARM_CALL)
        if mac:
            first=-int.from_bytes(selection['first'],'little',signed=True)
            count=selection['count'][0];singleton=int.from_bytes(selection['single'],'little')
            slots=int.from_bytes(selection['slots'],'little')
            selector=record('type_selector',factory+57,22)
            m=template('4489f8488d0d {table:4} 486304814801c84531edffe0').fullmatch(selector);require(m is not None)
            table=factory+57+m.end('table')+int.from_bytes(m['table'],'little',signed=True)
            zero=table+struct.unpack('<i',record('kind_zero',table,4))[0]
            require(zero==base+selection.start()-31 and construction.start()==selection.start()+253)
            item_prefix=17
        else:
            single=one('single',ARM_SINGLE)
            first=instruction(selection,'first','sub.w',['r1','r5'])
            count=instruction(selection,'count','cmp',['r1'])
            singleton=instruction(single,'single','cmp',['r1'])
            slots=instruction(single,'slots','mov.w',['sl'])
            require(instruction(selection,'single_branch','bhs.w',[])==base+single.start())
            require(instruction(selection,'join','b',[])==base+single.end())
            require(construction.start()==single.start()+188)
            require(record('type_selector',factory+112,4)==bytes.fromhex('dfe813f0'))
            table=factory+116
            zero=table+2*struct.unpack('<H',record('kind_zero',table,2))[0]
            require(zero==base+selection.start()-26)
            item_prefix=78
        require(0<=first<=65535 and 1<=count<=64 and first+count<=65536 and 0<=singleton<=65535 and 1<=slots<=4096)
        require(list(range(first,first+count))+[singleton]==weapon['launch_modes']['alternate_item_ids'])
        classification=weapon['launch_modes']['provenance']['classification']
        expected=base+classification['offset']-mach.slice_offset-section['offset']-item_prefix
        require(call(construction,'item')==expected)
        require(section_bytes(mach,call(construction,'ctor'),4,b'__text') is not None)
        require(0<base+selection.start()-factory<1024 and 0<base+construction.start()-factory<2048)
        provenance['factory_call']=dict(weapon['provenance']['tail'])
        provenance['item_classification']=dict(classification)
        spans=sorted((r['offset'],r['offset']+r['bytes']) for r in provenance.values())
        require(all(a[1]<=b[0] for a,b in zip(spans,spans[1:])))
        return {'slots':slots,'provenance':provenance}
    except (ValueError,KeyError,TypeError,IndexError,OverflowError,struct.error):return {}
