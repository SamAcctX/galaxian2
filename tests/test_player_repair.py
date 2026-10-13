"""Synthetic relocated repair declarations; no proprietary fixture bytes."""
import copy
import struct
import unittest
from types import SimpleNamespace
from gof2_content import player_repair as reader
from gof2_content.player_initialization import LAYOUTS as PLAYER_LAYOUTS
from test_font_selection import expand
from test_ship_models import branch


def fixture(mac,shift=0):
    arch='x86_64' if mac else 'armv7';origin=0x200000+shift;offset=256;bias=4096
    positions={k:1000 if k=='update' else 2500+i*500 for i,k in enumerate(reader.LAYOUTS[arch])}
    positions.update(factory=17000,clone_wrapper=17400,hull_current=19000,periods=20000 if mac else 1424)
    data=bytearray(21300);fields={}
    def write(at,raw):data[offset+at:offset+at+len(raw)]=raw
    def span(at,n):return {'offset':bias+offset+at,'bytes':n}
    def call(at,dest,kind='bl'):
        if mac:return struct.pack('<i',dest-at-4)
        raw=bytearray(branch(((origin+at+4)&~3)-4 if kind=='blx' else origin+at,origin+dest))
        if kind=='b.w':raw[3]&=~0x40
        if kind=='blx':raw[3]&=~0x10
        return raw
    update={('call_12' if mac else 'call_c'):'device_getter',('call_85' if mac else 'call_92'):'hull_max',
            ('call_cd' if mac else 'call_ee'):'hull_max',('call_91' if mac else 'call_a0'):'hull_add',
            ('call_d9' if mac else 'call_fc'):'armor_current',('call_e3' if mac else 'call_108'):'armor_max',
            ('call_ef' if mac else 'call_11a'):'armor_add'}
    for k in (['call_26','call_7b','call_c3'] if mac else ['call_22','call_86','call_e2']):update[k]='hull_current'
    targets={'update':update,'device_assignment':{('call_c' if mac else 'call_6'):'item_id'},
             'ship_clone':{('call_5f' if mac else 'call_a6'):'ship_ctor'},
             'factory':{('call_4' if mac else 'call_0'):'hull_source'}}
    layouts=dict(reader.LAYOUTS[arch],factory=PLAYER_LAYOUTS[arch]['factory'])
    for key,(size,spec) in layouts.items():
        at=positions[key];raw,masks=expand(spec);fields[key]=masks
        for field,destination in targets.get(key,{}).items():
            p,n=masks[field];raw[p:p+n]=call(at+p,positions[destination])
        if key in ['hull_add','armor_add']:
            field=('call_1e' if key=='hull_add' else 'call_24') if mac else 'call_10'
            p,n=masks[field];raw[p:p+n]=call(at+p,19400,'b.w')
        if key=='update':
            if not mac:
                for field in ['call_64','call_be']:
                    p,n=masks[field];raw[p:p+n]=call(at+p,19200,'blx')
            for field,extra in [('ref_60' if mac else 'ref_34',0),('ref_a8',8)]:
                p,n=masks[field];target=positions['periods']+extra
                if mac:raw[p:p+n]=struct.pack('<i',target-at-p-n)
                else:
                    delta=target-((at+p+4)&~3);reg=2 if extra==0 else 0
                    raw[p:p+n]=struct.pack('<HH',0xf20f|((delta>>11)<<10),(((delta>>8)&7)<<12)|(reg<<8)|(delta&255))
        write(at,raw)
    at=positions['clone_wrapper'];write(at+(8 if mac else 6),(b'\xe8'+call(at+9,positions['ship_clone'])) if mac else call(at+6,positions['ship_clone']))
    table=18000 if mac else positions['device_assignment']-100
    entries=[0]*30;entries[15]=positions['device_assignment']-table if mac else 50
    write(table,struct.pack('<30i',*entries) if mac else bytes(entries))
    write(positions['periods'],struct.pack('<4f',420,600,700,1000))
    text={'segment':b'__TEXT','name':b'__text','address':origin,'offset':offset,'length':19900}
    const={'segment':b'__TEXT','name':b'__const','address':origin+20000,'offset':offset+20000,'length':1000}
    if not mac:
        # Synthetic Mach-O import metadata identifies the existing ABI helper.
        struct.pack_into('<7I',data,0,0xfeedface,12,0,2,3,228,0)
        struct.pack_into('<2I',data,28,1,124);struct.pack_into('<I',data,76,1)
        struct.pack_into('<3I',data,116,origin+19200,16,offset+19200)
        struct.pack_into('<3I',data,140,8,0,16)
        names=b'\0___floatdisf\0'
        struct.pack_into('<6I',data,152,2,24,21000,1,21100,len(names))
        struct.pack_into('<2I',data,176,11,80);struct.pack_into('<2I',data,232,21200,1)
        struct.pack_into('<IB',data,21000,1,1);data[21100:21100+len(names)]=names
        struct.pack_into('<I',data,21200,0)
    m=SimpleNamespace(architecture=arch,data=bytes(data),slice_offset=bias,text=text,sections=[text,const])
    rp={'recharge':span(positions['update']-(94 if mac else 110),94 if mac else 110),
        'clock_zero':span(positions['timers_zero']+(22 if mac else 8),11 if mac else 8),
        'hull_getter':span(positions['hull_current'],12 if mac else 4)}
    player={'recharge':{'provenance':rp},'provenance':{'equipment_table':span(table,120 if mac else 30),
        'reset':span(positions['device_zero']+(31 if mac else 40),8 if mac else 12),
        'factory':span(positions['factory'],PLAYER_LAYOUTS[arch]['factory'][0])}}
    actors={'player_initialization':player,'npc_initialization':{'provenance':{'stats_entry':span(positions['stats_capacity']-(173 if mac else 112),4)}}}
    vehicle={'equipment_rule':'last_matching'};loadout={'provenance':{'ship_clone':span(at,27 if mac else 18)}}
    return m,actors,vehicle,loadout,positions,fields,offset


class RepairTests(unittest.TestCase):
    def test_relocated_source_links_and_values(self):
        for mac in [False,True]:
            for shift in [0,0x800000]:
                m,a,v,l,*_=fixture(mac,shift);result=reader.extract_player_repair(m,a,v,l)
                self.assertTrue(result,(mac,shift))
                self.assertEqual({k:x for k,x in result.items() if k!='provenance'},reader.VALUES)
                self.assertEqual(len(result['provenance']),16)

    def test_changed_layouts_and_disconnected_links(self):
        for mac in [False,True]:
            m,a,v,l,positions,fields,offset=fixture(mac)
            for key in reader.LAYOUTS[m.architecture]:
                changed=copy.copy(m);raw=bytearray(m.data);raw[offset+positions[key]+(0 if key!='ship_ctor' else 4)]^=255;changed.data=bytes(raw)
                self.assertFalse(reader.extract_player_repair(changed,a,v,l),(mac,key))
            for key,field in [('update','call_cd' if mac else 'call_ee'),('device_assignment','call_c' if mac else 'call_6'),('ship_clone','call_5f' if mac else 'call_a6')]:
                changed=copy.copy(m);raw=bytearray(m.data);raw[offset+positions[key]+fields[key][field][0]]^=2;changed.data=bytes(raw)
                self.assertFalse(reader.extract_player_repair(changed,a,v,l),(mac,key,field))
            changed=copy.copy(m);raw=bytearray(m.data);raw[offset+positions['periods']]^=1;changed.data=bytes(raw)
            self.assertFalse(reader.extract_player_repair(changed,a,v,l))
            if not mac:
                changed=copy.copy(m);raw=bytearray(m.data);raw[offset+positions['update']+fields['update']['ref_34'][0]+3]^=1;changed.data=bytes(raw)
                self.assertFalse(reader.extract_player_repair(changed,a,v,l),'Changed ARM literal register')
                changed=copy.copy(m);raw=bytearray(m.data);raw[21104]^=1;changed.data=bytes(raw)
                self.assertFalse(reader.extract_player_repair(changed,a,v,l),'Changed ARM conversion import')

    def test_missing_anchors_table_alias_and_truncation(self):
        for mac in [False,True]:
            m,a,v,l,positions,_,offset=fixture(mac)
            changed=copy.deepcopy(a);changed['player_initialization']['recharge']={}
            self.assertFalse(reader.extract_player_repair(m,changed,v,l))
            self.assertFalse(reader.extract_player_repair(m,a,{},l))
            changed=copy.copy(m);changed.data=m.data[:offset+positions['hull_source']+2]
            self.assertFalse(reader.extract_player_repair(changed,a,v,l))
            changed=copy.copy(m);raw=bytearray(m.data);at=offset+(18000 if mac else positions['device_assignment']-100)
            raw[at:at+(4 if mac else 1)]=struct.pack('<i',positions['device_assignment']-18000) if mac else bytes([50]);changed.data=bytes(raw)
            self.assertFalse(reader.extract_player_repair(changed,a,v,l))


ANDROID_PARENTS = ({'player_initialization': {'recharge': {'period_ms': 100}}, 'npc_initialization': {'is_player': False}},
                   {'equipment_rule': 'last_matching'}, {'ship_clone': 1})
EGO_UPDATE = '_ZN9PlayerEgo6updateEiP5RadarP3HudP5RadioP11LevelScriptibi'


def android_functions(periods='0x43d20000, 0x44160000, 0x442f0000, 0x447a0000', sorts=None, **changes):
    """Synthetic Android repair chain (periods 420/600 and 700/1000, item 75 slow)."""
    from android_text_fixture import fill
    from gof2_content import player_initialization as player, player_recharge as recharge
    names = dict(getter='_ZN4Ship14getShieldRegenEv', hull_getter='_ZN6Player12getHitpointsEv', adder='_ZN6Player16regenerateShieldEf',
                 device_getter='_ZN4Ship13getRepairTypeEv', hull_max='_ZN6Player15getMaxHitpointsEv', armor_current='_ZN6Player10getArmorHPEv',
                 armor_max='_ZN6Player13getMaxArmorHPEv', hull_add='#_ZN6Player14regenerateHullEv', armor_add='#_ZN6Player15regenerateArmorEv',
                 hull_periods='hull', armor_periods=changes.pop('armor_label', 'armor'), item_id='_ZN4Item8getIndexEv', type_getter='_ZN4Item7getSortEv',
                 ctor='_ZN4ShipC2Eiiiiiiiif')
    names.update(changes.pop('names', {}))
    repair = fill(reader.ANDROID_UPDATE, **names).strip().splitlines()[1:]  # opens with the recharge's skip target
    words = periods.split(', ')
    update = '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', 'mov sb, r0', fill(recharge.ANDROID_RECHARGE, **names), *repair,
                        'bx lr', 'hull:', '.word ' + ', '.join(words[:2]), 'armor:', '.word ' + ', '.join(words[2:])])
    following = fill(player.ANDROID_LOOP_NEXT, head='#head').strip().splitlines()
    sorts = sorts or ['next'] * 15 + ['device'] + ['next'] * 14
    ship = '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', changes.pop('reset', fill(player.ANDROID_RESET)),
                      'head:', fill(player.ANDROID_LOOP_HEAD, skip='#skip', next='#next', **names), '.cases ' + ', '.join(sorts),
                      'other:', 'b #next', 'device:', changes.pop('device', fill(reader.ANDROID_DEVICE, next='#next', **names)),
                      'next:', *following[:8], 'skip:', *following[8:], 'bx lr'])
    functions = {
        EGO_UPDATE: update,
        '_ZN9PlayerEgoC1EP6Player': changes.pop('ego', '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, lr}', 'vpush {d8}', fill(recharge.ANDROID_ENTRY),
                                                                   reader.ANDROID_TIMERS, recharge.ANDROID_CLOCK_ZERO, 'bx lr'])),
        '_ZN4Ship14getShieldRegenEv': recharge.ANDROID_HELPERS['getter'], '_ZN6Player12getHitpointsEv': recharge.ANDROID_HELPERS['hull_getter'],
        '_ZN6Player16updateDamageRateEv': 'bx lr',
        **{name: fill(reader.ANDROID_HELPERS[key], changed='#_ZN6Player16updateDamageRateEv') for key, name in [
            ('device_getter', '_ZN4Ship13getRepairTypeEv'), ('hull_max', '_ZN6Player15getMaxHitpointsEv'), ('armor_current', '_ZN6Player10getArmorHPEv'),
            ('armor_max', '_ZN6Player13getMaxArmorHPEv'), ('hull_add', '_ZN6Player14regenerateHullEv'), ('armor_add', '_ZN6Player15regenerateArmorEv')]},
        '_ZN4Ship12refreshValueEv': ship,
        '_ZN4Item8getIndexEv': 'ldr r0, [r0]\nbx lr', '_ZN4Item7getSortEv': 'ldr r0, [r0, #8]\nbx lr',
        '_ZN4Ship8getMaxHPEv': fill(reader.ANDROID_HULL_SOURCE),
        '_ZN6PlayerC1Eiiiii': changes.pop('stats', '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', 'mov r4, r0', reader.ANDROID_CAPACITY, 'bx lr'])),
        '_ZN4Ship5cloneEv': '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, lr}', fill(reader.ANDROID_CLONE, blank='0x42c80000', **names), 'bx lr']),
        '_ZN4ShipC2Eiiiiiiiif': changes.pop('ship_ctor', '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}', 'mov r4, r0', 'movs r6, #0', reader.ANDROID_UPGRADES, 'bx lr']))}
    functions.update(changes)
    return {k: v for k, v in functions.items() if v is not None}


def android_extract(parents=ANDROID_PARENTS, **changes):
    from android_text_fixture import text_library
    lib, addresses = text_library(android_functions(**changes))
    return reader.extract_player_repair(lib, *parents), lib, addresses


class AndroidRepairTests(unittest.TestCase):
    def test_named_chain_gives_values_and_spans(self):
        result, lib, addresses = android_extract()
        self.assertEqual({k: v for k, v in result.items() if k != 'provenance'}, reader.VALUES)
        p = result['provenance']
        at = lambda key, name: (p[key]['offset'] - addresses[name], p[key]['bytes'])
        # The repair opens where the 80-byte recharge (after push and the this copy) ends.
        self.assertEqual(at('update', EGO_UPDATE), (6 + 80, 242))
        self.assertEqual(lib.data[p['periods']['offset']:p['periods']['offset'] + 16], struct.pack('<4f', 420, 600, 700, 1000))
        ego, ship = '_ZN9PlayerEgoC1EP6Player', '_ZN4Ship12refreshValueEv'
        self.assertEqual(at('timers_zero', ego), (8 + 28, 44))
        self.assertEqual([at(k, ship) for k in ('device_zero', 'device_entry')], [(4 + 6, 12), (4 + 44 + 24 + 15, 1)])
        self.assertEqual(at('device_assignment', ship), (4 + 44 + 24 + 30 + 2, 24))
        self.assertEqual([at('stats_capacity', '_ZN6PlayerC1Eiiiii'), at('ship_ctor', '_ZN4ShipC2Eiiiiiiiif'), at('upgrade_zero', '_ZN4ShipC2Eiiiiiiiif')], [(6, 6), (8, 14), (6, 2)])
        self.assertEqual(at('ship_clone', '_ZN4Ship5cloneEv'), (4, 104))
        for key, name in [('device_getter', '_ZN4Ship13getRepairTypeEv'), ('hull_max', '_ZN6Player15getMaxHitpointsEv'), ('armor_current', '_ZN6Player10getArmorHPEv'),
                          ('armor_max', '_ZN6Player13getMaxArmorHPEv'), ('hull_add', '_ZN6Player14regenerateHullEv'), ('armor_add', '_ZN6Player15regenerateArmorEv'),
                          ('item_id', '_ZN4Item8getIndexEv'), ('hull_source', '_ZN4Ship8getMaxHPEv')]:
            self.assertEqual(p[key]['offset'], addresses[name], key)

    def test_each_broken_rule_is_unsupported(self):
        from android_text_fixture import fill
        from gof2_content import player_recharge as recharge
        ego = lambda *parts: '\n'.join(['push.w {r4, r5, r6, r7, r8, sb, sl, lr}', 'vpush {d8}', *parts, 'bx lr'])
        entry, timers = fill(recharge.ANDROID_ENTRY), reader.ANDROID_TIMERS + recharge.ANDROID_CLOCK_ZERO
        cases = {
            'no recharge': dict(parents=({'player_initialization': {}, 'npc_initialization': {'is_player': False}}, *ANDROID_PARENTS[1:])),
            'no npc': dict(parents=({'player_initialization': ANDROID_PARENTS[0]['player_initialization']}, *ANDROID_PARENTS[1:])),
            'other equipment rule': dict(parents=(ANDROID_PARENTS[0], {'equipment_rule': 'first_matching'}, ANDROID_PARENTS[2])),
            'no loadout': dict(parents=(*ANDROID_PARENTS[:2], {})),
            'not after recharge': {EGO_UPDATE: android_functions()[EGO_UPDATE].replace('subs r0, #0x65', 'subs r0, #0x66')},
            'update this from r1': {EGO_UPDATE: android_functions()[EGO_UPDATE].replace('mov sb, r0', 'mov sb, r1')},
            'device getter field': {'_ZN4Ship13getRepairTypeEv': 'ldr r0, [r0, #0x50]\nbx lr'},
            'hull max field': {'_ZN6Player15getMaxHitpointsEv': 'ldr.w r0, [r0, #0x88]\nbx lr'},
            'armor current field': {'_ZN6Player10getArmorHPEv': 'ldr.w r0, [r0, #0x88]\nbx lr'},
            'armor max field': {'_ZN6Player13getMaxArmorHPEv': 'ldr.w r0, [r0, #0x94]\nbx lr'},
            'hull amount': {'_ZN6Player14regenerateHullEv': fill(reader.ANDROID_HELPERS['hull_add'], changed='#_ZN6Player16updateDamageRateEv').replace('adds r1, #1', 'adds r1, #2')},
            'armor amount': {'_ZN6Player15regenerateArmorEv': fill(reader.ANDROID_HELPERS['armor_add'], changed='#_ZN6Player16updateDamageRateEv').replace('adds r1, #2', 'adds r1, #3')},
            'adders differ': {'_ZN6Player15regenerateArmorEv': fill(reader.ANDROID_HELPERS['armor_add'], changed='#_ZN6Player12getHitpointsEv')},
            'hull getter field': {'_ZN6Player12getHitpointsEv': 'ldr r0, [r0, #0x7c]\nbx lr'},
            'periods apart': dict(armor_label='hull'),
            'other periods': dict(periods='0x43d20000, 0x44160000, 0x442f0000, 0x44fa0000'),
            'no entry': dict(ego=ego(timers)),
            'entry without zero': dict(ego=ego(entry.replace('movs r6, #0', 'movs r6, #1'), timers)),
            'no timers': dict(ego=ego(entry, recharge.ANDROID_CLOCK_ZERO)),
            'timers without hull clock': dict(ego=ego(entry, reader.ANDROID_TIMERS)),
            'ego this lost': dict(ego=ego(entry, 'movs r4, #0', timers)),
            'zero integer lost': dict(ego=ego(entry, 'movs r6, #1', timers)),
            'zero vector lost': dict(ego=ego(entry, 'vld1.64 {d16, d17}, [r0:0x80]', timers)),
            'no reset': dict(reset='mov r4, r0'),
            'device sort': dict(sorts=['next'] * 14 + ['device'] + ['next'] * 15),
            'device twice': dict(sorts=['device'] + ['next'] * 14 + ['device'] + ['next'] * 14),
            'device not dispatched': dict(sorts=['next'] * 14 + ['device', 'other'] + ['next'] * 14),
            'device continues elsewhere': dict(device=fill(reader.ANDROID_DEVICE, next='#skip', item_id='_ZN4Item8getIndexEv')),
            'item id field': {'_ZN4Item8getIndexEv': 'ldr r0, [r0, #4]\nbx lr'},
            'upgrade bonus': {'_ZN4Ship8getMaxHPEv': fill(reader.ANDROID_HULL_SOURCE).replace('#0x28', '#0x30')},
            'no capacity': dict(stats='push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\nmov r4, r0\nbx lr'),
            'stats this lost': dict(stats='push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\nmov r4, r0\nmovs r4, #0\n' + reader.ANDROID_CAPACITY + '\nbx lr'),
            'no clone': {'_ZN4Ship5cloneEv': 'bx lr'},
            'no ship zero': dict(ship_ctor='push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\nmov r4, r0\n' + reader.ANDROID_UPGRADES + '\nbx lr'),
            'ship zero after': dict(ship_ctor='push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\nmov r4, r0\n' + reader.ANDROID_UPGRADES + '\nmovs r6, #0\nbx lr'),
            'ship zero lost': dict(ship_ctor='push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\nmov r4, r0\nmovs r6, #0\nmovs r6, #1\n' + reader.ANDROID_UPGRADES + '\nbx lr'),
            'ship this lost': dict(ship_ctor='push.w {r4, r5, r6, r7, r8, sb, sl, fp, lr}\nmov r4, r0\nmovs r6, #0\nmovs r4, #1\n' + reader.ANDROID_UPGRADES + '\nbx lr'),
        }
        for name, changes in cases.items():
            with self.subTest(name):
                self.assertEqual(android_extract(**changes)[0], {})
