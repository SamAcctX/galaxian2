"""Static equipment-bound shield recharge and ordinary player-pass declarations.

Android: PlayerEgo's constructor clears the recharge clock and blocked flag and
stores the pulse max shield / (Ship::getShieldRegen / 100); PlayerEgo::update
adds elapsed time while regen and hull are positive and, past 100 ms, clears
the clock and adds one pulse with Player::regenerateShield; MGame::OnUpdate
updates the player before Level::update. Ship::refreshValue clears the regen
and assigns item attribute 19 with the shield's sort.
"""
import struct
from .opening_loadout import template
from .ship_models import section_bytes

VALUES={'equipment_property':19,'period_ms':100,'capacity_divisor':100.0,
        'initial_elapsed_ms':0,'discard_excess_time':True,'pulses_per_update':1,
        'requires_living_hull':True,'before_world_weapons':True}


# PlayerEgo::PlayerEgo: `this` in r4, zeros in r6 and q8.
ANDROID_ENTRY = """
mov r4, r0
addw r0, pc, #{}
vmov.i32 q8, #0
vld1.64 {d18, d19}, [r0:0x80]
add.w r0, r4, #0x44
mov.w sl, #0x3f800000
str.w sl, [r4, #0x40]
movs r6, #0
"""
ANDROID_CLOCK_ZERO = """
add.w r2, r4, #0x118
vst1.64 {d16, d17}, [r2]
"""
ANDROID_BLOCKED_ZERO = 'strb.w r6, [r4, #0x24]'
ANDROID_DIVISOR = 'vldr s16, ={divisor}'
ANDROID_PULSE = """
ldr r0, [r6]
call _ZN6Status7getShipEv
call {shield_getter}
mov r5, r0
ldr r0, [r6]
call _ZN6Status7getShipEv
call {getter}
vmov s0, r0
mov.w r0, #-1
vmov s2, r5
vcvt.f32.s32 s0, s0
vcvt.f32.s32 s2, s2
vdiv.f32 s0, s0, s16
vdiv.f32 s0, s2, s0
vstr s0, [r4, #0x218]
"""
# PlayerEgo::update: `this` in sb, elapsed milliseconds in r8; the clock is 64-bit.
ANDROID_RECHARGE = """
ldr.w r0, ={}
add r0, pc
ldr r0, [r0]
ldr r0, [r0]
call _ZN6Status7getShipEv
call {getter}
cmp r0, #1
blt {@skip}
ldr.w r0, [sb]
call {hull_getter}
cmp r0, #1
blt {@skip}
ldrd r0, r1, [sb, #0x118]
adds.w r0, r0, r8
adc.w r1, r1, r8, asr #31
strd r0, r1, [sb, #0x118]
subs r0, #0x65
sbcs r0, r1, #0
blt {@skip}
add.w r0, sb, #0x118
movs r1, #0
strd r1, r1, [r0]
ldr.w r1, [sb, #0x218]
ldr.w r0, [sb]
call {adder}
skip: ldr.w r0, ={}
"""
ANDROID_HELPERS = {'getter': 'ldr r0, [r0, #0x24]\nbx lr', 'hull_getter': 'ldr r0, [r0, #0x78]\nbx lr',
                   'adder': """
vldr s0, [r0, #0x88]
vmov s4, r1
vldr s2, [r0, #0x94]
vadd.f32 s0, s0, s4
vcvt.f32.s32 s2, s2
vcmpe.f32 s0, s2
vmrs apsr_nzcv, fpscr
it mi
vmovmi.f32 s2, s0
vstr s2, [r0, #0x88]
b.w {changed}
"""}
# MGame::OnUpdate: the player update (below 4 s frames) precedes Level::update.
ANDROID_ORDER = """
ldr.w r0, [fp, #0x50]
cmp.w r0, #0xfa0
bge {@world}
ldr.w r3, [fp, #0x70]
ldr.w lr, [fp, #0x80]
ldrd ip, r2, [fp, #0x78]
ldr.w r0, [fp, #0x164]
ldr.w r5, [fp, #0xd4]
cmp r0, #0
ldr r0, [sp, #0x18]
ldrb.w r6, [fp, #0x5f]
it gt
addgt.w r0, fp, #0x44
ldr.w r4, [fp, #0x14]
ldr r1, [r0]
ldr.w r0, [fp, #0x58]
strd lr, ip, [sp]
strd r5, r6, [sp, #8]
str r4, [sp, #0x10]
call {update}
world: ldr.w r0, [fp, #0x58]
call _ZN9PlayerEgo17isInRocketControlEv
ldr.w r2, [fp, #0x40]
mov r4, r0
ldr.w r0, [fp, #0x74]
ldrb.w r1, [fp, #0x5f]
asrs r3, r2, #0x1f
str r1, [sp]
call _ZN5Level6updateExb
"""


def android_recharge(lib):
    from .android_shapes import Listing
    from .player_initialization import ANDROID_HELPERS as PLAYER, ANDROID_RESET, ANDROID_SHIELD
    order = Listing(lib, '_ZN5MGame8OnUpdateEv').unique(ANDROID_ORDER)
    update = Listing(lib, order['update']) if order else None
    recharge = update.unique(ANDROID_RECHARGE) if update else None
    ctor = Listing(lib, '_ZN9PlayerEgoC1EP6Player')
    entry, clock, blocked, load, pulse = (ctor.unique(t) for t in (ANDROID_ENTRY, ANDROID_CLOCK_ZERO, ANDROID_BLOCKED_ZERO, ANDROID_DIVISOR, ANDROID_PULSE))
    if None in (recharge, entry, clock, blocked, load, pulse) or pulse['getter'] != recharge['getter']:
        return {}
    # r4 holds `this` from the entry; r6 and q8 stay zero to the stores; s16 keeps the divisor.
    stores = max(clock.last, blocked.last)
    if (not ctor.holds('r4', pulse.last) or not update.holds('sb', recharge.last)
            or any(ctor.writes(entry.last + 1, stores, r) for r in ('r6', 'q8', 'd16', 'd17'))
            or not load.last < pulse.first or ctor.writes(load.last + 1, pulse.last, 's16')):
        return {}
    helpers = {key: Listing(lib, recharge[key]).at(template, 0) for key, template in ANDROID_HELPERS.items()}
    if None in helpers.values() or Listing(lib, pulse['shield_getter']).at(PLAYER['shield_getter'], 0) is None:
        return {}
    ship = Listing(lib, '_ZN4Ship12refreshValueEv')
    reset, shield = ship.unique(ANDROID_RESET), ship.unique(ANDROID_SHIELD)
    divisor, divisor_word = load.pool('divisor')
    if reset is None or shield is None or struct.unpack('<f', struct.pack('<I', divisor))[0] != 100.0:
        return {}
    # The shield's sort also assigns attribute 19 (after attribute 18), cleared by the reset.
    # The recharge ends where its skip target (the repair's first line) starts.
    proof = {'application_order': order.span(), 'recharge': update.span(recharge.first, recharge.last - 1), 'pulse': pulse.span(), 'entry': entry.span(),
             'clock_zero': clock.span(), 'blocked_zero': blocked.span(), 'divisor_load': load.span(), 'divisor': divisor_word,
             'assignment': ship.span(shield.first + 6, shield.first + 11), 'equipment_zero': ship.span(reset.last, reset.last),
             **{key: shape.span() for key, shape in helpers.items()}}
    return dict(VALUES, provenance=proof)


def extract_player_recharge(mach,actors,vehicle,clock):
    if mach.architecture == 'android-armv7':
        player = actors.get('player_initialization')
        if not player or vehicle.get('equipment_rule') != 'last_matching' or not clock:
            return {}
        return android_recharge(mach)
    import capstone
    arch=mach.architecture
    if arch not in LAYOUTS:return {}
    mac=arch=='x86_64';proof={};blocks={};positions={}
    decoder=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);decoder.detail=True
    text=mach.text;code=mach.data[text['offset']:text['offset']+text['length']]
    def require(ok):
        if not ok:raise ValueError('Unsupported player shield recharge')
    def address(span):
        offset=span['offset']-mach.slice_offset-text['offset']
        require(0<=offset and offset+span['bytes']<=len(code))
        return text['address']+offset
    def read(key,at,size,section=b'__text'):
        result=section_bytes(mach,at,size,section);require(result is not None and len(result[0])==size)
        proof[key]={'offset':result[1],'bytes':size};return result[0]
    def match(key,at=None):
        size,spec=LAYOUTS[arch][key]
        if at is None:
            found=[m for m in template(spec).finditer(code) if mac or m.start()%2==0]
            require(len(found)==1);at=text['address']+found[0].start()
        row=template(spec).fullmatch(read(key,at,size));require(row is not None)
        blocks[key]=row;positions[key]=at;return at
    def target(key,field,kind='bl'):
        row=blocks[key];at=positions[key]
        if mac:return at+row.end(field)+int.from_bytes(row[field],'little',signed=True)
        rows=list(decoder.disasm(row[field],at+row.start(field)))
        require(len(rows)==1 and rows[0].mnemonic==kind and rows[0].operands[0].type==capstone.arm.ARM_OP_IMM)
        return rows[0].operands[0].imm
    try:
        player=actors['player_initialization'];require(player and vehicle['equipment_rule']=='last_matching')
        pulse=match('pulse');update=match('recharge')
        match('application_order',address(clock['provenance']['frame'])+(0x547 if mac else 0x2cc))
        match('world_pass',target('application_order','call_7e' if mac else 'call_74'))
        require(target('pulse','call_c')==address(player['provenance']['shield_getter']))
        require(target('pulse','call_4' if mac else 'call_6')==target('pulse','call_18'))
        getter=match('getter',target('pulse','call_20' if mac else 'call_1e'))
        require(target('recharge','call_12' if mac else 'call_10')==getter)
        require(target('recharge','call_a')==target('pulse','call_4' if mac else 'call_6'))
        match('hull_getter',target('recharge','call_1e'))
        match('adder',target('recharge','call_59' if mac else 'call_6a'))
        assignment=address(player['provenance']['shield_assignment'])+(26 if mac else 14)
        match('assignment',assignment)
        require(target('assignment','call_11' if mac else 'call_8')==address(vehicle['provenance']['property_getter']))
        match('equipment_zero',address(player['provenance']['reset'])+(-8 if mac else 0))
        ctor=pulse-(0x92e if mac else 0x51a)
        match('clock_zero',ctor+(0x302 if mac else 0x152))
        match('blocked_zero',ctor+(0x298 if mac else 0x12a))
        require(target('application_order','call_5b' if mac else 'call_50')==update-(0x234a if mac else 0x1d00))
        if mac:divisor_at=target('pulse','ref_2c')
        else:
            match('zero_vector',ctor+0x1c);match('zero_integer',ctor+0x2c)
            at=match('divisor_load',ctor+0x35e)
            rows=list(decoder.disasm(blocks['divisor_load']['ref_0'],at))
            require(len(rows)==1 and rows[0].mnemonic=='vldr' and rows[0].reg_name(rows[0].operands[0].reg)=='s20')
            op=rows[0].operands[1];require(op.type==capstone.arm.ARM_OP_MEM and rows[0].reg_name(op.mem.base)=='pc')
            divisor_at=((at+4)&~3)+op.mem.disp
        divisor=struct.unpack('<f',read('divisor',divisor_at,4,b'__const' if mac else b'__text'))[0]
        require(divisor==100.0)
        spans=sorted((p['offset'],p['offset']+p['bytes']) for p in proof.values())
        require(all(a[1]<=b[0] for a,b in zip(spans,spans[1:])))
        return dict(VALUES,provenance=proof)
    except (ValueError,KeyError,TypeError,IndexError,OverflowError,struct.error):return {}


LAYOUTS = {'x86_64': {'pulse': [69,
                      '498b7d00e8 {call_4:4} 4889c7e8 {call_c:4} 4189c6498b7d00e8 {call_18:4} '
                      '4889c7e8 {call_20:4} 0f57c0f30f2ac0f30f5e05 {ref_2c:4} '
                      'f3410f2acef30f5ec8f30f118bac020000'],
            'recharge': [94,
                         '488d05 {ref_0:4} 488b38e8 {call_a:4} 4889c7e8 {call_12:4} '
                         '85c07e43498b3ee8 {call_1e:4} '
                         '85c07e37498b866801000048038548fbffff498986680100004883f8657c1c49c7866801000000000000f3410f1086ac020000498b3ee8 '
                         '{call_59:4}'],
            'assignment': [26, '498b4770488b40084a8b3c30be13000000e8 {call_11:4} 41894724'],
            'getter': [9, '554889e58b47245dc3'],
            'hull_getter': [12, '554889e58b87800000005dc3'],
            'adder': [38,
                      '554889e5f30f588790000000f30f2a8f9c000000f30f5dc1f30f1187900000005de9 '
                      '{call_21:4}'],
            'clock_zero': [11, '48c7836801000000000000'],
            'blocked_zero': [4, 'c6434000'],
            'equipment_zero': [8, '49c7472400000000'],
            'application_order': [131,
                                  '41817d589f0f00007f56498d454c4183bdbc01000000490f4ec48b304d8b8d980000004d8b85a8000000498b8d88000000498b95a0000000498b7d60458b951c010000410fb65d6b418b45208944241083e301895c240844891424e8 '
                                  '{call_5b:4} 498b7d60e8 {call_64:4} '
                                  '88c349637548498bbd90000000410fb6556b83e201e8 {call_7e:4}'],
            'world_pass': [40,
                           '554889e54157415641554154534883ec288955b04989f64989ff41f687f8010000010f84b2000000']},
 'armv7': {'pulse': [62,
                     'daf800000896 {call_6:4} 0896 {call_c:4} 0446daf800000896 {call_18:4} 0896 '
                     '{call_1e:4} 40ec300bbbff200644ec304bbbff201680ee0a0a81ee000a85ed850a'],
           'recharge': [110,
                        '08984ff0ff340068ec94 {call_a:4} ec94 {call_10:4} 01282adbdbf80000ec94 '
                        '{call_1e:4} '
                        '012823dbdbe945018219069841eb0003652a4ff000014ff00000cbe945234ff0000238bf0121002bb8bf012208bf0a4662b90bf58a714ff0ff3208604860dbf81412dbf80000ec92 '
                        '{call_6a:4}'],
           'assignment': [14, '1321e06e40688059 {call_8:4} 6062'],
           'getter': [4, '406a7047'],
           'hull_getter': [4, '806f7047'],
           'adder': [42,
                     '90ed251a41ec301b90ed220abbff011600ef200db4eec10af1ee10fa48bfb0ee401a80ed221a '
                     '{call_26:4}'],
           'clock_zero': [8, '04f5887000f98f8a'],
           'blocked_zero': [4, '84f82420'],
           'equipment_zero': [12, '04f11c0084f85c2040f98f0a'],
           'zero_vector': [6, '80ef50800446'],
           'zero_integer': [2, '0022'],
           'divisor_load': [4, '{ref_0:4}'],
           'application_order': [120,
                                 'dbf84c00b0f57a6f24dadbf860014ff0ff34dbf86c3000280c98dbf87490dbf87cc0dbf87820dbf8d0e0c8bf0bf140000168dbf854009bf85b60dbf81450b494cdf800c0cdf80490cdf808e003960495 '
                                 '{call_50:4} dbf854004ff0ff36b496 {call_5e:4} '
                                 'dbf83c1005469bf85b30dbf87000ca17b496 {call_74:4}'],
           'world_pass': [30, 'f0b503af2de9000d2ded028b87b00546924695f858018b460093002865d0']}}
