"""Static ordinary repair-device and fresh player hull declarations.

Android: right after the shield recharge, PlayerEgo::update reads the ship's
repair type (Ship::getRepairType, -1 without a device), adds elapsed time to
the hull and armor repair clocks and, past the period its type selects from
two float pairs, clears the clock and calls Player::regenerateHull or, with a
full hull, Player::regenerateArmor. Ship::refreshValue sets the type from item
sort 15 (index 75: slow); Ship::getMaxHP adds 40 per untagged upgrade to the
base hull, and Ship::Ship / Ship::clone start a ship without upgrades.
"""
import struct
from .opening_loadout import template
from .player_initialization import LAYOUTS as PLAYER_LAYOUTS
from .ship_models import section_bytes
from .scenery_population import import_symbol

VALUES={'equipment_type':15,'item_type_value_index':5,'item_id_value_index':1,'slow_item_id':75,'missing_device_mode':-1,
        'hull_periods_ms':[600,420],'armor_periods_ms':[1000,700],'hull_amount':1,'armor_amount':2,
        'initial_elapsed_ms':0,'base_hull_field':1,'upgrade_tag':0,'upgrade_bonus':40,
        'initial_upgrades':[],'after_shield_recharge':True,'requires_full_hull_for_armor':True,
        'discard_excess_time':True}


# PlayerEgo::update, `this` in sb: repair after the shield recharge (whose skip target opens it).
ANDROID_UPDATE = """
ldr.w r0, ={}
add r0, pc
ldr r0, [r0]
ldr r0, [r0]
call _ZN6Status7getShipEv
call {device_getter}
mov r5, r0
cmp r5, #0
blt {@skip}
ldr.w r0, [sb]
call {hull_getter}
cmp r0, #1
blt {@skip}
vmov.32 d16[0], r8
add.w r6, sb, #0x120
addw r2, pc, #{hull_periods}
cmp r5, #0
vld1.64 {d18, d19}, [r6]
it eq
addeq r2, #4
vmov.32 d16[1], fp
vmov.32 d17[0], r8
vldr s16, [r2]
vmov.32 d17[1], fp
vadd.i64 q8, q9, q8
vmov.32 r0, d16[0]
vmov.32 r1, d16[1]
vst1.64 {d16, d17}, [r6]
call __aeabi_l2f
vmov s0, r0
add.w r4, sb, #0x128
vcmpe.f32 s0, s16
vmrs apsr_nzcv, fpscr
ble {@armor}
movs r0, #0
strd r0, r0, [r6]
ldr.w r0, [sb]
call {hull_getter}
mov r6, r0
ldr.w r0, [sb]
call {hull_max}
cmp r6, r0
itt lt
ldrlt.w r0, [sb]
blxlt {hull_add}
armor: ldrd r0, r1, [r4]
addw r6, pc, #{armor_periods}
cmp r5, #0
it eq
addeq r6, #4
call __aeabi_l2f
vmov s0, r0
vldr s2, [r6]
vcmpe.f32 s0, s2
vmrs apsr_nzcv, fpscr
ble {@skip}
movs r0, #0
strd r0, r0, [r4]
ldr.w r0, [sb]
call {hull_getter}
mov r5, r0
ldr.w r0, [sb]
call {hull_max}
cmp r5, r0
blt {@skip}
ldr.w r0, [sb]
call {armor_current}
mov r5, r0
ldr.w r0, [sb]
call {armor_max}
cmp r5, r0
itt lt
ldrlt.w r0, [sb]
blxlt {armor_add}
skip: ldr.w r0, [sb, #0xac]
"""
ANDROID_HELPERS = {'device_getter': 'ldr r0, [r0, #0x4c]\nbx lr', 'hull_max': 'ldr.w r0, [r0, #0x84]\nbx lr',
                   'armor_current': 'ldr.w r0, [r0, #0x8c]\nbx lr', 'armor_max': 'ldr.w r0, [r0, #0x90]\nbx lr',
                   'hull_add': """
ldr r1, [r0, #0x78]
ldr.w r2, [r0, #0x84]
adds r1, #1
cmp r1, r2
it lt
movlt r2, r1
str r2, [r0, #0x78]
b.w {changed}
""", 'armor_add': """
ldrd r1, r2, [r0, #0x8c]
adds r1, #2
cmp r1, r2
it gt
movgt r1, r2
str.w r1, [r0, #0x8c]
b.w {changed}
"""}
# PlayerEgo::PlayerEgo (r4 `this`, r6 and q8 zero): the armor clock at 0x128 here, the
# hull clock at 0x120 with the recharge clock just after.
ANDROID_TIMERS = """
add.w r2, r4, #0x128
strd r6, r0, [r4, #0x108]
str.w r6, [r4, #0x110]
strb.w r6, [r4, #0x24]
str.w r6, [r4, #0x154]
str.w r6, [r4, #0x254]
strb.w r6, [r4, #0x158]
str.w r6, [r4, #0x15c]
strb.w r6, [r4, #0x160]
strb.w r6, [r4, #0x170]
vst1.64 {d16, d17}, [r2]
"""
# Ship::refreshValue, item sort 15: repair type 1, or 0 for item 75.
ANDROID_DEVICE = """
ldr r0, [r4, #0x6c]
ldr r0, [r0, #4]
ldr r0, [r0, r5]
call {item_id}
cmp r0, #0x4b
mov.w r0, #0
it ne
movne r0, #1
str r0, [r4, #0x4c]
b {next}
"""
ANDROID_HULL_SOURCE = """
push {r7, lr}
ldr r1, [r0, #0x78]
cbz r1, {@none}
ldr.w ip, [r1]
cmp.w ip, #0
beq {@none}
ldr.w lr, [r1, #4]
movs r2, #0
movs r1, #0
loop: ldr.w r3, [lr, r2, lsl #2]
adds r2, #1
cmp r3, #0
it eq
addeq r1, #0x28
cmp r2, ip
blo {@loop}
b {@base}
none: movs r1, #0
base: ldr r0, [r0, #4]
add r0, r1
pop {r7, pc}
"""
# Player::Player (`this` in r4): hull and maximum from the capacity argument.
ANDROID_CAPACITY = 'str r2, [r4, #0x78]\nstr.w r2, [r4, #0x84]'
ANDROID_CLONE = """
mov r4, r0
movs r0, #0x80
call _Znwj
mov r5, r0
ldr r0, [r4, #0x68]
ldr.w sb, [r4, #0x7c]
vldr s0, [r4, #0x18]
ldrd r1, r2, [r4]
ldr r3, [r4, #0xc]
ldr.w ip, [r4, #0x14]
ldrd lr, r8, [r0]
ldrd r6, r0, [r0, #8]
vldr s2, ={}
sub.w r0, r0, sb
vmul.f32 s0, s0, s2
str r0, [sp, #0x10]
mov r0, r5
strd r8, r6, [sp, #8]
strd ip, lr, [sp]
vstr s0, [sp, #0x14]
call {ctor}
ldr r0, [r4, #0x78]
cbz r0, {@done}
ldr r1, [r0]
cbz r1, {@done}
movs r6, #0
copy: ldr r0, [r0, #4]
ldr.w r1, [r0, r6, lsl #2]
mov r0, r5
call _ZN4Ship6addModEi
ldr r0, [r4, #0x78]
adds r6, #1
ldr r1, [r0]
cmp r6, r1
blo {@copy}
done: mov r0, r5
"""
# Ship::Ship (`this` in r4, r6 zero): no upgrades (0x78) before the first refresh.
ANDROID_UPGRADES = """
mov r0, r4
str r6, [r4, #0x70]
str r6, [r4, #0x64]
strd r6, r6, [r4, #0x78]
call _ZN4Ship12refreshValueEv
"""


def android_repair(lib):
    from .android_shapes import Listing, number
    from .declaration_layouts import data_bytes
    from .player_initialization import ANDROID_LOOP_HEAD, ANDROID_LOOP_NEXT, ANDROID_RESET
    from .player_recharge import ANDROID_CLOCK_ZERO, ANDROID_ENTRY, ANDROID_HELPERS as RECHARGE, ANDROID_RECHARGE

    def function(token):
        address = number(token) & ~1
        return lib.imports.get(address) or next((name for name, (start, _) in lib.symbols.items() if start == address), '')

    update = Listing(lib, '_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi')
    recharge = update.unique(ANDROID_RECHARGE)
    repair = update.at(ANDROID_UPDATE, recharge.last) if recharge else None
    if repair is None or not update.holds('sb', repair.last):
        return {}
    names = {key: repair[key] for key in ('device_getter', 'hull_max', 'armor_current', 'armor_max')}
    names.update(hull_add=function(repair['hull_add']), armor_add=function(repair['armor_add']))
    helpers = {key: Listing(lib, names[key]).at(template, 0) for key, template in ANDROID_HELPERS.items()}
    if (None in helpers.values() or helpers['hull_add']['changed'] != helpers['armor_add']['changed']
            or Listing(lib, repair['hull_getter']).at(RECHARGE['hull_getter'], 0) is None):
        return {}
    # Each period pair is (repair type 1, type 0); the armor pair follows the hull pair.
    first = repair.listing.code[repair.index('hull_periods')].address
    second = repair.listing.code[repair.index('armor_periods')].address
    first, second = ((first + 4) & ~3) + repair.value('hull_periods'), ((second + 4) & ~3) + repair.value('armor_periods')
    periods = data_bytes(lib, first, 16)
    if second != first + 8 or (struct.unpack('<4f', periods[0]) if periods else None) != (420.0, 600.0, 700.0, 1000.0):
        return {}
    ctor = Listing(lib, '_ZN9PlayerEgoC1EP6Player')
    entry, timers = ctor.unique(ANDROID_ENTRY), ctor.unique(ANDROID_TIMERS + ANDROID_CLOCK_ZERO)
    if (entry is None or timers is None or not ctor.holds('r4', timers.last)
            or any(ctor.writes(entry.last + 1, timers.last, r) for r in ('r6', 'q8', 'd16', 'd17'))):
        return {}
    ship = Listing(lib, '_ZN4Ship12refreshValueEv')
    head, following, reset = ship.unique(ANDROID_LOOP_HEAD), ship.unique(ANDROID_LOOP_NEXT), ship.unique(ANDROID_RESET)
    targets = [ship.case(head.last, sort) for sort in range(30)] if head else []
    device = ship.at(ANDROID_DEVICE, targets[15]) if targets and targets[15] is not None else None
    if (device is None or following is None or reset is None or targets.count(targets[15]) != 1
            or ship.target(device['next']) != following.first):
        return {}
    item_id = Listing(lib, device['item_id']).at('ldr r0, [r0]\nbx lr', 0)
    hull_source = Listing(lib, '_ZN4Ship8getMaxHPEv').at(ANDROID_HULL_SOURCE, 0)
    stats = Listing(lib, '_ZN6PlayerC1Eiiiii')
    capacity = stats.unique(ANDROID_CAPACITY)
    clone = Listing(lib, '_ZN4Ship5cloneEv').unique(ANDROID_CLONE)
    ship_ctor = Listing(lib, clone['ctor']) if clone else None
    zero, upgrades = (ship_ctor.unique('movs r6, #0'), ship_ctor.unique(ANDROID_UPGRADES)) if ship_ctor else (None, None)
    if (None in (item_id, hull_source, capacity, clone, zero, upgrades) or not stats.holds('r4', capacity.last)
            or not ship_ctor.holds('r4', upgrades.last) or not zero.last < upgrades.first or ship_ctor.writes(zero.last + 1, upgrades.last, 'r6')):
        return {}
    table = ship.span(head.last, head.last)['offset'] + 4
    proof = {'update': update.span(repair.first, repair.last - 1), 'timers_zero': ctor.span(timers.first, timers.first + 10),
             'device_assignment': device.span(), 'device_entry': {'offset': table + 15, 'bytes': 1},
             'device_zero': ship.span(reset.first + 2, reset.first + 5), 'item_id': item_id.span(), 'hull_source': hull_source.span(),
             'stats_capacity': capacity.span(), 'ship_clone': clone.span(), 'ship_ctor': upgrades.span(), 'upgrade_zero': zero.span(),
             'periods': {'offset': periods[1], 'bytes': 16}, **{key: shape.span() for key, shape in helpers.items()}}
    return dict(VALUES, provenance=proof)


def extract_player_repair(mach,actors,vehicle,loadout):
    if mach.architecture == 'android-armv7':
        player = actors.get('player_initialization', {})
        if not player.get('recharge') or not actors.get('npc_initialization') or vehicle.get('equipment_rule') != 'last_matching' or not loadout:
            return {}
        return android_repair(mach)
    import capstone
    arch=mach.architecture
    if arch not in LAYOUTS:return {}
    mac=arch=='x86_64';text=mach.text;proof={};blocks={};positions={}
    decoder=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);decoder.detail=True
    def require(ok):
        if not ok:raise ValueError('Unsupported ordinary player repair')
    def address(span):
        p=span['offset']-mach.slice_offset-text['offset']
        require(0<=p and p+span['bytes']<=text['length'])
        return text['address']+p
    def read(key,at,size,section=b'__text'):
        found=section_bytes(mach,at,size,section);require(found is not None and len(found[0])==size)
        proof[key]={'offset':found[1],'bytes':size};return found[0]
    def match(key,at):
        size,spec=LAYOUTS[arch][key];row=template(spec).fullmatch(read(key,at,size));require(row is not None)
        blocks[key]=row;positions[key]=at;return at
    def target(key,field,kind='bl'):
        row=blocks[key];at=positions[key]
        if mac:return at+row.end(field)+int.from_bytes(row[field],'little',signed=True)
        ins=list(decoder.disasm(row[field],at+row.start(field)))
        require(len(ins)==1 and ins[0].mnemonic==kind and ins[0].operands[-1].type==capstone.arm.ARM_OP_IMM)
        return ins[0].operands[-1].imm
    def branch_at(at):
        raw=section_bytes(mach,at,5 if mac else 4,b'__text');require(raw is not None)
        if mac:
            require(raw[0][0]==0xe8);return at+5+int.from_bytes(raw[0][1:],'little',signed=True)
        ins=list(decoder.disasm(raw[0],at));require(len(ins)==1 and ins[0].mnemonic=='bl')
        return ins[0].operands[0].imm
    def literal(key,field):
        if mac:return target(key,field)
        at=positions[key]+blocks[key].start(field);ins=list(decoder.disasm(blocks[key][field],at))
        require(len(ins)==1 and ins[0].mnemonic=='addw' and ins[0].reg_name(ins[0].operands[1].reg)=='pc' and ins[0].reg_name(ins[0].operands[0].reg)==('r2' if field=='ref_34' else 'r0'))
        return ((at+4)&~3)+ins[0].operands[2].imm
    try:
        player=actors['player_initialization'];recharge=player['recharge'];npc=actors['npc_initialization']
        require(recharge and vehicle['equipment_rule']=='last_matching')
        match('update',address(recharge['provenance']['recharge'])+recharge['provenance']['recharge']['bytes'])
        match('device_getter',target('update','call_12' if mac else 'call_c'))
        hull=address(recharge['provenance']['hull_getter'])
        for field in (['call_26','call_7b','call_c3'] if mac else ['call_22','call_86','call_e2']):require(target('update',field)==hull)
        maximum=match('hull_max',target('update','call_85' if mac else 'call_92'))
        require(target('update','call_cd' if mac else 'call_ee')==maximum)
        for key,field in [('hull_add','call_91' if mac else 'call_a0'),('armor_current','call_d9' if mac else 'call_fc'),
                          ('armor_max','call_e3' if mac else 'call_108'),('armor_add','call_ef' if mac else 'call_11a')]:match(key,target('update',field))
        require(target('hull_add','call_1e' if mac else 'call_10','b.w')==target('armor_add','call_24' if mac else 'call_10','b.w'))
        if not mac:
            helper=target('update','call_64','blx')
            require(helper==target('update','call_be','blx') and import_symbol(mach,helper)==b'___floatdisf')
        match('timers_zero',address(recharge['provenance']['clock_zero'])-(22 if mac else 8))
        table=address(player['provenance']['equipment_table']);raw=section_bytes(mach,table,120 if mac else 30,b'__text');require(raw is not None)
        entries=struct.unpack('<30i',raw[0]) if mac else raw[0]
        destination=table+entries[15]*(1 if mac else 2)
        require(sum(table+n*(1 if mac else 2)==destination for n in entries)==1)
        match('device_assignment',destination)
        match('item_id',target('device_assignment','call_c' if mac else 'call_6'))
        match('device_zero',address(player['provenance']['reset'])-(31 if mac else 40))
        factory=address(player['provenance']['factory']);size,spec=PLAYER_LAYOUTS[arch]['factory']
        raw=section_bytes(mach,factory,size,b'__text');require(raw is not None)
        blocks['factory']=template(spec).fullmatch(raw[0]);positions['factory']=factory;require(blocks['factory'] is not None)
        match('hull_source',target('factory','call_4' if mac else 'call_0'))
        match('stats_capacity',address(npc['provenance']['stats_entry'])+(173 if mac else 112))
        clone=address(loadout['provenance']['ship_clone'])
        match('ship_clone',branch_at(clone+(8 if mac else 6)))
        match('ship_ctor',target('ship_clone','call_5f' if mac else 'call_a6'))
        first=literal('update','ref_60' if mac else 'ref_34');second=literal('update','ref_a8')
        require(second==first+8)
        values=struct.unpack('<4f',read('periods',first,16,b'__const' if mac else b'__text'))
        require(values==(420.0,600.0,700.0,1000.0))
        spans=sorted((p['offset'],p['offset']+p['bytes']) for p in proof.values())
        require(all(a[1]<=b[0] for a,b in zip(spans,spans[1:])))
        return dict(VALUES,provenance=proof)
    except (KeyError,ValueError,TypeError,IndexError,OverflowError,struct.error):return {}


LAYOUTS = {'x86_64': {'update': [244,
                       '488d05 {ref_0:4} 488b38e8 {call_a:4} 4889c7e8 {call_12:4} '
                       '4189c74585ff0f88d1000000498b3ee8 {call_26:4} '
                       '85c00f8ec1000000498b8670010000488b8d48fbffff4801c84989867001000049018e78010000f3480f2ac04585ff0f94c00fb6c0488d0d '
                       '{ref_60:4} 0f2e0481762949c7867001000000000000498b3ee8 {call_7b:4} 89c3498b3ee8 '
                       '{call_85:4} 39c37d08498b3ee8 {call_91:4} f3490f2a86780100004585ff0f94c00fb6c0488d0d '
                       '{ref_a8:4} 0f2e0481763f49c7867801000000000000498b3ee8 {call_c3:4} 89c3498b3ee8 '
                       '{call_cd:4} 39c37c1e498b3ee8 {call_d9:4} 89c3498b3ee8 {call_e3:4} 39c37d08498b3ee8 '
                       '{call_ef:4}'],
            'device_getter': [9, '554889e58b474c5dc3'],
            'hull_max': [12, '554889e58b878c0000005dc3'],
            'hull_add': [35, '554889e58b87800000008b8f8c000000ffc039c80f4fc18987800000005de9 {call_1e:4}'],
            'armor_current': [12, '554889e58b87940000005dc3'],
            'armor_max': [12, '554889e58b87980000005dc3'],
            'armor_add': [41,
                          '554889e58b879400000083c0028987940000008b8f9800000039c87e06898f940000005de9 '
                          '{call_24:4}'],
            'timers_zero': [22, '48c783780100000000000048c7837001000000000000'],
            'device_assignment': [35,
                                  '498b4770488b40084a8b3c30e8 {call_c:4} 83f84b0f95c00fb6c04189474ce9 '
                                  '{call_1e:4}'],
            'device_zero': [8, '41c7474cffffffff'],
            'item_id': [8, '554889e58b075dc3'],
            'hull_source': [59,
                            '554889e5488b978800000031c04885d27424448b0231c04585c0741a488b520831c031f68d4828833cb2000f44c148ffc64439c672ee0347045dc3'],
            'stats_capacity': [12, '89938000000089938c000000'],
            'ship_clone': [148,
                           '554889e541574156534883ec184989ffbf98000000e8 {call_15:4} '
                           '4989c6498b7f688b470c412b8790000000458b4714418b4f0c418b37418b5704f3410f104718448b0f8b5f048b7f0889442410897c2408891c24f30f5905 '
                           '{ref_54:4} 4c89f7e8 {call_5f:4} '
                           '498b87880000004885c07424833800741f31db488b40088b34984c89f7e8 {call_81:4} '
                           '48ffc3498b87880000003b1872e3'],
            'ship_ctor': [240,
                          '554889e541574156415541545350f30f1145d44589ce4889fb8933895304894b0cc74310000000004489431444894308bf10000000e8 '
                          '{call_35:4} f30f1045d4f30f5e05 {ref_3f:4} '
                          '448b6d208b4d18448b7d1048894368448930448978048948084489680cf30f114318bf18000000e8 '
                          '{call_6e:4} 4989c4bf08000000e8 {call_7b:4} '
                          '498944240841c74424100100000048c7000000000041c70424000000004c8963704501f744037d184501ef4489ff4c89e6e8 '
                          '{call_b1:4} '
                          '48c7437800000000c743640000000048c7838800000000000000c78390000000000000004889df4883c4085b415c415d415e415f5de9 '
                          '{call_eb:4}']},
 'armv7': {'update': [286,
                      '08980068ec94 {call_6:4} ec94 {call_c:4} 0446002cc0f28380dbf800004ff0ff31ec91 '
                      '{call_22:4} 012879db00ee906b06980bf58e75 {ref_34:4} '
                      '65f98f2a002c08bf0432b24620ee900b01ee906b92ed008a21ee900b72efe00810ee900b30ee901b45f98f0a '
                      '{call_64:4} 40ec100bb4eec80af1ee10fa16dd00204ff0ff3628606860dbf80000ec96 {call_86:4} '
                      '0546dbf80000ec96 {call_92:4} 854204dadbf80000ec96 {call_a0:4} 0bf59275 {ref_a8:4} '
                      'd5e90023002c08bf0430194690ed008a1046 {call_be:4} '
                      '40ec100b5646b4eec80af1ee10fa25dd0020286068604ff0ff35dbf80000ec95 {call_e2:4} '
                      '0446dbf80000ec95 {call_ee:4} 844213dbdbf80000ec95 {call_fc:4} 0446dbf80000ec95 '
                      '{call_108:4} 844206dadbf800004ff0ff31ec91 {call_11a:4}'],
           'device_getter': [4, 'c06c7047'],
           'hull_max': [6, 'd0f884007047'],
           'hull_add': [20, '816fd0f8842001319142b8bf0a468267 {call_10:4}'],
           'armor_current': [6, 'd0f88c007047'],
           'armor_max': [6, 'd0f890007047'],
           'armor_add': [20, 'd0e92323911c9942c8bf1946c0f88c10 {call_10:4}'],
           'timers_zero': [8, '04f5907000f98f8a'],
           'device_assignment': [26, 'e06e40688059 {call_6:4} 4b284ff0000018bf0120e06457e0e06e'],
           'device_zero': [28, '4ff0ff31002284ed04ab04464df2b07004f13c03c0f21f00e1647844'],
           'item_id': [4, '00687047'],
           'hull_source': [50,
                           '816f00291cbfd1f80090b9f1000f01d100210be0d1f804c0002200215cf822300132002b08bf28314a45f7d3406808447047'],
           'stats_capacity': [18, 'b2670396d7f80c90bd68c6f8842080e82802'],
           'ship_clone': [216,
                          'f0b503af2de9000dadf1400424f00f04a54604f9ed8204f9efc29cb0054680200995 {call_22:4} '
                          '4cf61201c0f21f010e900e9879440d90a86e096800f1040b02680c929be81009d5f800a068680b90e8680a9032486e6995ed068a7844ed6f1591304916900fa841f0010117977944cdf864d0189101211091 '
                          '{call_78:4} abeb0500 {ref_80:4} '
                          '5146049008ff100d0c980b9a0a9b8ded050acdf80c80029401900d98009620ef1001 {call_a6:4} '
                          '0998816f064600291cbf086800280ed000244ff0ff350e98496851f824101095 {call_ca:4} '
                          'b16f013408688442f3d3'],
           'ship_ctor': [212,
                         'f0b503af2de9000dadf1400424f00f04a54604f9ed8204f9efc290b00446b868 {ref_20:4} '
                         '4ff0000997ed072a04f10805019484e8060082ee008a85e8090260611020 {call_42:4} '
                         '07f10c052ecda06680e82e000c2084ed068a20ef1001 {call_5c:4} '
                         '4df67e01c0f21f01029079442a4809687844099129490a9003a841f001010b977944cdf834d00c9101210491 '
                         '{call_8c:4} 0420 {call_92:4} '
                         '02990123029a00255060029a9360056002983a69019c0560f868e16610447a691044ba691044 '
                         '{call_bc:4} 4ff0ff3025676566a567e56704902046 {call_d0:4}']}}
