"""Read fresh player statistics and equipment capacity declarations, statically.

Depends on validated vehicle, NPC statistics and cursor-zero staging anchors.
No executable bytes or gameplay instructions are returned to the engine.

Android: Level::createPlayer builds the Player with half extent 1200 and
copies the ship's shield and armor capacity (Ship::getMaxShieldHP/ArmorHP)
through Player::setMaxShieldHP/ArmorHP before marking it the player;
Ship::refreshValue clears both capacities and assigns item attributes 18
and 20 for item sorts 9 and 10 while walking the equipment in order; the
cursor-0 branch of LevelScript::LevelScript makes the player vulnerable.
"""
import struct
from .opening_loadout import template
from .ship_models import section_bytes

VALUES = {"half_extent":1200,"initial_active":True,"initial_damage_allowed":True,
          "is_player":True,"equipment_rule":"last_matching","missing_capacity":0,
          "item_type_value_index":5,"shield_equipment_type":9,"armor_equipment_type":10,
          "shield_property":18,"armor_property":20}


ANDROID_FACTORY = """
mov.w r0, #0x114
str.w r8, [sl, #8]
call _Znwj
mov r5, r0
ldr r0, [r6]
call _ZN6Status7getShipEv
call _ZN4Ship8getMaxHPEv
mov r2, r0
mov r0, r5
mov.w r1, #0x4b0
mov r3, r4
strd sb, r8, [sp]
call _ZN6PlayerC1Eiiiii
ldr.w r0, ={}
add r0, pc
ldr r6, [r0]
ldr r0, [r6]
call _ZN6Status7getShipEv
call {shield_getter}
mov r1, r0
mov r0, r5
call {shield_setter}
ldr r0, [r6]
call _ZN6Status7getShipEv
call {armor_getter}
mov r1, r0
mov r0, r5
call {armor_setter}
movs r0, #1
strb.w r0, [r5, #0x69]
"""
ANDROID_HELPERS = {'shield_getter': 'ldr r0, [r0, #0x1c]\nbx lr', 'armor_getter': 'ldr r0, [r0, #0x20]\nbx lr',
                   'shield_setter': 'vmov s0, r1\nvcvt.f32.s32 s0, s0\nstr.w r1, [r0, #0x94]\nvstr s0, [r0, #0x88]\nb.w {changed}',
                   'armor_setter': 'strd r1, r1, [r0, #0x8c]\nb.w {changed}'}
# Player::Player: `this` in r4; active (0xc0) set with the constructor flags.
ANDROID_ACTIVE = """
movs r0, #0
movs r1, #1
str.w r0, [r4, #0xd0]
add r5, sp, #4
strb.w r1, [r4, #0x70]
str.w r1, [r4, #0x10c]
strb.w r0, [r4, #0x44]
strb.w r0, [r4, #0x45]
strb.w r0, [r4, #0x68]
strb.w r1, [r4, #0xc0]
"""
# Ship::refreshValue: `this` in r4; shield, armor and the next two words cleared.
ANDROID_RESET = """
mov r4, r0
ldr.w r0, ={}
mov.w r1, #-1
vmov.i32 q8, #0
movs r2, #0
str r1, [r4, #0x4c]
strb.w r2, [r4, #0x50]
add.w r3, r4, #0x1c
strb.w r2, [r4, #0x51]
add r0, pc
strb.w r2, [r4, #0x5c]
add.w r2, r4, #0x3c
vst1.32 {d16, d17}, [r3]
"""
# Equipment array at 0x6c: r5 walks its words, r6 counts.
ANDROID_LOOP_ENTRY = """
ldr r1, [r4, #0x6c]
ldr r0, [r1]
cmp r0, #0
beq.w {empty}
ldr r0, ={}
vmov.f32 s20, #1.000000e+00
vldr s16, ={}
movs r5, #0
add r0, pc
vldr s18, ={}
vldr s22, ={}
mov.w sb, #1
ldr.w fp, [r0]
mov.w r8, #0x3f800000
ldr r0, ={}
movs r6, #0
add r0, pc
ldr.w sl, [r0]
b {head}
"""
ANDROID_LOOP_HEAD = """
ldr r0, [r1, #4]
ldr r0, [r0, r5]
cmp r0, #0
beq.w {skip}
call {type_getter}
cmp r0, #0x1d
bhi.w {next}
tbb [pc, r0]
"""
ANDROID_SHIELD = """
ldr r0, [r4, #0x6c]
movs r1, #0x12
ldr r0, [r0, #4]
ldr r0, [r0, r5]
call _ZN4Item12getAttributeEi
str r0, [r4, #0x1c]
movs r1, #0x13
ldr r0, [r4, #0x6c]
ldr r0, [r0, #4]
ldr r0, [r0, r5]
call _ZN4Item12getAttributeEi
str r0, [r4, #0x24]
b {next}
"""
ANDROID_ARMOR = """
ldr r0, [r4, #0x6c]
movs r1, #0x14
ldr r0, [r0, #4]
ldr r0, [r0, r5]
call _ZN4Item12getAttributeEi
str r0, [r4, #0x20]
b {next}
"""
ANDROID_LOOP_NEXT = """
ldr r0, [r4, #0x6c]
ldr r0, [r0, #4]
ldr r0, [r0, r5]
call _ZN4Item13getTotalPriceEv
ldr r1, [r4, #8]
add r0, r1
str r0, [r4, #8]
ldr r1, [r4, #0x6c]
ldr r0, [r1]
adds r6, #1
adds r5, #4
cmp r6, r0
blo.w {head}
"""
ANDROID_DAMAGE_DISPATCH = """
call _ZN6Status25getCurrentCampaignMissionEv
cmp r0, #0
str r4, [sp, #0x44]
beq {initial}
"""
ANDROID_DAMAGE = """
strd r6, r6, [r4]
ldr r0, [sp, #0x4c]
strb r6, [r0, #1]
mov r0, sl
ldr.w sb, [sp, #0x48]
strb.w r6, [sb, #0x48]
call _ZN5Level9getPlayerEv
movs r1, #1
movs r4, #1
call _ZN9PlayerEgo21setComputerControlledEb
mov r0, sl
call _ZN5Level9getPlayerEv
ldr r0, [r0]
movs r1, #1
call {damage_setter}
"""


def android_player(lib):
    from .android_shapes import Listing
    level = Listing(lib, '_ZN5Level12createPlayerEv')
    factory = level.unique(ANDROID_FACTORY)
    if factory is None:
        return {}
    helpers = {key: Listing(lib, factory[key]).at(template, 0) for key, template in ANDROID_HELPERS.items()}
    if None in helpers.values() or helpers['shield_setter']['changed'] != helpers['armor_setter']['changed']:
        return {}
    stats = Listing(lib, '_ZN6PlayerC1Eiiiii')
    active = stats.unique(ANDROID_ACTIVE)
    if active is None or not stats.holds_this('r4', active.first):
        return {}
    ship = Listing(lib, '_ZN4Ship12refreshValueEv')
    reset, entry, head, following = (ship.unique(t) for t in (ANDROID_RESET, ANDROID_LOOP_ENTRY, ANDROID_LOOP_HEAD, ANDROID_LOOP_NEXT))
    # r4 holds `this` from its first copy (the reset opens with one) through the loop.
    if None in (reset, entry, head, following) or not ship.holds_this('r4', following.last):
        return {}
    if not (ship.target(entry['head']) == ship.target(following['head']) == head.first
            and ship.target(head['next']) == following.first and ship.target(head['skip']) == following.first + 8):
        return {}
    type_getter = Listing(lib, head['type_getter']).at('ldr r0, [r0, #8]\nbx lr', 0)
    # cmp #0x1d: 30 item sorts; exactly one dispatches to each assignment.
    targets = [ship.case(head.last, sort) for sort in range(30)]
    assignments = {}
    for key, sort, template in (('shield', 9, ANDROID_SHIELD), ('armor', 10, ANDROID_ARMOR)):
        found = ship.at(template, targets[sort]) if targets[sort] is not None else None
        if found is None or targets.count(targets[sort]) != 1 or ship.target(found['next']) != following.first:
            return {}
        assignments[key] = found
    script = Listing(lib, '_ZN11LevelScriptC1EP5LevelP3HudP5RadarP18TargetFollowCamera')
    dispatch = script.unique(ANDROID_DAMAGE_DISPATCH)
    permission = script.follow(dispatch, 'initial', ANDROID_DAMAGE)
    setter = Listing(lib, permission['damage_setter']).at('strb.w r1, [r0, #0xc2]\nbx lr', 0) if permission else None
    if type_getter is None or setter is None:
        return {}
    provenance = {'factory': factory.span(), 'active': active.span(), 'reset': reset.span(), 'loop_entry': entry.span(),
                  'loop_head': head.span(), 'type_getter': type_getter.span(), 'loop_next': following.span(),
                  'shield_assignment': assignments['shield'].span(), 'armor_assignment': assignments['armor'].span(),
                  'damage_dispatch': dispatch.span(), 'damage_permission': permission.span(), 'damage_setter': setter.span(),
                  **{key: shape.span() for key, shape in helpers.items()}}
    table = ship.span(head.last, head.last)['offset'] + 4
    provenance.update(shield_entry={'offset': table + 9, 'bytes': 1}, armor_entry={'offset': table + 10, 'bytes': 1})
    return dict(VALUES, provenance=provenance)


def extract_player_initialization(mach, actors, vehicle, staging):
    if mach.architecture == 'android-armv7':
        if not actors.get('npc_initialization') or not staging:
            return {}
        if vehicle.get('equipment_rule') != 'last_matching' or vehicle.get('item_type_value_index') != 5:
            return {}
        return android_player(mach)
    import capstone
    arch = mach.architecture
    if arch not in LAYOUTS or not actors.get('npc_initialization') or not vehicle or not staging:
        return {}
    mac = arch == 'x86_64'
    decoder = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB)
    decoder.detail = True
    text = mach.text
    code = mach.data[text['offset']:text['offset'] + text['length']]
    provenance = {}
    matches = {}
    addresses = {}

    def require(value):
        if not value: raise ValueError('Unsupported fresh player initialization')

    def anchor(data, key):
        row = data['provenance'][key]
        at = row['offset'] - mach.slice_offset - text['offset']
        require(type(at) is int and 0 <= at < len(code) and 0 < row['bytes'] <= len(code) - at)
        return text['address'] + at

    def match(key, address):
        size, spec = LAYOUTS[arch][key]
        found = section_bytes(mach, address, size, b'__text')
        result = template(spec).fullmatch(found[0]) if found else None
        require(result is not None)
        provenance[key] = {'offset':found[1], 'bytes':size}
        matches[key] = result
        addresses[key] = address
        return address

    def target(key, field, mnemonic='bl'):
        m = matches[key]; address = addresses[key]
        if mac: return address + m.end(field) + int.from_bytes(m[field], 'little', signed=True)
        ins = list(decoder.disasm(m[field], address + m.start(field)))
        require(len(ins) == 1 and ins[0].mnemonic == mnemonic and ins[0].operands[-1].type == capstone.arm.ARM_OP_IMM)
        return ins[0].operands[-1].imm

    try:
        rows = [m for m in template(LAYOUTS[arch]['factory'][1]).finditer(code) if mac or m.start() % 2 == 0]
        require(len(rows) == 1)
        match('factory', text['address'] + rows[0].start())
        npc = actors['npc_initialization']
        require(target('factory', 'call_28' if mac else 'call_26') == anchor(npc, 'stats_wrapper'))
        require(target('factory', 'call_43' if mac else 'call_42') == target('factory', 'call_69' if mac else 'call_66'))
        for key, field in [('shield_getter','call_51' if mac else 'call_48'),
                           ('armor_getter','call_77' if mac else 'call_72'),
                           ('shield_setter','call_61' if mac else 'call_58'),
                           ('armor_setter','call_87' if mac else 'call_82')]:
            match(key, target('factory', field))
        require(target('shield_setter','call_24' if mac else 'call_20','b.w') ==
                target('armor_setter','call_18' if mac else 'call_8','b.w'))
        match('active', anchor(npc, 'active' if mac else 'flags') + (0 if mac else 2))
        match('damage_permission', anchor(staging,'initial') + (0x56 if mac else 0x30))
        require(target('damage_permission','call_1' if mac else 'call_0') == anchor(staging,'player_getter'))
        match('damage_setter', target('damage_permission','call_14' if mac else 'call_12'))

        table = anchor(vehicle,'equipment_table')
        size = 120 if mac else 30
        found = section_bytes(mach, table, size, b'__text')
        require(found is not None)
        provenance['equipment_table'] = {'offset':found[1], 'bytes':size}
        entries = struct.unpack('<30i',found[0]) if mac else found[0]
        for key, type_id in [('shield_assignment',VALUES['shield_equipment_type']),
                             ('armor_assignment',VALUES['armor_equipment_type'])]:
            # Type indices are checked against the actual dispatch table, not
            # accepted merely because a matching assignment exists elsewhere.
            address = table + entries[type_id] * (1 if mac else 2)
            require(sum(table + entry * (1 if mac else 2) == address for entry in entries) == 1)
            match(key,address)
            require(target(key,'call_18' if mac else 'call_8') == anchor(vehicle,'property_getter'))
        selector = anchor(vehicle,'equipment_selector')
        for key, delta in ({'reset':-175,'loop_initial':-37,'loop_next':713} if mac else
                           {'zero_vector':-210,'reset':-166,'loop_offset':-102,'loop_initial':-68,'loop_next':426}).items():
            match(key,selector + delta)
        if mac:
            require(target('loop_initial','ref_6') == table)
            require(target('loop_initial','ref_13') == target('factory','ref_35'))
            require(target('loop_initial','call_33') == addresses['loop_next'] + 4)
            require(target('loop_next','call_16') == selector - 17)
        else:
            require(target('loop_initial','call_2','b') == selector - 10)
            require(target('loop_next','call_10','blo.w') == selector - 10)
        require(vehicle['equipment_rule'] == 'last_matching' and vehicle['item_type_value_index'] == 5)
        spans = sorted((r['offset'], r['offset'] + r['bytes']) for r in provenance.values())
        require(all(a[1] <= b[0] for a,b in zip(spans,spans[1:])))
        return dict(VALUES, provenance=provenance)
    except (ValueError,KeyError,TypeError,IndexError,OverflowError,struct.error):
        return {}

LAYOUTS = {'x86_64': {'factory': (96,
                        '4889c7e8 {call_4:4} 4c89f7beb004000089c24489e14589e84589f9e8 {call_28:4} 488d1d '
                        '{ref_35:4} 488b3be8 {call_43:4} 4889c7e8 {call_51:4} 4c89f789c6e8 {call_61:4} 488b3be8 '
                        '{call_69:4} 4889c7e8 {call_77:4} 4c89f789c6e8 {call_87:4} 41c6466d01'),
            'shield_getter': (9, '554889e58b471c5dc3'),
            'armor_getter': (9, '554889e58b47205dc3'),
            'shield_setter': (28, '554889e589b79c000000f30f2ac6f30f1187900000005de9 {call_24:4}'),
            'armor_setter': (22, '554889e589b79800000089b7940000005de9 {call_18:4}'),
            'shield_assignment': (26, '498b4770488b40084a8b3c30be12000000e8 {call_18:4} 4189471c'),
            'armor_assignment': (26, '498b4770488b40084a8b3c30be14000000e8 {call_18:4} 41894720'),
            'reset': (8, '49c7471c00000000'),
            'loop_initial': (37,
                             '4531f6488d1d {ref_6:4} 4c8d25 {ref_13:4} 4d89f5488b48084a8b3c314885ff0f84 '
                             '{call_33:4}'),
            'loop_next': (20, '498b47704983c60849ffc5443b280f82 {call_16:4}'),
            'damage_permission': (18, 'e8 {call_1:4} 488b38be01000000e8 {call_14:4}'),
            'damage_setter': (13, '554889e54088b7ca0000005dc3'),
            'active': (7, 'c683c800000001')},
 'armv7': {'factory': (94,
                       '{call_0:4} 0246032114981c910f990b9b8de80a004ff49661109b {call_26:4} '
                       '149c4ff0ff36089d28681c96 {call_42:4} 1c96 {call_48:4} 014620461c96 {call_58:4} 28681c96 '
                       '{call_66:4} 1c96 {call_72:4} 014620461c96 {call_82:4} 1498012180f86910'),
           'shield_getter': (4, 'c0697047'),
           'armor_getter': (4, '006a7047'),
           'shield_setter': (24, '41ec301bc0f89410bbff200680ed220a20ef1001 {call_20:4}'),
           'armor_setter': (12, 'c0f88c10c0f89010 {call_8:4}'),
           'shield_assignment': (14, 'e06e122140688059 {call_8:4} e061'),
           'armor_assignment': (14, 'e06e142140688059 {call_8:4} 2062'),
           'zero_vector': (4, 'c0ef5000'),
           'reset': (12, '04f11c0084f85c2040f98f0a'),
           'loop_offset': (8, '0026a060e16e0868'),
           'loop_initial': (4, '0025 {call_2:2}'),
           'loop_next': (14, 'e16e0868013504368542 {call_10:4}'),
           'damage_permission': (16, '{call_0:4} 00680121cdf85068 {call_12:4}'),
           'damage_setter': (6, '80f8c2107047'),
           'active': (36, '01214ff0ff35c6f8d00086f8701004acc6f80c1186f8440086f8450086f8680086f8c010')}}
