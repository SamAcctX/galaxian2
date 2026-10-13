"""Relocated synthetic declarations: no original executable fixture is shipped."""
import copy
import struct
import unittest
from types import SimpleNamespace
from gof2_content import player_initialization as reader
from test_font_selection import expand
from test_ship_models import branch


def fixture(mac, shift=0):
    arch='x86_64' if mac else 'armv7'; origin=0x200000+shift; offset=256; bias=4096
    data=bytearray(8256); selector=3000; table=5000 if mac else 3030
    positions={'factory':500,'shield_getter':1000,'armor_getter':1100,'shield_setter':1200,
               'armor_setter':1300,'active':1500,'damage_permission':1600,'damage_setter':1800,
               'shield_assignment':3800 if mac else table+180,'armor_assignment':3900 if mac else table+200}
    deltas={'reset':-175,'loop_initial':-37,'loop_next':713} if mac else {
        'zero_vector':-210,'reset':-166,'loop_offset':-102,'loop_initial':-68,'loop_next':426}
    positions.update({key:selector+delta for key,delta in deltas.items()})
    fields={};mutations={}
    def write(at,raw): data[offset+at:offset+at+len(raw)]=raw
    def extent(at,n=4): return {'offset':bias+offset+at,'bytes':n}
    for key,(size,spec) in reader.LAYOUTS[arch].items():
        raw,fields[key]=expand(spec);assert len(raw)==size;write(positions[key],raw)
        covered={j for p,n in fields[key].values() for j in range(p,p+n)}
        mutations[key]=positions[key]+next(j for j in range(size) if j not in covered)
    targets={'factory.'+('call_28' if mac else 'call_26'):2000,
             'factory.'+('call_43' if mac else 'call_42'):2100,
             'factory.'+('call_69' if mac else 'call_66'):2100,
             'factory.'+('call_51' if mac else 'call_48'):1000,
             'factory.'+('call_77' if mac else 'call_72'):1100,
             'factory.'+('call_61' if mac else 'call_58'):1200,
             'factory.'+('call_87' if mac else 'call_82'):1300,
             'shield_setter.'+('call_24' if mac else 'call_20'):2200,
             'armor_setter.'+('call_18' if mac else 'call_8'):2200,
             'shield_assignment.'+('call_18' if mac else 'call_8'):2300,
             'armor_assignment.'+('call_18' if mac else 'call_8'):2300,
             'damage_permission.'+('call_1' if mac else 'call_0'):2400,
             'damage_permission.'+('call_14' if mac else 'call_12'):1800}
    if mac:
        targets.update({'factory.ref_35':7500,'loop_initial.ref_13':7500,'loop_initial.ref_6':table,
                        'loop_initial.call_33':positions['loop_next']+4,'loop_next.call_16':selector-17})
    else:
        targets.update({'loop_initial.call_2':selector-10,'loop_next.call_10':selector-10})
    for key,slots in fields.items():
        for field,(p,n) in slots.items():
            at=positions[key]+p;destination=targets.get(key+'.'+field,2500)
            if mac: raw=(destination-at-n).to_bytes(n,'little',signed=True)
            elif n==2: raw=struct.pack('<H',0xe000|(((destination-at-4)//2)&2047))
            elif key=='loop_next':
                delta=(destination-at-4)&0x1fffff
                raw=struct.pack('<HH',0xf000|((delta>>20)<<10)|(3<<6)|((delta>>12)&63),
                                0x8000|(((delta>>18)&1)<<13)|(((delta>>19)&1)<<11)|((delta>>1)&2047))
            else:
                raw=branch(origin+at,origin+destination)
                if key.endswith('_setter'): raw=raw[:2]+struct.pack('<H',struct.unpack('<H',raw[2:])[0]&~0x4000)
            write(at,raw)
    rows=[0]*30
    for type_id,key in [(9,'shield_assignment'),(10,'armor_assignment')]:
        rows[type_id]=(positions[key]-table)//(1 if mac else 2)
    write(table,struct.pack('<30i',*rows) if mac else bytes(rows))
    text={'name':b'__text','segment':b'__TEXT','offset':offset,'address':origin,'length':8000}
    m=SimpleNamespace(architecture=arch,data=bytes(data),slice_offset=bias,text=text,sections=[text])
    actors={'npc_initialization':{'provenance':{'stats_wrapper':extent(2000),
        'active' if mac else 'flags':extent(1500 if mac else 1498,7 if mac else 88)}}}
    vehicle={'equipment_rule':'last_matching','item_type_value_index':5,'provenance':{
        'equipment_table':extent(table,120 if mac else 30),'equipment_selector':extent(selector),
        'property_getter':extent(2300)}}
    staging={'provenance':{'initial':extent(1600-(0x56 if mac else 0x30)), 'player_getter':extent(2400)}}
    return m,actors,vehicle,staging,positions,fields,mutations,offset,table


class PlayerInitializationTests(unittest.TestCase):
    def test_relocated_profiles(self):
        for mac in [False,True]:
            for shift in [0,0x800000]:
                args=fixture(mac,shift);m,a,v,s=args[:4]
                result=reader.extract_player_initialization(m,a,v,s)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({k:v for k,v in result.items() if k!='provenance'},reader.VALUES)
                self.assertEqual(len(result['provenance']),14 if mac else 16)

    def test_reject_changed_declarations_and_type_table(self):
        for mac in [False,True]:
            m,a,v,s,positions,fields,mutations,offset,table=fixture(mac)
            for name,at in dict(mutations,shield_type=table+9*(4 if mac else 1),armor_type=table+10*(4 if mac else 1)).items():
                changed=copy.copy(m);raw=bytearray(m.data);raw[offset+at]^=1;changed.data=bytes(raw)
                self.assertEqual(reader.extract_player_initialization(changed,a,v,s),{},(mac,name))
            # A second matching factory is ambiguous even with the same body.
            raw=bytearray(m.data);size=reader.LAYOUTS[m.architecture]['factory'][0]
            raw[offset+6000:offset+6000+size]=raw[offset+positions['factory']:offset+positions['factory']+size]
            changed=copy.copy(m);changed.data=bytes(raw)
            self.assertEqual(reader.extract_player_initialization(changed,a,v,s),{})

    def test_reject_redirected_links_and_foreign_anchors(self):
        for mac in [False,True]:
            m,a,v,s,positions,fields,_,offset,table=fixture(mac)
            for key,field in [('factory','call_28' if mac else 'call_26'),
                              ('armor_setter','call_18' if mac else 'call_8'),
                              ('shield_assignment','call_18' if mac else 'call_8'),
                              ('damage_permission','call_1' if mac else 'call_0'),
                              ('loop_next','call_16' if mac else 'call_10')]:
                p,_=fields[key][field];raw=bytearray(m.data);raw[offset+positions[key]+p]^=2
                changed=copy.copy(m);changed.data=bytes(raw)
                self.assertEqual(reader.extract_player_initialization(changed,a,v,s),{},(mac,key))
            for index,key in [(0,'stats_wrapper'),(1,'equipment_table'),(2,'initial')]:
                args=copy.deepcopy([a,v,s]);data=args[index]['npc_initialization'] if index==0 else args[index]
                data['provenance'][key]['offset']+=2
                self.assertEqual(reader.extract_player_initialization(m,*args),{},(mac,key))
            for cut in [0,offset+positions['factory']+20,offset+table+15]:
                changed=copy.copy(m);changed.data=m.data[:cut]
                self.assertEqual(reader.extract_player_initialization(changed,a,v,s),{})
            self.assertEqual(reader.extract_player_initialization(m,{},v,s),{})
            self.assertEqual(reader.extract_player_initialization(m,a,{},s),{})


ANDROID_PARENTS = ({'npc_initialization': {'ordinary_half_extent': 1}}, {'equipment_rule': 'last_matching', 'item_type_value_index': 5}, {'initial': {}})


def android_functions(**changes):
    """Synthetic Android player chain in the shapes the reader matches."""
    from android_text_fixture import fill
    names = dict(shield_getter='_ZN4Ship14getMaxShieldHPEv', armor_getter='_ZN4Ship13getMaxArmorHPEv',
                 shield_setter='_ZN6Player14setMaxShieldHPEi', armor_setter='_ZN6Player13setMaxArmorHPEi',
                 type_getter='_ZN4Item7getSortEv', damage_setter='_ZN6Player13setVulnerableEb')
    names.update(changes.pop('names', {}))
    sorts = changes.pop('sorts', ['next'] * 9 + ['shield', 'armor'] + ['next'] * 19)
    following = fill(reader.ANDROID_LOOP_NEXT, head=changes.pop('loop_back', '#head')).strip().splitlines()
    ship = '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', changes.pop('reset', fill(reader.ANDROID_RESET)),
                      changes.pop('entry', fill(reader.ANDROID_LOOP_ENTRY, empty='#done', head='#head')),
                      'head:', fill(reader.ANDROID_LOOP_HEAD, **{'skip': '#skip', 'next': '#next', **changes.pop('head', {})}, **names),
                      '.cases ' + ', '.join(sorts), 'other:', 'b #next',
                      'shield:', fill(reader.ANDROID_SHIELD, next=changes.pop('shield_next', '#next')),
                      'armor:', fill(reader.ANDROID_ARMOR, next='#next'),
                      'next:', *following[:8], 'skip:', *following[8:], 'done:', 'pop.w {r4, r5, r6, r7, r8, sb, sl, fp, pc}'])
    functions = {
        '_ZN5Level12createPlayerEv': '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', fill(reader.ANDROID_FACTORY, **names), 'bx lr']),
        '_ZN4Ship14getMaxShieldHPEv': reader.ANDROID_HELPERS['shield_getter'],
        '_ZN4Ship13getMaxArmorHPEv': reader.ANDROID_HELPERS['armor_getter'],
        '_ZN6Player14setMaxShieldHPEi': fill(reader.ANDROID_HELPERS['shield_setter'], changed='#_ZN6Player16updateDamageRateEv'),
        '_ZN6Player13setMaxArmorHPEi': fill(reader.ANDROID_HELPERS['armor_setter'], changed=changes.pop('armor_changed', '#_ZN6Player16updateDamageRateEv')),
        '_ZN6Player16updateDamageRateEv': 'bx lr',
        '_ZN6PlayerC1Eiiiii': changes.pop('stats', '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', 'mov r4, r0',
                                                               'call _ZN6Player16updateDamageRateEv', reader.ANDROID_ACTIVE, 'mov r4, r0', 'bx lr'])),
        '_ZN4Ship12refreshValueEv': ship,
        '_ZN4Item7getSortEv': 'ldr r0, [r0, #8]\nbx lr',
        '_ZN11LevelScriptC1EP5LevelP3HudP5RadarP18TargetFollowCamera': '\n'.join([
            'push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', fill(reader.ANDROID_DAMAGE_DISPATCH, initial=changes.pop('initial', '#initial')),
            'other:', 'bx lr', 'initial:', fill(reader.ANDROID_DAMAGE, **names), 'bx lr']),
        '_ZN6Player13setVulnerableEb': 'strb.w r1, [r0, #0xc2]\nbx lr'}
    functions.update(changes)
    return {k: v for k, v in functions.items() if v is not None}


def android_extract(parents=ANDROID_PARENTS, **changes):
    from android_text_fixture import text_library
    lib, addresses = text_library(android_functions(**changes))
    return reader.extract_player_initialization(lib, *parents), addresses


class AndroidPlayerInitialization(unittest.TestCase):
    def test_named_chain_gives_values_and_spans(self):
        result, addresses = android_extract()
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'}, reader.VALUES)
        ship, script = addresses['_ZN4Ship12refreshValueEv'], addresses['_ZN11LevelScriptC1EP5LevelP3HudP5RadarP18TargetFollowCamera']
        p = result['provenance']
        self.assertEqual({k: (p[k]['offset'] - ship, p[k]['bytes']) for k in ('reset', 'loop_entry', 'loop_head', 'shield_entry', 'armor_entry', 'shield_assignment', 'armor_assignment', 'loop_next')},
                         {'reset': (4, 44), 'loop_entry': (48, 56), 'loop_head': (104, 24), 'shield_entry': (137, 1), 'armor_entry': (138, 1),
                          'shield_assignment': (160, 30), 'armor_assignment': (190, 16), 'loop_next': (206, 30)})
        self.assertEqual((p['damage_dispatch']['offset'] - script, p['damage_permission']['offset'] - script), (4, 16))
        self.assertEqual((p['factory']['offset'] - addresses['_ZN5Level12createPlayerEv'], p['active']['offset'] - addresses['_ZN6PlayerC1Eiiiii']), (4, 10))
        for key, name in [('shield_getter', '_ZN4Ship14getMaxShieldHPEv'), ('armor_getter', '_ZN4Ship13getMaxArmorHPEv'), ('shield_setter', '_ZN6Player14setMaxShieldHPEi'),
                          ('armor_setter', '_ZN6Player13setMaxArmorHPEi'), ('type_getter', '_ZN4Item7getSortEv'), ('damage_setter', '_ZN6Player13setVulnerableEb')]:
            self.assertEqual(p[key]['offset'], addresses[name], key)

    def test_each_broken_rule_is_unsupported(self):
        from android_text_fixture import fill
        entry, reset = fill(reader.ANDROID_LOOP_ENTRY, empty='#done', head='#head'), fill(reader.ANDROID_RESET)
        flagged = lambda *parts: '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', *parts, 'bx lr'])
        cases = {
            'no npc': dict(parents=({}, *ANDROID_PARENTS[1:])),
            'no vehicle': dict(parents=(ANDROID_PARENTS[0], {}, ANDROID_PARENTS[2])),
            'no staging': dict(parents=(*ANDROID_PARENTS[:2], {})),
            'other equipment rule': dict(parents=(ANDROID_PARENTS[0], {'equipment_rule': 'first_matching', 'item_type_value_index': 5}, ANDROID_PARENTS[2])),
            'other type index': dict(parents=(ANDROID_PARENTS[0], {'equipment_rule': 'last_matching', 'item_type_value_index': 4}, ANDROID_PARENTS[2])),
            'no factory': {'_ZN5Level12createPlayerEv': 'bx lr'},
            'shield getter field': {'_ZN4Ship14getMaxShieldHPEv': 'ldr r0, [r0, #0x20]\nbx lr'},
            'armor getter field': {'_ZN4Ship13getMaxArmorHPEv': 'ldr r0, [r0, #0x1c]\nbx lr'},
            'shield setter shape': {'_ZN6Player14setMaxShieldHPEi': 'strd r1, r1, [r0, #0x8c]\nb.w #_ZN6Player16updateDamageRateEv'},
            'armor setter shape': {'_ZN6Player13setMaxArmorHPEi': 'strd r1, r1, [r0, #0x90]\nb.w #_ZN6Player16updateDamageRateEv'},
            'setters differ': dict(armor_changed='#_ZN6Player13setVulnerableEb'),
            'not active': dict(stats=flagged('mov r4, r0', reader.ANDROID_ACTIVE.replace('strb.w r1, [r4, #0xc0]', 'strb.w r0, [r4, #0xc0]'))),
            'stats this changed': dict(stats=flagged('movs r0, #0', 'mov r4, r0', reader.ANDROID_ACTIVE)),
            'stats this lost': dict(stats=flagged('mov r4, r0', 'movs r4, #0', reader.ANDROID_ACTIVE)),
            'stats no this': dict(stats=flagged(reader.ANDROID_ACTIVE)),
            'no reset': dict(reset='mov r4, r0'),
            'ship this changed': dict(reset='movs r0, #0\n' + reset),
            'ship this lost': dict(entry='movs r4, #0\n' + entry),
            'reset after entry': dict(reset='mov r4, r0', entry=entry.replace('b #head', 'b #head\n' + reset)),
            'entry elsewhere': dict(entry=entry.replace('b #head', 'b #next')),
            'shield continues elsewhere': dict(shield_next='#skip'),
            'loop back elsewhere': dict(loop_back='#next'),
            'default elsewhere': dict(head=dict(next='#skip')),
            'skip elsewhere': dict(head=dict(skip='#next')),
            'shield not dispatched': dict(sorts=['next'] * 8 + ['shield', 'other', 'armor'] + ['next'] * 19),
            'type getter field': {'_ZN4Item7getSortEv': 'ldr r0, [r0, #0xc]\nbx lr'},
            'shield sort': dict(sorts=['next'] * 8 + ['shield', 'next', 'armor'] + ['next'] * 19),
            'armor sort': dict(sorts=['next'] * 9 + ['shield', 'next', 'armor'] + ['next'] * 18),
            'shield twice': dict(sorts=['shield'] + ['next'] * 8 + ['shield', 'armor'] + ['next'] * 19),
            'armor twice': dict(sorts=['next'] * 9 + ['shield', 'armor'] + ['next'] * 18 + ['armor']),
            'no dispatch': dict(initial='#other'),
            'damage setter field': {'_ZN6Player13setVulnerableEb': 'strb.w r1, [r0, #0xc3]\nbx lr'},
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(android_extract(**changes)[0], {})
