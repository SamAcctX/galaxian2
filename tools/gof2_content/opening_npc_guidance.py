"""Recognize bounded fresh-opening NPC control declarations, never runtime code.

Android: PlayerFighter's constructor seeds speeds, fire alignment, boost
chance and hull; PlayerFighter::update (vtable slot 13) times target
selection, the damage boost and random boosts, moves the speed towards the
boost target through its rate table, picks the near range (8000, 12000
while the player is docked) and fires inside +-35000; Level::createShip
derives the hull from the level and difficulty, and Level::connectPlayers
lists the player first and other-race ships as targets.
"""
import copy
import struct
from .opening_loadout import template
from .ship_models import section_bytes

LAYOUTS = {'x86_64': {'tuning': ('constructor',
                       1371,
                       127,
                       '41c784240c0200000000004041c7842410020000f6fff93b41c784241402000000000040488db550ffffff41c7842418020000dc05000041c784247801000050c3000041c784241c0200000500000041c74424540000000041c684248d0100000041c78424900100000000000041c684247d0100000041c684247e01000000'),
            'speed_seed': ('constructor',
                           1772,
                           55,
                           '41c64424680141c684248d01000001f3410f10842414020000f3410f11842450020000f3410f1084240c020000f3410f11842458020000'),
            'hull_seed': ('constructor',
                          2118,
                          39,
                          '498b7c2408e8 {call_5:4} 418984244002000041c78424440200000000000041c684244802000000'),
            'selection': ('update',
                          2095,
                          119,
                          '4181be20020000891300000f8cfe0200004489ad80f5ffff30c041f6867d01000001751a488d05 '
                          '{ref_24:4} 488b38be64000000e8 {call_33:4} '
                          '83f8140f9cc04188867d01000041c7862002000000000000488d05 {ref_50:4} 488b38be64000000e8 '
                          '{call_5f:4} 83f81d0f8f3d01000041833f020f8233010000'),
            'boost_damage': ('update',
                             10661,
                             123,
                             '418b86400200004439e07e6f4429e041038644020000418986440200004589a640020000f30f2ac0f30f118580f5ffff498b7e08e8 '
                             '{call_34:4} 0f57c0f30f2ac0f30f108d80f5fffff30f5ec8f30f590d {ref_4c:4} 0f2e0d '
                             '{ref_54:4} 761e41c786440200000000000041c786280200001027000041c6864802000001'),
            'boost_start': ('update',
                            10784,
                            135,
                            '4181be28020000891300007c7a41f6865c02000001757041c786280200000000000041f6864802000001751d488d05 '
                            '{ref_2c:4} 488b38be64000000e8 {call_3b:4} 413b861c0200007d3e488d05 {ref_49:4} '
                            '488b38beb80b0000e8 {call_58:4} '
                            '05881300004189862c02000041c6865c0200000141c786540200000000b04041c786580200006666a63f'),
            'boost_response': ('update',
                               10919,
                               202,
                               '41f6865c020000010f84bc000000418b8628020000413b862c0200007f0bf3410f108654020000eb3741c786280200000000000041c6864802000000f3410f108614020000f3410f118654020000f3410f108e0c020000f3410f118e58020000660fefc90f2ec17661f3410f108e500200000f2ec10f97c00fb6c0488d0d '
                               '{ref_7b:4} f30f590c81f3410f118e50020000f3410f1096140200000f2e0d {ref_99:4} '
                               '73050f2ed17623f3410f1186500200000f2ec2750a7a0841c6865c0200000041c7865402000000000000'),
            'near': ('update',
                     11151,
                     62,
                     'b9401f0000f6406d017433498b7e78e8 {call_f:4} b9401f00004885c07420498b7e78e8 {call_22:4} '
                     '4889c7e8 {call_2a:4} bae02e000084c0b9401f00000f45ca'),
            'fire': ('update',
                     11635,
                     146,
                     'f3410f1086cc010000f3410f5c4648f30f100d {ref_f:4} 0f2ec80f86490100000f2e05 {ref_20:4} '
                     '0f863c010000f3410f1086d0010000f3410f5c464cf30f100d {ref_3c:4} 0f2ec80f861c0100000f2e05 '
                     '{ref_4d:4} 0f860f010000f3410f1086d4010000f3410f5c4650f30f100d {ref_69:4} '
                     '0f2ec80f86ef0000000f2e05 {ref_7a:4} 0f86e200000041f64641010f84a3000000'),
            'hull_level': ('factory',
                           166,
                           46,
                           'bb2c010000488d05 {ref_5:4} 488b38e8 {call_f:4} 83f8147f15488d05 {ref_19:4} 488b38e8 '
                           '{call_23:4} 6bd80e83c314'),
            'hull_difficulty': ('factory',
                                442,
                                37,
                                'f30f2ac3488d05 {ref_4:4} f30f10482cf30f580d {ref_10:4} '
                                'f30f59c8f30f58c8f3440f2cf1'),
            'membership': ('membership',
                           0,
                           37,
                           '488b4008488b3cd84c39f70f849e0000008b45c83947440f95c00a45c03c010f858a000000'),
            'player_first': ('membership',
                             512,
                             33,
                             '498b876801000031db4885c07413488b4db8488b4908488b00488901bb01000000')},
 'armv7': {'tuning': ('constructor',
                      1134,
                      132,
                      '15984ff0ff314ff6f672c0ef5000c3f6f93297ed030ac0f82c1120eff0811598c0f830111598c0f834114ff080411598c0f8a0111598c0f8a4211598c0f8a81140f2dc511598c0f8ac114cf250311598c0f8241105211598c0f8b01100201599159a01f5a2715063159a82f83901159a159b159cc4f83c01159c84f82901159c84f82a01'),
           'speed_seed': ('constructor',
                          1378,
                          38,
                          '159801231599159a82f84830159a82f83931159ad2f8a821c1f8e0211599d1f8a011c0f8e811'),
           'hull_seed': ('constructor',
                         1700,
                         30,
                         '159840681b91 {call_6:4} 1599c1f8d00100211598c0f8d411159880f8d811'),
           'selection': ('update',
                         2026,
                         132,
                         '41f28931caf84401daf8b4018842c0f2c4809af829010025cdf8ccb000284ff0000012d146f6be104ff0ff31c0f22100784400680068cdf8a0186421 '
                         '{call_3c:4} '
                         '14284ff00000b8bf0120cdf8d48046f69411c0f221018af829017944caf8b451d1f800b04ff0ff31dbf80000cdf8a0186421 '
                         '{call_72:4} 1d2800f3118120680228c0f00d81'),
           'boost_damage': ('update',
                            6712,
                            102,
                            'daf8d001a8422edddaf8d411401bcaf8d0514ff0ff320144caf8d411daf8040041ec181bcdf8a028 '
                            '{call_28:4} 40ec300b {ref_30:4} bbff0806bbff201680ee010a {ref_40:4} '
                            '00ff110db4eec20af1ee10fa09dd0020caf8d40142f21070caf8bc0101208af8d801'),
           'boost_start': ('update',
                           6814,
                           130,
                           'daf8bc0141f2893188423adb9af8ec01b8bb0020caf8bc019af8d80188b945f210704ff0ff31c0f22100784400680068cdf8a0186421 '
                           '{call_36:4} daf8b01188421fda45f2ec604ff0ff31c0f22100784400680068cdf8a01840f6b831 '
                           '{call_5c:4} 41f288310844caf8c001012046f266618af8ec010020c3f6a671c4f2b000cae97901'),
           'boost_return': ('update',
                            6944,
                            54,
                            '9af8ec01002800f06884dae96f01884240f32f840020caf8bc018af8d8019aed6a0a8aed790adaf8a001caf8e80120ef100100f020bc'),
           'boost_response': ('update',
                              9106,
                              104,
                              '9aed790ab5eec00af1ee10fa2cdd9aed781a {rates:4} '
                              '81ef163fb4eec10af1ee10fa20ef1001c8bf043090ed002a01ff121d8aed781ab4eec31a9aed6a2af1ee10fa04dab4eec21af1ee10fa0cd5b4eec20a8aed780af1ee10fa04bf00208af8ec010020caf8e401'),
           'near': ('update',
                    9210,
                    86,
                    'daf84401002800f00f829af82811002940f00a8290f86900002800f0c581daf850004ff0ff35cdf8a058 '
                    '{call_2a:4} 4ff4fa54002800f0ba81daf85000cdf8a058 {call_40:4} cdf8a058 {call_48:4} '
                    '002818bf42f6e064aae1'),
           'fire': ('update',
                    11374,
                    128,
                    '9aed0a1a9aed582a {ref_8:4} 22ef011db4eec01af1ee10fa40f1b180 {ref_1c:4} '
                    'b4eec21af1ee10fa40f3a9809aed0b1a9aed593a23ef011db4eec01af1ee10fa40f19d80b4eec21af1ee10fa40f397809aed0c1a9aed5a3a23ef011db4eec01af1ee10fa40f18b80b4eec21af1ee10fa40f385809af821105d465646002944d0'),
           'hull_level': ('factory',
                          254,
                          36,
                          '0846 {call_2:4} 142802dd4ff4967509e0d8f800003094 {call_16:4} c0ebc000142101eb4005'),
           'hull_difficulty': ('factory',
                               490,
                               44,
                               'c6ff102f784445ec305bfbff2006baf19a0f006890ed0b0a40ef222d40ffb22d40efa20dbbff200710ee105a'),
           'membership': ('membership', 0, 30, '406850f82500984250d0416a099a91424ff0000118bf0121089a114346d0'),
           'player_first': ('membership',
                            -360,
                            30,
                            'd6f8f0004ff0ff3a002806d000684ff0010b0d994968086001e04ff0000b')}}

LITERALS = {'x86_64': {'boost_damage.ref_4c': (None, 100.0),
            'boost_damage.ref_54': (None, 40.0),
            'boost_response.ref_7b': (None, [0.949999988079071, 1.0499999523162842]),
            'boost_response.ref_99': (None, 5.5),
            'fire.ref_f': (None, 35000.0),
            'fire.ref_20': (None, -35000.0),
            'fire.ref_3c': (None, 35000.0),
            'fire.ref_4d': (None, -35000.0),
            'fire.ref_69': (None, 35000.0),
            'fire.ref_7a': (None, -35000.0),
            'hull_difficulty.ref_10': (None, -0.5)},
 'armv7': {'boost_damage.ref_30': ('s4', 40.0),
           'boost_damage.ref_40': ('s2', 100.0),
           'boost_response.rates': ('r0', [0.949999988079071, 1.0499999523162842]),
           'fire.ref_8': ('s0', 35000.0),
           'fire.ref_1c': ('s4', -35000.0)}}

# These immediate declarations are recognized by the bounded layouts above.
# Later mission/cursor, companion, hull-family and level branches are excluded.
VALUES = {'actor_kind':8,'target_kind':'player','selection_period_ms':5000,
          'straight_roll_bound':100,'straight_chance':20,'selection_roll_bound':100,
          'cruise_speed':2.0,'boost_period_ms':5000,'boost_chance':5,'boost_roll_bound':100,'damage_boost_elapsed_ms':10000,
          'boost_duration_base_ms':5000,'boost_duration_bound_ms':3000,
          'boost_speed':5.5,'speed_decrease':0.949999988079071,'speed_increase':1.0499999523162842,
          'damage_percent_scale':100.0,'boost_damage_percent':40.0,
          'close_half_extent':8000,'special_close_half_extent':12000,
          'fire_half_extent':35000.0,'fire_alignment':struct.unpack('<f',bytes.fromhex('f6fff93b'))[0],
          'fresh_hull_base':34,'difficulty_offset':-0.5}


# PlayerFighter::PlayerFighter, `this` in fp.
ANDROID_TUNING = """
movw r3, #0xfff6
mov.w r4, #-1
movw r1, #0xc350
movw r2, #0x5dc
movt r3, #0x3bf9
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
"""
ANDROID_SPEED_SEED = """
movs r0, #1
strb.w r0, [fp, #0x48]
strb.w r0, [fp, #0x139]
ldr.w r0, [fp, #0x1a8]
str.w r0, [fp, #0x1e0]
ldr.w r0, [fp, #0x1a0]
str.w r0, [fp, #0x1e8]
"""
ANDROID_HULL_SEED = """
ldr.w r0, [fp, #4]
call _ZN6Player12getHitpointsEv
ldr r1, ={}
movs r2, #0
strd r0, r2, [fp, #0x1d0]
add r1, pc
strb.w r2, [fp, #0x1d8]
"""
# PlayerFighter::update, `this` in r4.
ANDROID_SELECTION = """
movw r1, #0x1389
str.w r0, [r4, #0x144]
ldr.w r0, [r4, #0x1b4]
cmp r0, r1
blt.w {later}
ldrb.w r0, [r4, #0x129]
movs r5, #0
cmp r0, #0
mov.w r0, #0
bne {@straight}
ldr.w r0, ={}
movs r1, #0x64
add r0, pc
ldr r0, [r0]
ldr r0, [r0]
call _ZN11AbyssEngine8AERandom7nextIntEi
cmp r0, #0x14
mov.w r0, #0
it lt
movlt r0, #1
straight: ldr.w r1, ={}
strb.w r0, [r4, #0x129]
add r1, pc
str.w r5, [r4, #0x1b4]
ldr r1, [r1]
ldr r0, [r1]
movs r1, #0x64
call _ZN11AbyssEngine8AERandom7nextIntEi
cmp r0, #0x1d
bgt {keep}
ldr r0, [r6]
cmp r0, #2
blo {keep}
"""
# Damage boost, random boost and boost end; the response follows elsewhere.
ANDROID_BOOST = """
ldr.w r0, [r4, #0x1d0]
cmp r0, fp
ble {@start}
ldr.w r1, [r4, #0x1d4]
sub.w r0, r0, fp
add r0, r1
strd fp, r0, [r4, #0x1d0]
vmov s0, r0
ldr r0, [r4, #4]
vcvt.f32.s32 s16, s0
call _ZN6Player15getMaxHitpointsEv
vmov s0, r0
vldr s2, ={scale}
vcvt.f32.s32 s0, s0
vdiv.f32 s0, s16, s0
vmul.f32 s0, s0, s2
vldr s2, ={percent}
vcmpe.f32 s0, s2
vmrs apsr_nzcv, fpscr
ble {@start}
movs r0, #0
str.w r0, [r4, #0x1d4]
movw r0, #0x2710
str.w r0, [r4, #0x1bc]
movs r0, #1
strb.w r0, [r4, #0x1d8]
start: ldr.w r0, [r4, #0x1bc]
movw r1, #0x1389
cmp r0, r1
blt {@boosting}
ldrb.w r0, [r4, #0x1ec]
cbnz r0, {@boosting}
movs r0, #0
str.w r0, [r4, #0x1bc]
ldrb.w r0, [r4, #0x1d8]
cbnz r0, {@forced}
ldr r0, ={}
movs r1, #0x64
add r0, pc
ldr r0, [r0]
ldr r0, [r0]
call _ZN11AbyssEngine8AERandom7nextIntEi
ldr.w r1, [r4, #0x1b0]
cmp r0, r1
bge {@boosting}
forced: ldr r0, ={}
movw r1, #0xbb8
add r0, pc
ldr r0, [r0]
ldr r0, [r0]
call _ZN11AbyssEngine8AERandom7nextIntEi
movw r1, #0x1388
add r0, r1
str.w r0, [r4, #0x1c0]
movs r0, #1
movw r1, #0x6666
strb.w r0, [r4, #0x1ec]
movs r0, #0
movt r1, #0x3fa6
movt r0, #0x40b0
strd r0, r1, [r4, #0x1e4]
boosting: ldrb.w r0, [r4, #0x1ec]
cmp r0, #0
beq.w {done}
ldrd r0, r1, [r4, #0x1bc]
cmp r0, r1
ble.w {response}
movs r0, #0
str.w r0, [r4, #0x1bc]
strb.w r0, [r4, #0x1d8]
ldr.w r0, [r4, #0x1a8]
str.w r0, [r4, #0x1e4]
ldr.w r1, [r4, #0x1a0]
vmov s0, r0
str.w r1, [r4, #0x1e8]
b {resume}
"""
ANDROID_RESPONSE = """
vldr s0, [r4, #0x1e4]
add.w r0, r4, #0x1e4
vcmpe.f32 s0, #0
vmrs apsr_nzcv, fpscr
ble {@done}
vldr s2, [r4, #0x1e0]
addw r1, pc, #{rates}
vmov.f32 s6, #5.500000e+00
vcmpe.f32 s0, s2
vmrs apsr_nzcv, fpscr
it gt
addgt r1, #4
vldr s4, [r1]
vmul.f32 s4, s2, s4
vstr s4, [r4, #0x1e0]
vcmpe.f32 s4, s6
vldr s2, [r4, #0x1a8]
vmrs apsr_nzcv, fpscr
bge {@reached}
vcmpe.f32 s4, s2
vmrs apsr_nzcv, fpscr
bpl {@done}
reached: vcmpe.f32 s0, s2
vstr s0, [r4, #0x1e0]
vmrs apsr_nzcv, fpscr
itt eq
moveq r1, #0
strbeq.w r1, [r4, #0x1ec]
movs r1, #0
str r1, [r0]
done: ldr.w r0, [r4, #0x144]
"""
ANDROID_NEAR = """
ldrb.w r0, [r0, #0x69]
cmp r0, #0
beq.w {other}
ldr r0, [r4, #0x50]
call _ZN5Level9getPlayerEv
mov.w r5, #0x1f40
cmp r0, #0
beq.w {}
ldr r0, [r4, #0x50]
call _ZN5Level9getPlayerEv
call _ZN9PlayerEgo22isDockedToDockingPointEv
cmp r0, #0
it ne
movwne r5, #0x2ee0
"""
ANDROID_FIRE = """
vldr s4, [r4, #0x16c]
vldr s0, [r4, #0x1a4]
vcmpe.f32 s4, s0
vmrs apsr_nzcv, fpscr
bpl {miss}
vneg.f32 s2, s0
vcmpe.f32 s4, s2
vmrs apsr_nzcv, fpscr
ble {miss}
vldr s4, [r4, #0x170]
vcmpe.f32 s4, s0
vmrs apsr_nzcv, fpscr
bpl {miss}
vcmpe.f32 s4, s2
vmrs apsr_nzcv, fpscr
ble {miss}
vldr s0, [r4, #0x28]
vldr s2, [r4, #0x160]
vsub.f32 s4, s2, s0
vldr s0, ={range}
vcmpe.f32 s4, s0
vmrs apsr_nzcv, fpscr
bpl {miss}
vldr s2, ={negative_range}
vcmpe.f32 s4, s2
vmrs apsr_nzcv, fpscr
ble {miss}
vldr s4, [r4, #0x2c]
vldr s6, [r4, #0x164]
vsub.f32 s4, s6, s4
vcmpe.f32 s4, s0
vmrs apsr_nzcv, fpscr
bpl {miss}
vcmpe.f32 s4, s2
vmrs apsr_nzcv, fpscr
ble {miss}
vldr s4, [r4, #0x30]
vldr s6, [r4, #0x168]
vsub.f32 s4, s6, s4
vcmpe.f32 s4, s0
vmrs apsr_nzcv, fpscr
bpl {miss}
vcmpe.f32 s4, s2
vmrs apsr_nzcv, fpscr
ble {miss}
ldrb.w r1, [r4, #0x21]
"""
# Level::createShip: level (at most 20) x 14 + 20, plus 4 x cursor or 180 once the game is won.
ANDROID_HULL_LEVEL = """
ldr.w r0, ={}
add r0, pc
ldr r0, [r0]
ldr r0, [r0]
call _ZN6Status8getLevelEv
cmp r0, #0x14
str r4, [sp, #0x18]
ble {@level}
movs r5, #0x14
b {@clamped}
level: ldr.w r0, ={}
add r0, pc
ldr r0, [r0]
ldr r0, [r0]
call _ZN6Status8getLevelEv
mov r5, r0
clamped: ldr.w r0, ={}
add r0, pc
ldr r0, [r0]
ldr r0, [r0]
call _ZN6Status7gameWonEv
cmp r0, #0
lsl.w r1, r8, #2
rsb r0, r5, r5, lsl #3
it ne
movne r1, #0xb4
cmp r6, #0x33
add.w r0, r1, r0, lsl #1
add.w r4, r0, #0x14
"""
ANDROID_HULL_DIFFICULTY = """
ldr.w r0, ={}
vmov.f32 s0, #-5.000000e-01
vmov s4, r4
cmp.w r8, #0x9a
add r0, pc
ldr r0, [r0]
vldr s2, [r0, #0x2c]
vcvt.f32.s32 s4, s4
vadd.f32 s0, s2, s0
vmul.f32 s0, s4, s0
vadd.f32 s0, s4, s0
vcvt.s32.f32 s0, s0
vmov sl, s0
"""
# Level::connectPlayers: the player first, then ships other than this one of another race.
ANDROID_PLAYER_FIRST = """
ldr.w r0, [fp, #0xf0]
cmp r0, #0
beq.w {none}
ldr.w r1, [sl, #4]
ldr r0, [r0]
str r0, [r1]
movs r0, #1
b {count}
"""
ANDROID_MEMBERSHIP = """
movs r0, #0
str r0, [sp, #0x30]
ldr.w r0, [fp, #0xf8]
ldr r1, [r0]
cmp r1, #0
beq.w {}
movs r1, #0
cmp r4, #0
it eq
moveq r1, #1
ldr r2, [sp, #0x38]
movs r5, #0
cmp r2, #0x24
mov.w r2, #0
it eq
moveq r2, #1
ands r1, r2
str r1, [sp, #0x1c]
ldr r0, [r0, #4]
ldr.w r0, [r0, r5, lsl #2]
cmp r0, r6
beq {skip}
ldr r1, [r0, #0x24]
cmp r1, r8
mov.w r1, #0
it ne
movne r1, #1
orrs.w r1, r1, sb
beq {skip}
"""


def android_guidance(lib):
    from .android_shapes import Listing, relocation, vtable_slot
    method = relocation(lib, vtable_slot(lib, '_ZTV13PlayerFighter', 13))
    if method is None:
        return {}
    update = Listing(lib, method[0])
    constructor = Listing(lib, '_ZN13PlayerFighterC1EiiP6PlayerP10AEGeometryfffb')
    ship = Listing(lib, '_ZN5Level10createShipEiiiP8Waypointbb')
    players = Listing(lib, '_ZN5Level14connectPlayersEv')
    shapes = {key: listing.unique(template) for key, listing, template in [
        ('tuning', constructor, ANDROID_TUNING), ('speed_seed', constructor, ANDROID_SPEED_SEED),
        ('hull_seed', constructor, ANDROID_HULL_SEED), ('selection', update, ANDROID_SELECTION),
        ('boost', update, ANDROID_BOOST), ('near', update, ANDROID_NEAR), ('fire', update, ANDROID_FIRE),
        ('hull_level', ship, ANDROID_HULL_LEVEL), ('hull_difficulty', ship, ANDROID_HULL_DIFFICULTY),
        ('player_first', players, ANDROID_PLAYER_FIRST)]}
    if None in shapes.values():
        return {}
    boost, first = shapes['boost'], shapes['player_first']
    shapes['boost_response'] = update.follow(boost, 'response', ANDROID_RESPONSE)
    shapes['membership'] = players.follow(first, 'none', ANDROID_MEMBERSHIP)
    response, membership = shapes['boost_response'], shapes['membership']
    # The boost end resumes after the response's first load and skips to where the response
    # ends; the target count is stored with the player first; misses and kept targets go on.
    if (response is None or membership is None or update.target(boost['resume']) != response.first + 1
            or update.target(boost['done']) != response.last or players.target(first['count']) != membership.first + 1
            or not update.target(shapes['fire']['miss']) > shapes['fire'].last
            or not update.target(shapes['selection']['keep']) > shapes['selection'].last
            or not update.target(shapes['selection']['later']) > shapes['selection'].last):
        return {}
    # The other near branch also takes 8000.
    if update.follow(shapes['near'], 'other', 'mov.w r5, #0x1f40') is None:
        return {}
    fire = shapes['fire']
    literals = [boost.pool('scale'), boost.pool('percent'), fire.pool('range'), fire.pool('negative_range')]
    # The decrease/increase rates: two floats the `addw rN, pc` addresses.
    rates = section_bytes(lib, update.pc_address(response.index('rates')), 8, b'__text')
    found = [struct.unpack('<f', struct.pack('<I', word))[0] for word, _ in literals] + list(struct.unpack('<2f', rates[0]) if rates else [])
    if found != [100.0, 40.0, 35000.0, -35000.0, VALUES['speed_decrease'], VALUES['speed_increase']]:
        return {}
    proof = {'virtual_update': method[1], **{key: shape.span() for key, shape in shapes.items()}}
    for index, (_, span) in enumerate(literals):
        proof['literal_%d' % index] = span
    proof['literal_4'] = {'offset': rates[1], 'bytes': 8}
    result = copy.deepcopy(VALUES)
    result['provenance'] = proof
    return result


def extract_opening_npc_guidance(mach, actors):
    if mach.architecture == 'android-armv7':
        initial = actors.get('npc_initialization') or {}
        if not initial.get('flight') or not initial.get('primary_weapon'):
            return {}
        rows = actors['actors']
        if [(r['actor_id'], r['actor_kind'], r['hull_catalogue_id']) for r in rows] != [(0, 8, 2), (1, 8, 23), (2, 8, 2)]:
            return {}
        return android_guidance(mach)
    import capstone
    mac=mach.architecture=='x86_64'
    if mach.architecture not in LAYOUTS:return {}
    decoder=capstone.Cs(capstone.CS_ARCH_ARM,capstone.CS_MODE_THUMB);decoder.detail=True
    proof={}
    def require(ok):
        if not ok:raise ValueError('Unsupported fresh NPC control declaration')
    def address(span):
        offset=span['offset']-mach.slice_offset
        matches=[s for s in mach.sections if s['offset']<=offset and offset+span['bytes']<=s['offset']+s['length']]
        require(len(matches)==1)
        return matches[0]['address']+offset-matches[0]['offset']
    def read(key,at,size,segment=b'__TEXT',section=b'__text'):
        matches=[s for s in mach.sections if s['segment']==segment and s['name']==section and s['address']<=at and at+size<=s['address']+s['length']]
        require(len(matches)==1)
        offset=matches[0]['offset']+at-matches[0]['address']
        raw=mach.data[offset:offset+size];require(len(raw)==size)
        span={'offset':offset+mach.slice_offset,'bytes':size}
        if span not in proof.values():proof[key]=span
        return raw
    try:
        initial=actors['npc_initialization'];flight=initial['flight'];weapon=initial['primary_weapon']
        require(flight and weapon and weapon['provenance']['fresh_level'])
        require([r['actor_id'] for r in actors['actors']]==[0,1,2])
        require([r['actor_kind'] for r in actors['actors']]==[8,8,8])
        require([r['hull_catalogue_id'] for r in actors['actors']]==[2,23,2])
        update_at=address(flight['provenance']['virtual_update'])
        pointer=int.from_bytes(read('virtual_update',update_at,8 if mac else 4,b'__DATA',b'__const'),'little')
        if not mac:require(pointer&1==1)
        bases={'constructor':address(flight['provenance']['bank'])-(2272 if mac else 1794),
               'factory':address(initial['provenance']['factory_entry']),
               'update':pointer if mac else pointer&~1}
        layout=LAYOUTS[mach.architecture]
        code=mach.data[mach.text['offset']:mach.text['offset']+mach.text['length']]
        found=[m for m in template(layout['membership'][3]).finditer(code) if mac or m.start()%2==0]
        require(len(found)==1)
        bases['membership']=mach.text['address']+found[0].start()
        rows={};positions={}
        for key,(base,delta,size,pattern) in layout.items():
            at=bases[base]+delta;positions[key]=at
            row=template(pattern).fullmatch(read(key,at,size));require(row is not None);rows[key]=row
        literal_index=0
        for name,(register,expected) in LITERALS[mach.architecture].items():
            block,field=name.split('.');row=rows[block];at=positions[block]
            if mac:location=at+row.end(field)+int.from_bytes(row[field],'little',signed=True)
            else:
                instructions=list(decoder.disasm(row[field],at+row.start(field)))
                require(len(instructions)==1 and instructions[0].size==4)
                i=instructions[0];require(i.reg_name(i.operands[0].reg)==register)
                if field=='rates':
                    require(i.mnemonic=='subw' and i.reg_name(i.operands[1].reg)=='pc' and i.operands[-1].type==capstone.arm.ARM_OP_IMM)
                    location=i.address+4-i.operands[-1].imm
                else:
                    require(i.mnemonic=='vldr' and i.operands[-1].type==capstone.arm.ARM_OP_MEM and i.reg_name(i.operands[-1].mem.base)=='pc')
                    location=((i.address+4)&~3)+i.operands[-1].mem.disp
            values=expected if isinstance(expected,list) else [expected]
            raw=read('literal_'+str(literal_index),location,4*len(values),section=b'__const' if mac else b'__text')
            require(list(struct.unpack('<'+'f'*len(values),raw))==values)
            if 'literal_'+str(literal_index) in proof:literal_index+=1
        spans=sorted((s['offset'],s['offset']+s['bytes']) for s in proof.values())
        require(all(a[1]<=b[0] for a,b in zip(spans,spans[1:])))
        result=copy.deepcopy(VALUES);result['provenance']=proof
        return result
    except (ValueError,KeyError,TypeError,IndexError,OverflowError,struct.error):return {}
