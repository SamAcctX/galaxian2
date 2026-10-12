"""Relocated synthetic opening declarations, with meaningful corruption cases."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from gof2_content.opening_actors import extract_opening_actors,MAC_ACTORS,ARM_ACTORS,MAC_DISPATCH,ARM_DISPATCH
from test_font_selection import expand
from test_materials import arm_wide
from test_ship_models import branch


def fixture(mac, relocation=0):
    start=0x10000+relocation;dispatch_start=start+512 if mac else start-96;getter=start+1024;setter=start+1100;constant=start+4096
    actors,af=expand(MAC_ACTORS if mac else ARM_ACTORS);dispatch,df=expand(MAC_DISPATCH if mac else ARM_DISPATCH)
    def put(block,fields,key,value):
        at,size=fields[key];assert size==len(value);block[at:at+size]=value
    def near_branch(at,target,kind):
        delta=target-at-4
        if kind=='blo':opcode=0xd300
        elif kind=='bgt':opcode=0xdc00
        elif kind=='beq':opcode=0xd000
        else:raise ValueError(kind)
        return struct.pack('<H',opcode|((delta//2)&255))
    def wide_branch(at,target,kind):
        delta=target-at-4
        if kind=='b.w':
            raw=bytearray(branch(at,target));raw[3]&=~0x40;return bytes(raw)
        # Thumb-2 conditional branch: S:J2:J1:imm6:imm11:0.
        d=delta&0x1fffff;condition={'bgt.w':12,'bne.w':1}[kind]
        return struct.pack('<2H',0xf000|((d>>20)<<10)|(condition<<6)|((d>>12)&63),0x8000|(((d>>18)&1)<<13)|(((d>>19)&1)<<11)|((d>>1)&2047))
    for block,fields,base in [(actors,af,start),(dispatch,df,dispatch_start)]:
        for key,(at,size) in fields.items():
            if key.startswith('call_'):
                target=start+2000
                if block is dispatch and key==('call_a' if mac else 'call_10'):target=getter
                if block is actors and key in (['call_130','call_171'] if mac else ['call_100','call_14a']):target=setter
                if mac:raw=struct.pack('<i',target-base-at-4)
                else:
                    blx=(block is actors and key in ['call_a','call_1a']) or (block is dispatch and key=='call_4a')
                    raw=bytearray(branch(((base+at+4)&~3)-4 if blx else base+at,target))
                    if blx:raw[3]&=~0x10
                put(block,fields,key,raw)
            elif mac and key.startswith('ref_'):put(block,fields,key,struct.pack('<i',constant-base-at-4))
            elif key.startswith('jump_'):
                if mac:
                    destinations={'jump_4d':start+0x162,'jump_138':start+0x150,'jump_15c':start+0x5b,'jump_25':start}
                    target=destinations.get(key,start+2200)
                    put(block,fields,key,int(target-base-at-size).to_bytes(size,'little',signed=True))
                else:
                    if block is actors:
                        cases={'jump_56':(start+0x12c,'beq'),'jump_106':(start+0x120,'bgt'),'jump_12a':(start+0x62,'blo'),'jump_160':(start+2200,'b.w')}
                        target,kind=cases[key]
                    else:target,kind=start+2200,('bne.w' if key=='jump_5c' else 'bgt.w')
                    put(block,fields,key,near_branch(base+at,target,kind) if size==2 else wide_branch(base+at,target,kind))
            elif key.startswith('pointer_'):
                put(block,fields,key,arm_wide(123,0,key in ['pointer_4','pointer_1a']))
    if mac:
        scalars={'count':3,'alternate_hull':7,'alternate_index':1,'default_hull':4,'actor_kind':8,'actor_hull':123,'effect_last_actor':2,'player_hull':9999,'saved_player_hull':9999}
        for key,value in scalars.items():put(actors,af,key,value.to_bytes(af[key][1],'little',signed=True))
    else:
        shorts={'count':(0,3,False),'default_hull':(3,4,False),'alternate_index':(4,1,True),'alternate_hull':(3,7,False),'actor_hull':(1,123,False),'effect_last_actor':(4,2,True)}
        for key,(reg,value,cmp) in shorts.items():put(actors,af,key,struct.pack('<H',(0x2800 if cmp else 0x2000)|(reg<<8)|value))
        put(actors,af,'actor_kind',bytes.fromhex('4ff00801'))
        for key,value,reg,top in [('position_low',0,1,False),('position_high',0x42c8,1,True),('player_hull_low',9999,4,False),('player_hull_high',0,4,True)]:put(actors,af,key,arm_wide(value,reg,top))
    data=bytearray(8192)
    actor_offset=256;dispatch_offset=actor_offset+dispatch_start-start
    data[actor_offset:actor_offset+len(actors)]=actors;data[dispatch_offset:dispatch_offset+len(dispatch)]=dispatch
    raw=bytes.fromhex('554889e58b87780200005dc3' if mac else 'd0f8d4017047')
    data[1280:1280+len(raw)]=raw
    raw=bytes.fromhex('554889e589b78000000039b78c0000007d0689b78c0000005de9')+struct.pack('<i',100) if mac else bytes.fromhex('8167d0f884208a42b8bfc0f88410')+wide_branch(setter+14,setter+100,'b.w')
    data[1356:1356+len(raw)]=raw
    struct.pack_into('<f',data,5000,100)
    text={'name':b'__text','segment':b'__TEXT','address':start-256,'offset':0,'length':4000}
    const={'name':b'__const','segment':b'__TEXT','address':constant,'offset':5000,'length':4}
    return SimpleNamespace(data=bytes(data),text=text,sections=[text,const],slice_offset=16384,architecture='x86_64' if mac else 'armv7'),af,df,dispatch_offset


@unittest.skipUnless(importlib.util.find_spec('capstone'),'optional static-reader dependency')
class OpeningActors(unittest.TestCase):
    def test_relocation_and_source_parameter_changes(self):
        for mac in [True,False]:
            for relocation in [0,0x30000]:
                with self.subTest(mac=mac,relocation=relocation):
                    mach,*_=fixture(mac,relocation);scope=extract_opening_actors(mach)
                    self.assertEqual([a['hull_catalogue_id'] for a in scope['actors']],[4,7,4])
                    self.assertEqual([a['current_hull_override'] for a in scope['actors']],[123]*3)
                    self.assertEqual(scope['actors'][0]['position'],[100]*3)
                    self.assertEqual(scope['player_current_hull_override'],9999)
                    self.assertEqual(scope['provenance']['declaration']['offset'],16640)

    def test_rejects_broken_dispatch_loop_hull_setter_and_values(self):
        for mac in [True,False]:
            for bad in ['dispatch','loop','getter','setter','setter_link','count','hull','position','effect_range']:
                with self.subTest(mac=mac,bad=bad):
                    mach,af,df,do=fixture(mac);data=bytearray(mach.data)
                    if bad=='dispatch':data[do+df['jump_25' if mac else 'jump_5c'][0]]^=(0x10 if mac else 0x40)
                    elif bad=='loop':data[256+af['jump_15c' if mac else 'jump_12a'][0]]^=1
                    elif bad=='getter':data[1280]^=1
                    elif bad=='setter':data[1356]^=1
                    elif bad=='setter_link':data[256+af['call_171' if mac else 'call_14a'][0]]^=1
                    elif bad=='count':data[256+af['count'][0]]=0
                    elif bad=='hull':data[256+af['actor_hull'][0]]=0
                    elif bad=='effect_range':data[256+af['effect_last_actor'][0]]=1
                    elif mac:struct.pack_into('<f',data,5000,float('nan'))
                    else:
                        at=256+af['position_high'][0];data[at:at+4]=arm_wide(0x7fc0,1,True)
                    mach.data=bytes(data)
                    self.assertEqual(extract_opening_actors(mach),{})

if __name__=='__main__':unittest.main()


def android_level(**changes):
    """Synthetic Level::createCampaignMission in the Android shape: player hull
    0x12345 kept in ip, cursor 0 through the range check and case table."""
    from android_text_fixture import fill
    from gof2_content import opening_actors as reader
    values = dict(count='4', alternate_index='2', default_hull='5', alternate_hull='9', actor_kind='7',
                  position_low='0', position_high='0x42c8', actor_hull='0x7b', effect_last_actor='3',
                  factory='_ZN5Level10createShipEiiiP8Waypointbb', deactivation='_ZN8KIPlayer10setToSleepEv',
                  setter='_ZN6Player12setHitpointsEi', player_setter='_ZN6Player12setHitpointsEi',
                  after='#after', next='#next', loop='#loop', exit='#exit')
    values.update(changes.pop('values', {}))
    constants = changes.pop('constants', 'movw ip, #0x2345\nmovw r5, #0x10\nmovt ip, #1')
    head = changes.pop('head', 'cmp r0, #0x60\nbgt.w #high\nsub.w r1, r0, #0x30\ncmp r1, #0x20\nbhi.w #low')
    cases = changes.pop('cases', '.cases case0, high, high, high')
    level = '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', 'call _ZN6Status25getCurrentCampaignMissionEv',
                       constants, head, 'low:', 'ldr.w sl, [sp, #0x40]', 'cmp r0, #3', 'bhi.w #high',
                       'tbh [pc, r0, lsl #1]', cases, 'case0:', fill(reader.ANDROID_ACTORS, **values),
                       'loop:', fill(reader.ANDROID_LOOP, **values), 'next:', fill(reader.ANDROID_NEXT, **values),
                       'after:', fill(reader.ANDROID_PLAYER, **values), 'exit:', 'bx lr', 'high:', 'bx lr'])
    functions = {'_ZN5Level21createCampaignMissionEv': level,
                 '_ZN6Status25getCurrentCampaignMissionEv': 'ldr.w r0, [r0, #0x1e8]\nbx lr',
                 '_ZN6Player12setHitpointsEi': fill(reader.ANDROID_SETTER, changed='#_ZN6Player9setActiveEb'),
                 '_ZN6Player9setActiveEb': 'bx lr'}
    functions.update(changes)
    return {k: v for k, v in functions.items() if v is not None}


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class AndroidOpeningActors(unittest.TestCase):
    def extract(self, **changes):
        from android_text_fixture import text_library
        lib, addresses = text_library(android_level(**changes))
        return extract_opening_actors(lib), lib, addresses

    def test_named_case_gives_actors_hull_and_spans(self):
        scope, lib, addresses = self.extract()
        self.assertEqual([a['hull_catalogue_id'] for a in scope['actors']], [5, 5, 9, 5])
        self.assertEqual({(a['actor_kind'], a['current_hull_override'], tuple(a['position'])) for a in scope['actors']}, {(7, 123, (100.0,) * 3)})
        self.assertEqual(scope['player_current_hull_override'], 0x12345)
        self.assertEqual(scope['npc_initialization'], {})
        level = addresses['_ZN5Level21createCampaignMissionEv']
        spans = {k: (v['offset'] - level, v['bytes']) for k, v in scope['provenance'].items() if k not in ('cursor_getter', 'hull_setter')}
        # call + 3 constants + range check; dispatch at `low`; the table entry follows tbh, case 0 the table.
        self.assertEqual(spans, {'dispatch': (4, 32), 'case_dispatch': (36, 14), 'case_entry': (50, 2), 'declaration': (58, 262)})
        self.assertEqual(scope['provenance']['cursor_getter'], {'offset': addresses['_ZN6Status25getCurrentCampaignMissionEv'], 'bytes': 6})
        self.assertEqual(scope['provenance']['hull_setter'], {'offset': addresses['_ZN6Player12setHitpointsEi'], 'bytes': 18})

    def test_each_broken_rule_is_unsupported(self):
        from gof2_content import opening_actors as reader
        cases = {
            'cursor in r0': dict(constants='movw ip, #0x2345\nmovw r0, #0x10\nmovt ip, #1'),
            'hull register missing': dict(constants='movw sb, #0x2345\nmovt sb, #1'),
            'hull low missing': dict(constants='movw r5, #0x2345\nmovt ip, #1'),
            'hull high missing': dict(constants='movw ip, #0x2345\nmovt r5, #1'),
            'two dispatches': dict(constants='movw ip, #0x2345\nmovt ip, #1\ncmp r0, #0x60\nbgt.w #high\nsub.w r1, r0, #0x30\ncmp r1, #0x20\nbhi.w #low\ncall _ZN6Status25getCurrentCampaignMissionEv\nmovw ip, #0x2345\nmovt ip, #1'),
            'hull twice': dict(constants='movw ip, #0x2345\nmovw ip, #0x10\nmovt ip, #1'),
            'zero hull': dict(constants='movw ip, #0\nmovt ip, #0'),
            'negative hull': dict(constants='movw ip, #0\nmovt ip, #0x8000'),
            'zero base': dict(head='cmp r0, #0x60\nbgt.w #high\nsub.w r1, r0, #0\ncmp r1, #0x20\nbhi.w #low'),
            'range to elsewhere': dict(head='cmp r0, #0x60\nbgt.w #high\nsub.w r1, r0, #0x30\ncmp r1, #0x20\nbhi.w #high'),
            'case 0 elsewhere': dict(cases='.cases high, case0, high, high'),
            'skip target': dict(values=dict(after='#next')),
            'effect target': dict(values=dict(next='#after')),
            'loop target': dict(values=dict(loop='#next')),
            'exit inside': dict(values=dict(exit='#case0')),
            'different setters': dict(values=dict(player_setter='_ZN6Player9setActiveEb')),
            'getter field': {'_ZN6Status25getCurrentCampaignMissionEv': 'ldr.w r0, [r0, #0x1ec]\nbx lr'},
            'setter shape': {'_ZN6Player12setHitpointsEi': reader.ANDROID_SETTER.replace('it lt\nstrlt.w', 'it gt\nstrgt.w').replace('{changed}', '#_ZN6Player9setActiveEb')},
            'setter loops': {'_ZN6Player12setHitpointsEi': 'top:\n' + reader.ANDROID_SETTER.strip().replace('{changed}', '#top')},
            'no actors': dict(values=dict(count='0', effect_last_actor='0xff')),
            'too many actors': dict(values=dict(count='0x21', effect_last_actor='0x20')),
            'alternate outside': dict(values=dict(alternate_index='4')),
            'effect range': dict(values=dict(effect_last_actor='2')),
            'zero actor hull': dict(values=dict(actor_hull='0')),
            'position not finite': dict(values=dict(position_high='0x7fc0')),
            'position too far': dict(values=dict(position_high='0x4b80')),
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(self.extract(**changes)[0], {})
        for missing in ('_ZN6Status25getCurrentCampaignMissionEv', '_ZN6Player12setHitpointsEi'):
            with self.subTest(missing):
                self.assertEqual(self.extract(**{missing: 'bx lr'})[0], {})
