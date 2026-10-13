"""Recognize fresh NPC holding-mode declarations without emitting original code.

Android: PlayerFighter's constructor clears the selection and boost timers
and takes the 50000 spatial half extent unless Status::inAlienOrbit;
PlayerFighter::update (vtable slot 13) advances both timers; Level::render
updates then draws every enemy; KIPlayer::setToSleep holds them in mode 5 and
PlayerFighter::awake (slot 3) releases them; the opening declaration in
Level::createCampaignMission sets the player's suppression flag.
"""
import copy
from .opening_loadout import template

VALUES = {'actor_mode':5,'spatial_half_extent':50000,'initial_targeting_blocked':True,
          'selection_elapsed_ms':0,'boost_elapsed_ms':0}


# PlayerFighter::PlayerFighter, `this` in fp: zero q8 cleared over the timers at 0x1b4..0x1c3.
ANDROID_TIMERS = """
vmov.i32 q8, #0
mov.w r5, #0x40000000
strd r4, r4, [fp, #0x12c]
str.w r4, [fp, #0x134]
movs r0, #0
strd r5, r3, [fp, #0x1a0]
movs r6, #5
strd r5, r2, [fp, #0x1a8]
str.w r1, [fp, #0x124]
add.w r1, fp, #0x144
str.w r6, [fp, #0x1b0]
str.w r0, [fp, #0x34]
strb.w r0, [fp, #0x139]
str.w r0, [fp, #0x13c]
strb.w r0, [fp, #0x129]
strb.w r0, [fp, #0x12a]
strb.w r0, [fp, #0x13a]
str.w r0, [fp, #0x1f0]
str.w r0, [fp, #0xd4]
strb.w r0, [fp, #0x12b]
strb.w r0, [fp, #0x1f4]
vst1.32 {d16, d17}, [r1]
add.w r1, fp, #0x1c4
vst1.32 {d16, d17}, [r1]
add.w r1, fp, #0x1b4
vst1.32 {d16, d17}, [r1]
"""
ANDROID_RANGE = """
ldr r0, ={}
add r0, pc
ldr r0, [r0]
ldr r0, [r0]
call _ZN6Status12inAlienOrbitEv
movw r1, #{near}
cmp r0, #0
itt ne
movwne r1, #0x86a0
movtne r1, #1
str.w r1, [fp, #0x124]
"""
# PlayerFighter::update: `this` in r4, elapsed milliseconds in r8.
ANDROID_CLOCK = """
ldr.w r0, [r4, #0x1bc]
asr.w r5, r8, #0x1f
add r6, sp, #0x1a8
add r0, r8
str.w r0, [r4, #0x1bc]
ldr.w r0, [r4, #0x1b4]
add r0, r8
str.w r0, [r4, #0x1b4]
"""
ANDROID_ACTIVATION = """
push {r4, r5, r7, lr}
add r7, sp, #8
mov r4, r0
movs r5, #1
str.w r5, [r4, #0x84]
movs r1, #1
ldr r0, [r4, #4]
call _ZN6Player9setActiveEb
mov r0, r4
movs r1, #1
call _ZN13PlayerFighter17setExhaustVisibleEb
strb.w r5, [r4, #0xf1]
ldr r0, [r4, #0xc]
cbnz r0, {@geometry}
ldr r0, [r4, #8]
geometry: movs r1, #1
pop.w {r4, r5, r7, lr}
b.w {}
"""
# Level::render, `this` in r4, elapsed in r5: every enemy updates (slot 13) before it draws (slot 9).
ANDROID_WORLD = """
ldr.w r0, [r4, #0xf8]
cbz r0, {@done}
ldr r1, [r0]
cbz r1, {@done}
movs r6, #0
loop: ldr r0, [r0, #4]
ldr.w r0, [r0, r6, lsl #2]
ldr r1, [r0]
ldr r2, [r1, #0x34]
mov r1, r5
blx r2
ldr.w r0, [r4, #0xf8]
ldr r0, [r0, #4]
ldr.w r0, [r0, r6, lsl #2]
ldr r1, [r0]
ldr r1, [r1, #0x24]
blx r1
ldr.w r0, [r4, #0xf8]
adds r6, #1
ldr r1, [r0]
cmp r6, r1
blo {@loop}
done: ldr.w r0, [r4, #0xfc]
"""


def android_holding(lib):
    from .android_shapes import Listing, relocation, vtable_slot
    from .npc_initialization import ANDROID_ACTIVITY, ANDROID_DEACTIVATION
    from .opening_actors import ANDROID_ACTORS, ANDROID_LOOP, ANDROID_NEXT, ANDROID_PLAYER
    update, awake = (relocation(lib, vtable_slot(lib, '_ZTV13PlayerFighter', slot)) for slot in (13, 3))
    if update is None or awake is None:
        return {}
    fighter = Listing(lib, '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb')
    render = Listing(lib, '_ZN5Level6renderEi')
    shapes = {'timers': fighter.unique(ANDROID_TIMERS), 'range': fighter.unique(ANDROID_RANGE),
              'clock_step': Listing(lib, update[0]).unique(ANDROID_CLOCK), 'activation': Listing(lib, awake[0]).at(ANDROID_ACTIVATION, 0),
              'world_order': render.unique(ANDROID_WORLD), 'deactivation': Listing(lib, '_ZN8KIPlayer10setToSleepEv').at(ANDROID_DEACTIVATION, 0)}
    opening = Listing(lib, '_ZN5Level21createCampaignMissionEv').unique(ANDROID_ACTORS + ANDROID_LOOP + ANDROID_NEXT + ANDROID_PLAYER)
    if None in shapes.values() or opening is None or shapes['range'].value('near') != 50000:
        return {}
    setter = Listing(lib, shapes['deactivation']['setter']).at(ANDROID_ACTIVITY, 0)
    status = relocation(lib, fighter.address(shapes['range'].first + 1))
    if setter is None or status is None or status[0] != '_ZN7Globals6statusE':
        return {}
    if not (render.holds('r4', shapes['world_order'].last) and render.holds('r5', shapes['world_order'].last, 'r1')):
        return {}
    proof = {'virtual_update': update[1], **{key: shape.span() for key, shape in shapes.items()},
             # The player's flag 0x5e set to 1 (r8) after the actors, before the exit branch.
             'player_suppression': opening.listing.span(opening.last - 3, opening.last - 1)}
    result = copy.deepcopy(VALUES)
    result['provenance'] = proof
    return result


def extract_npc_holding(mach, actors, projection):
    if mach.architecture == 'android-armv7':
        initial = actors.get('npc_initialization') or {}
        if not (initial.get('guidance') and initial.get('activation') and initial.get('flight')) or initial.get('initial_active') is not False:
            return {}
        if [r['actor_kind'] for r in actors['actors']] != [8, 8, 8] or [r['hull_catalogue_id'] for r in actors['actors']] != [2, 23, 2]:
            return {}
        return android_holding(mach) if projection else {}
    import capstone
    mac=mach.architecture=='x86_64'
    if mach.architecture not in LAYOUTS:return {}
    decoder=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);decoder.detail=True
    proof={}
    def require(value):
        if not value:raise ValueError('Unsupported fresh NPC holding declaration')
    def address(span):
        offset=span['offset']-mach.slice_offset
        rows=[s for s in mach.sections if s['offset']<=offset and offset+span['bytes']<=s['offset']+s['length']]
        require(len(rows)==1)
        return rows[0]['address']+offset-rows[0]['offset']
    def read(key,at,size,segment=b'__TEXT',section=b'__text'):
        rows=[s for s in mach.sections if s['segment']==segment and s['name']==section and s['address']<=at and at+size<=s['address']+s['length']]
        require(len(rows)==1)
        offset=rows[0]['offset']+at-rows[0]['address']
        raw=mach.data[offset:offset+size];require(len(raw)==size)
        proof[key]={'offset':offset+mach.slice_offset,'bytes':size}
        return raw
    def target(row,field,at):
        if mac:return at+row.end(field)+int.from_bytes(row[field],'little',signed=True)
        instructions=list(decoder.disasm(row[field],at+row.start(field)))
        require(len(instructions)==1 and instructions[0].mnemonic=='bl' and instructions[0].size==4)
        require(instructions[0].operands[-1].type==capstone.arm.ARM_OP_IMM)
        return instructions[0].operands[-1].imm
    try:
        initial=actors['npc_initialization'];flight=initial['flight']
        require(initial['guidance'] and initial['activation'] and not initial['initial_active'])
        require([r['actor_kind'] for r in actors['actors']]==[8,8,8])
        require([r['hull_catalogue_id'] for r in actors['actors']]==[2,23,2])
        pointer=int.from_bytes(read('virtual_update',address(flight['provenance']['virtual_update']),8 if mac else 4,b'__DATA',b'__const'),'little')
        if not mac:require(pointer&1)
        bases={'constructor':address(flight['provenance']['bank'])-(2272 if mac else 1794),
               'update':pointer if mac else pointer&~1,
               'activation':address(initial['activation']['provenance']['activation'])}
        code=mach.data[mach.text['offset']:mach.text['offset']+mach.text['length']]
        found=[m for m in template(LAYOUTS[mach.architecture]['world_order'][3]).finditer(code) if mac or m.start()%2==0]
        require(len(found)==1);bases['world']=mach.text['address']+found[0].start()
        for key,(base,delta,size,pattern) in LAYOUTS[mach.architecture].items():
            if mac and key=='activation':pattern=(pattern,MAC_ACTIVATION_ALTERNATE)
            at=bases[base]+delta;row=template(pattern).fullmatch(read(key,at,size));require(row is not None)
            if key=='range':require(target(row,'getter',at)==address(projection['provenance']['predicate']))
        deactivation=address(initial['provenance']['opening_deactivation'])
        pattern=('554889e553504889fbc783bc00000005000000488b7b0831f6e8 {setter:4}' if mac else
                 '90b504460520c4f884000021606801af {setter:4} 012084f8ad0090bd')
        row=template(pattern).fullmatch(read('deactivation',deactivation,30 if mac else 28));require(row is not None)
        require(target(row,'setter',deactivation)==address(initial['provenance']['activity_setter']))
        opening=actors['provenance']['declaration']
        # The authored player suppression flag prevents holding-mode self-activation.
        at=address(opening)+opening['bytes']-(19 if mac else 22)
        expected=bytes.fromhex('498b8768010000488b00c6406201' if mac else '1498012100684466d5f8f000006880f85e10')
        require(read('player_suppression',at,len(expected))==expected)
        spans=sorted((s['offset'],s['offset']+s['bytes']) for s in proof.values())
        require(all(a[1]<=b[0] for a,b in zip(spans,spans[1:])))
        result=copy.deepcopy(VALUES);result['provenance']=proof;return result
    except (ValueError,KeyError,TypeError,IndexError,OverflowError):return {}

LAYOUTS = {'x86_64': {'timers': ['constructor', 1609, 24, '49c78424280200000000000049c784242002000000000000'],
            'range': ['constructor',
                      2032,
                      38,
                      '488d05 {global:4} 488b38e8 {getter:4} b9a086010084c0b850c300000f45c14189842478010000'],
            'clock_step': ['update', 101, 14, '4501ae280200004501ae20020000'],
            'activation': ['activation',
                           0,
                           82,
                           '554889e553504889fbc783bc00000001000000488b7b08be01000000e8 {call_28:4} '
                           '4889dfbe01000000e8 {call_41:4} '
                           'c6834101000001488b7b184885ff7504488b7b10be010000004883c4085b5de9805aebff'],
            'world_order': ['world',
                            0,
                            71,
                            '498b87780100004885c0743b833800743631db488b4008488b3cd8488b074489f6ff5068498b8778010000488b4008488b3cd8488b07ff504848ffc3498b87780100003b1872cc']},
 'armv7': {'timers': ['constructor',
                      1134,
                      200,
                      '15984ff0ff314ff6f672c0ef5000c3f6f93297ed030ac0f82c1120eff0811598c0f830111598c0f834114ff080411598c0f8a0111598c0f8a4211598c0f8a81140f2dc511598c0f8ac114cf250311598c0f8241105211598c0f8b01100201599159a01f5a2715063159a82f83901159a159b159cc4f83c01159c84f82901159c84f82a01159c84f83a01159cc4f8f001159cc4f8d400159c84f82b01159c84f8f401159c41f98f0a02f5e27141f98f0a02f5da7141f98f0a03f5ee71c2f8d501c2f8d10141f98f0a'],
           'range': ['constructor',
                     1616,
                     36,
                     '10981e2100681b91 {getter:4} 15994cf2503200281cbf48f2a062c0f201021f20c1f82421'],
           'clock_step': ['update',
                          174,
                          32,
                          'daf8bc014feae6780df507644ff0ff353044caf8bc01daf8b4013044caf8b401'],
           'activation': ['activation',
                          0,
                          50,
                          'b0b504460125c4f884500121606802af {call_16:4} 20460121 {call_24:4} '
                          '84f8f1500121e068002808bfa068bde8b0406ff6afbf'],
           'world_order': ['world',
                           0,
                           58,
                           'd4f8f80000281cbf0168002915d00026406850f8260001684a6b29469047d4f8f800406850f826000168496a8847d4f8f800013601688e42ead3']}}

# The same model-visibility tail remains linked in this complete compiler layout.
MAC_ACTIVATION_ALTERNATE = LAYOUTS['x86_64']['activation'][3].replace('e9805aebff', 'e95441ebff')
