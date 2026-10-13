"""Recover ordinary weapon additional-damage binding and non-player hit routing.

Android: Gun::setIndex stores the item's additional-damage attribute next to its
launch flag; Gun::calcCharacterCollision applies it through Player::damageEmp
unless it is the missing value, then routes the gun's damage to Player::damage,
unscaled unless the target is the player.
"""
import struct
from .opening_loadout import template
from .ship_models import section_bytes

MAC_STORE = '488d0d {table:4} 448b34994585f6418987a8000000'
ARM_STORE = '{low:4} {high:4} 7066'
MAC_EXTRA = '418bb7a800000081fe {missing:4} 7413410fb6975101000083e2014c89e7e8 {extra:4}'
ARM_EXTRA = 'dbf86410 {low:4} 0c94 {high:4} 814204d09bf8f9203046 {extra:4}'
MAC_ROUTE = '498b47084885c07437f6406001753141f644246d017429418b8f9c000000f3410f2a87a4000000410fb6975101000083e201f30f5905 {constant_32:4} f30f2cf0eb7141f644246d017450498b7f70e8 {call_4c:4} 4885c07442498b7f70e8 {call_5a:4} 4889c7e8 {call_62:4} 3c01752d418b8f9c000000f3410f2a87a4000000410fb6975101000083e201f30f5905 {constant_86:4} f30f5905 {constant_8e:4} eba2418b8f9c000000418bb7a4000000410fb6975101000083e2014c89e7e8 {call_b4:4}'
ARM_ROUTE = 'dbf804000f9c18b190f85c00002818d096f8690038b3dbf83800 {call_1a:4} 10b3dbf83800 {call_24:4} {call_28:4} 01281ad19bed180afbff000640ff980d40ff9a0d08e096f8690070b19bed180afbff000640ff9c0dbbff2007dbf8583010ee101a05e0cdcc4c3edbf85830dbf860109bf8f9203046 {call_74:4}'
MAC_NORMAL = '554889e54157415641554154534883ec18894dd44189f6'
ARM_NORMAL = 'f0b503af2de9000dadf1100424f00f04a54604f9ef8a84b00446984694f8c20092468b4600281cbf'
MAC_GETTER = '554889e5488b4f388b3931d2eb044883c202b8257899c539fa730d488b410839349075ea8b4490045dc3'
ARM_GETTER = '026bd2f80090b9f1000f08d05268002352f82300884207d002334b45f8d347f62500ccf29950704702eb830040687047'


# Gun::setIndex, right after the classification: the attribute into the gun.
ANDROID_STORE = """
ldr r1, ={}
str r0, [r4, #{additional}]
"""
# Gun::calcCharacterCollision (`this` in fp, the target in sb).
ANDROID_GATE = """
ldr.w r1, [fp, #{additional}]
movw r0, #{missing_low}
movt r0, #{missing_high}
cmp r1, r0
beq {@route}
ldrb.w r2, [fp, #0xf9]
mov r0, sb
call _ZN6Player9damageEmpEib
"""
# Owner without the hostile flag and the player as target: x s24; owner flagged (or
# none) and the player docked: x s16 x s18; any other target: the damage as is.
ANDROID_ROUTE = """
route: ldr.w r0, [fp, #4]
movs r4, #1
cbz r0, {@special}
ldrb.w r0, [r0, #0x5c]
cbz r0, {@nonhostile}
special: ldrb.w r0, [sb, #0x69]
cbz r0, {@normal}
ldr.w r0, [fp, #0x38]
call _ZN5Level9getPlayerEv
cbz r0, {@normal}
ldr.w r0, [fp, #0x38]
call _ZN5Level9getPlayerEv
call _ZN9PlayerEgo22isDockedToDockingPointEv
cmp r0, #1
bne {@normal}
vldr s0, [fp, #{damage}]
vcvt.f32.s32 s0, s0
vmul.f32 s0, s0, s16
vmul.f32 s0, s0, s18
b {@scaled}
nonhostile: ldrb.w r0, [sb, #0x69]
cbz r0, {@normal}
vldr s0, [fp, #{damage}]
vcvt.f32.s32 s0, s0
vmul.f32 s0, s0, s24
scaled: ldr.w r3, [fp, #0x58]
ldrb.w r2, [fp, #0xf9]
vcvt.s32.f32 s0, s0
vmov r1, s0
b {@hit}
normal: ldr.w r3, [fp, #0x58]
ldr.w r1, [fp, #{damage}]
ldrb.w r2, [fp, #0xf9]
hit: mov r0, sb
call _ZN6Player6damageEibi
"""
ANDROID_COLLISION = '_ZN3Gun22calcCharacterCollisionEv'


def android_route(lib):
    """(listing, shape, gate span, route span) of the collision's damage routing, or None."""
    from .android_shapes import Listing
    collision = Listing(lib, ANDROID_COLLISION)
    found = collision.unique(ANDROID_GATE + ANDROID_ROUTE)
    if found is None or not collision.holds('fp', found.last):
        return None
    split = found.first + ANDROID_GATE.strip().count('\n')
    return collision, found, collision.span(found.first, split), collision.span(split + 1, found.last)


def android_policy(lib, weapon):
    from .android_shapes import Listing
    from .weapon_parameters import android_classification
    launch = weapon['launch_modes']['provenance']
    found = android_classification(lib)
    setter = Listing(lib, '_ZN3Gun8setIndexEi')
    store = setter.at(ANDROID_STORE, found.last + 1) if found else None
    routed = android_route(lib)
    hit = Listing(lib, '_ZN6Player6damageEibi')
    if store is None or routed is None or found.span() != launch['classification'] or launch['property_getter'] != weapon['provenance']['property_getter']:
        return {}
    _, gate, gate_span, route_span = routed
    missing = struct.unpack('<i', struct.pack('<I', gate.value('missing_high') << 16 | gate.value('missing_low')))[0]
    # The gate compares the stored attribute with the getter's missing value.
    if gate['additional'] != store['additional'] or missing != struct.unpack('<i', bytes.fromhex('257899c5'))[0]:
        return {}
    return {'additional_damage_property': found.value('property'), 'missing_additional_damage': missing, 'nonplayer_damage_scale': 1.0,
            'provenance': {'classification': found.span(), 'additional_store': store.span(), 'property_getter': dict(launch['property_getter']),
                           'additional_gate': gate_span, 'damage_route': route_span, 'normal_hit': hit.span(0, 0)}}


def extract_ordinary_hit_policy(mach, weapon):
    from .weapon_parameters import MAC_LAUNCH_MODE, ARM_LAUNCH_MODE
    if mach.architecture == 'android-armv7':
        return android_policy(mach, weapon) if weapon.get('launch_modes') else {}
    import capstone
    if mach.architecture not in ('x86_64','armv7'):return {}
    mac=mach.architecture=='x86_64';proof={}
    text=mach.text;base=text['address'];code=mach.data[text['offset']:text['offset']+text['length']]
    decoder=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);decoder.detail=True
    def require(value):
        if not value:raise ValueError('Unsupported ordinary hit policy')
    def address(extent):return base+extent['offset']-mach.slice_offset-text['offset']
    def read(key,at,size):
        row=section_bytes(mach,at,size,b'__text');require(row is not None)
        proof[key]={'offset':row[1],'bytes':size};return row[0]
    def match(key,at,size,spec):
        result=template(spec).fullmatch(read(key,at,size));require(result is not None);return result
    def instruction(m,key,at,name,register=None):
        rows=list(decoder.disasm(m[key],at+m.start(key)))
        require(len(rows)==1 and rows[0].size==len(m[key]))
        i=rows[0];require(i.mnemonic==name and i.operands[-1].type==capstone.arm.ARM_OP_IMM)
        if register:require(i.reg_name(i.operands[0].reg)==register)
        return i.operands[-1].imm
    def call(m,key,at):
        return at+m.end(key)+int.from_bytes(m[key],'little',signed=True) if mac else instruction(m,key,at,'bl')
    try:
        p=weapon['launch_modes']['provenance'];classification=p['classification']
        at=address(classification)
        declaration=match('classification',at,65 if mac else 56,MAC_LAUNCH_MODE if mac else ARM_LAUNCH_MODE)
        if mac:
            first=-int.from_bytes(declaration['first'],'little',signed=True)
            count=declaration['count'][0];single=int.from_bytes(declaration['single'],'little')
        else:
            first=instruction(declaration,'first',at,'sub.w','r0')
            count=instruction(declaration,'count',at,'cmp','r0')
            single=instruction(declaration,'single',at,'cmp','r4')
            instruction(declaration,'address_low',at,'movw','r1')
            instruction(declaration,'address_high',at,'movt','r1')
        require(0<=first<=65535 and 1<=count<=64 and first+count<=65536 and 0<=single<=65535)
        require(list(range(first,first+count))+[single]==weapon['launch_modes']['alternate_item_ids'])
        getter=call(declaration,'getter',at)
        require(getter==address(weapon['provenance']['property_getter']))
        getter_spec=MAC_GETTER if mac else ARM_GETTER
        require(read('property_getter',getter,len(bytes.fromhex(getter_spec)))==bytes.fromhex(getter_spec))
        # Classification's property-10 request must flow into the collision field.
        tail=match('additional_store',at+len(declaration[0]),21 if mac else 10,MAC_STORE if mac else ARM_STORE)
        if not mac:
            instruction(tail,'low',at+len(declaration[0]),'movw','r1')
            instruction(tail,'high',at+len(declaration[0]),'movt','r1')
        spec=MAC_EXTRA if mac else ARM_EXTRA
        rows=[m for m in template(spec).finditer(code) if mac or m.start()%2==0];require(len(rows)==1)
        at=base+rows[0].start();extra=match('additional_gate',at,34 if mac else 28,spec)
        if mac:missing=int.from_bytes(extra['missing'],'little',signed=True)
        else:
            unsigned=instruction(extra,'low',at,'movw','r0')+(instruction(extra,'high',at,'movt','r0')<<16)
            missing=struct.unpack('<i',struct.pack('<I',unsigned))[0]
        # This is the integer absence sentinel returned by the recognized getter.
        require(missing==struct.unpack('<i',bytes.fromhex('257899c5'))[0])
        require(section_bytes(mach,call(extra,'extra',at),4,b'__text') is not None)
        route_at=at+len(extra[0])
        route=match('damage_route',route_at,185 if mac else 120,MAC_ROUTE if mac else ARM_ROUTE)
        require(call(route,'call_4c' if mac else 'call_1a',route_at)==call(route,'call_5a' if mac else 'call_24',route_at))
        normal=call(route,'call_b4' if mac else 'call_74',route_at)
        normal_spec=MAC_NORMAL if mac else ARM_NORMAL
        require(read('normal_hit',normal,len(bytes.fromhex(normal_spec)))==bytes.fromhex(normal_spec))
        spans=sorted((r['offset'],r['offset']+r['bytes']) for r in proof.values())
        require(all(a[1]<=b[0] for a,b in zip(spans,spans[1:])))
        return {'additional_damage_property':10,'missing_additional_damage':missing,
                'nonplayer_damage_scale':1.0,'provenance':proof}
    except (ValueError,KeyError,TypeError,IndexError,OverflowError,struct.error):return {}
