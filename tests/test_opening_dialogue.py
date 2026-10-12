"""Synthetic relocated declarations; no game bytes or original strings stored."""
import importlib.util
import struct
from types import SimpleNamespace
import unittest
from test_ship_models import branch
from test_materials import arm_wide
from gof2_content.opening_dialogue import (MAC_SINGLE, MAC_RANGE, ARM_SINGLE, ARM_RANGE,
                                         extract_opening_dialogue)


def fixture(mac, relocation=0):
    base = (0x100000000 if mac else 0x10000) + relocation
    code = bytearray(16384)
    marks = {}
    pos = 256
    def raw(hexadecimal):
        nonlocal pos
        block = bytes.fromhex(hexadecimal); code[pos:pos+len(block)] = block; pos += len(block)
    def word(value):
        nonlocal pos
        code[pos:pos+4] = struct.pack('<I',value); pos += 4
    def rel(target):
        nonlocal pos
        code[pos:pos+4] = struct.pack('<i',target-pos-4); pos += 4
    def call(target, thumb=False):
        nonlocal pos
        if mac:
            raw('e8'); rel(target)
        else:
            block = bytearray(branch(base+pos-(pos%4 if thumb else 0),base+target))
            if thumb: block[3] &= ~0x10  # BLX immediate to aligned synthetic stub.
            code[pos:pos+4] = block; pos += 4
    def mov(reg, value):
        nonlocal pos
        if mac:
            raw({'edi':'bf','esi':'be','edx':'ba','ecx':'b9','r8d':'41b8','r9d':'41b9'}[reg]); word(value)
        else:
            number=int(reg[1:])
            if value < 256: raw(struct.pack('<H',0x2000 | number << 8 | value).hex())
            else:
                block=arm_wide(value,reg=number);code[pos:pos+4]=block;pos+=4
    if mac:
        raw('4989ff49c787b00100000000000081fea10000000f87');rel(12000)
        raw('89f0488d0d'); rel(7000);raw('486304814801c8ffe0')
        code[7000:7004]=struct.pack('<i',1024-7000)
    else:
        raw('a12c00f20080dfe814f0')
        code[pos:pos+2]=struct.pack('<H',(1024-pos)//2)
    pos=1024
    if mac:
        mov('edi',24);call(11000);raw('4889c3');mov('edi',8);call(11004)
        raw('48894308c743100100000048c70000000000c7030000000049899fb0010000')
        mov('edi',23);raw('4889de');call(11008)
    else:
        raw('4ff0ff30cdf8f0050c20');call(11000,True);raw('06900120cdf8f00504200595');call(11004,True)
        raw('06990123069a5060069a936000220260069802600598c0f814111720');call(11008)
    for i in range(23):
        marks[f'row{i}']=pos
        condition = 9 if i==9 else 27 if i==16 else 5
        value = 4 if i==9 else 80+i
        if mac:
            mov('edi',56);call(11000);raw('4889c34889df')
            marks[f'text{i}']=pos+1;mov('esi',1000+i);mov('edx',30+i);mov('ecx',condition);mov('r8d',value)
            if i==9: mov('r9d',4)
            marks[f'ctor{i}']=pos;call(8500 if i==9 else 8000)
            raw('498b87b0010000488b4008')
            if i==0: raw('488918')
            elif i*8<128: raw('488958'+bytes([i*8]).hex())
            else: raw('488998');word(i*8)
        else:
            raw('4ff0ff30cdf8f0052820');call(11000,True);mov('r1',i+2)
            raw(bytes([7+i,0x90,7+i,0x98]).hex());raw('cdf8f015')
            if i==9:
                mov('r2',value);mov('r1',4);raw('0092');mov('r2',30+i);raw('0191')
            else:
                mov('r1',value);mov('r2',30+i);raw('0091')
            marks[f'text{i}']=pos;mov('r1',1000+i);mov('r3',condition)
            marks[f'ctor{i}']=pos;call(8500 if i==9 else 8000)
            raw(bytes([7+i,0x98]).hex());raw('059ad2f81411' if i==22 else '0599d1f81411');raw('4968')
            raw(struct.pack('<H',0x6008 | i << 6).hex())
    if mac: raw('e9');rel(12000)
    else: call(12000);code[pos-1] &= ~0x40  # B.W instead of BL.
    marks['end']=pos
    def helper(at,spec):
        nonlocal pos
        pos=at
        for token in spec.split():
            if token.startswith('{'):
                if mac: rel(11004)
                else: call(11004,True)
            else:raw(token)
    helper(8000,MAC_SINGLE if mac else ARM_SINGLE)
    pos=8500
    if mac:raw('554889e55de9');rel(9000)
    else:raw('90b501af82b00446b868d7f80c908de801022046');call(9000);raw('204602b090bd')
    helper(9000,MAC_RANGE if mac else ARM_RANGE)
    pos=13000
    if mac:
        raw('488b45b049894528498b45106900d007000005dc0500004189453841c6453d01')
        pos=13100;raw('b8d0070000480343284839f0488975a80f8d');rel(13200);raw('f6433d01')
    else:
        raw('0e9a4ff4fa61109850610f98906190680068484300f2dc505062012082f82900')
        pos=13100;raw('3346002253f8140f596810f5fa6041f10001a0424ff0000028bf01205145a8bf012208bf0246002a40f00080')
    text=dict(address=base,offset=256,length=len(code),name=b'__text',segment=b'__TEXT')
    return SimpleNamespace(data=bytes(256)+code,sections=[text],text=text,slice_offset=4096,architecture='x86_64' if mac else 'armv7'),marks


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'Optional Capstone dependency not installed')
class DialogueTests(unittest.TestCase):
    def test_relocated_changed_content(self):
        for mac in (False,True):
            for shift in (0,0x18000):
                m,_=fixture(mac,shift);result=extract_opening_dialogue(m)
                self.assertTrue(result,(mac,shift))
                self.assertEqual([e['text_id'] for e in result['events']],list(range(1000,1023)))
                self.assertEqual(result['events'][9]['values'],[4,5,6,7])
                self.assertEqual(result['events'][16]['values'],[96])
                self.assertEqual(result['timing']['display_delay_ms'],2000)
    def test_rejects_corrupt_layouts_and_links(self):
        for mac in (False,True):
            for bad in ('dispatch','constructor','link','range','record','tail','timing','truncated'):
                m,marks=fixture(mac);data=bytearray(m.data)
                at={'dispatch':256,'constructor':8000,'range':9000,'record':marks['row10'],'link':marks['ctor5'],'tail':marks['end']-(5 if mac else 4),'timing':13000}.get(bad)
                if bad=='truncated': m.text['length']=7000
                else:data[256+at]^=0x80
                m.data=bytes(data)
                self.assertEqual(extract_opening_dialogue(m),{},(mac,bad))


def radio_event(index, text, speaker, condition, value, amount=1, value_register=None, store=None, size=0x28, ctor=None):
    """Thumb text of one Android radio event: allocation, constant arguments, constructor, list store."""
    from gof2_content.opening_dialogue import RANGE, SINGLE
    lines = ['movs r0, #%#x' % size, 'blx <_Znwj>', 'mov r5, r0', 'movw r1, #%#x' % text, 'movs r2, #%d' % speaker, 'movs r3, #%d' % condition]
    if amount != 1:
        lines += ['movs r0, #%d' % amount, 'strd r6, r0, [sp]']
    elif value_register:
        lines += ['str %s, [sp]' % value_register]
    else:
        lines += [('movw r0, #%#x' if value > 255 else 'movs r0, #%d') % value, 'str r0, [sp]']
    lines += ['mov r0, r5', 'blx <%s>' % (ctor or (RANGE if amount != 1 else SINGLE))]
    if store is not False:
        lines += ['ldr.w r0, [r4, #0x114]', 'ldr r0, [r0, #4]', store or ('str r5, [r0, #%#x]' % (4 * index) if index else 'str r5, [r0]')]
    return '\n'.join(lines) + '\n'


def opening_events(count=23):
    """Synthetic opening list: a timed start, then each event after the previous; 9 is a range."""
    rows = []
    for i in range(count):
        if i == 0: rows.append((2000, 7, 5, 1500, 1))
        elif i == 9: rows.append((2009, 0, 9, 0, 3))
        else: rows.append((2000 + i, i % 4, 6, i - 1, 1))
    return rows


def android_radio(opening=None, rescue=None, list_counts=(23, 3), opening_text=None, rescue_tail=True, ends=None, omit=(), single_prefix='', range_prefix=''):
    """Level::createRadioMessages with cases 0 and 1 in the Android shapes (case 1's last
    store in a shared tail), the RadioMessage constructors and the Radio timing blocks."""
    from android_fixture import TEXT, library, stub
    from thumb_shapes import assemble
    from gof2_content.android_library import AndroidLibrary
    from gof2_content import opening_dialogue as O
    calls = {'_Znwj': stub('_Znwj'), '_Znaj': stub('_Znaj'), '_Z14ArraySetLengthIP12RadioMessageEvjR5ArrayIT_E': TEXT,
             O.SINGLE: TEXT + 0x40, O.RANGE: TEXT + 0x80}
    functions = [('_Z14ArraySetLengthIP12RadioMessageEvjR5ArrayIT_E', b'\x70\x47\x00\xbf', TEXT),
                 (O.SINGLE, assemble(single_prefix + O.ANDROID_SINGLE + 'pop {r4, r5, r6, r7, pc}', TEXT + 0x40, calls=calls)[0], TEXT + 0x40),
                 (O.RANGE, assemble(range_prefix + O.ANDROID_RANGE + 'pop.w {r4, r5, r6, r7, r8, sb, pc}', TEXT + 0x80, calls=calls)[0], TEXT + 0x80),
                 ('_ZN5Radio6updateElP9PlayerEgoP11LevelScript', assemble('nop\n' + O.ANDROID_DURATION + 'bx lr', TEXT + 0x100, {'per_line': 1920, 'base': 1400})[0], TEXT + 0x100),
                 ('_ZN5Radio4drawExP9PlayerEgoP11LevelScript', assemble('nop\n' + O.ANDROID_DELAY + 'bx lr', TEXT + 0x140, {'delay': 1792, 'waiting': TEXT + 0x160})[0], TEXT + 0x140)]
    opening = opening or opening_text or ''.join(radio_event(i, *row, value_register='r6' if row[3] == 0 and row[4] == 1 else None)
                                                 for i, row in enumerate(opening_events()))
    rescue = rescue or (radio_event(0, 2023, 2, 5, 10000) + radio_event(1, 2024, 2, 6, 0, value_register='r6')
                        + radio_event(2, 2025, 2, 6, 1, store=False))
    lists = [O.ANDROID_LIST.replace('#{count}', '#%d' % n) for n in list_counts]
    tail = ('b.w @tail\n' if rescue_tail else 'ldr.w r0, [r4, #0x114]\nldr r0, [r0, #4]\nstr r5, [r0, #8]\nb.w @%s\n' % (ends or {}).get(1, 'end'))
    text = ('push.w {r4, r5, r6, r7, r8, lr}\n' + O.ANDROID_DISPATCH + 'case0: ' + lists[0].strip() + '\n' + opening + 'b.w @%s\n' % (ends or {}).get(0, 'end')
            + 'case1: ' + lists[1].strip() + '\n' + rescue + tail
            + 'end: pop.w {r4, r5, r6, r7, r8, pc}\ntail: ldr.w r0, [r4, #0x114]\nldr r0, [r0, #4]\nstr r5, [r0, #8]\nb.w @%s\n' % (ends or {}).get('tail', 'end')
            + 'other: pop.w {r4, r5, r6, r7, r8, pc}\n')
    code, labels, _ = assemble(text, TEXT + 0x200, {'outside': TEXT + 0x200}, calls=calls,
                               tables={'cases': ['case0', 'case1'] + ['end'] * 160})
    functions.append((O.RADIO_MESSAGES, code, TEXT + 0x200))
    functions = [row for row in functions if row[0] not in omit]
    return AndroidLibrary(library(functions, {}, text_size=0x3000)), labels


@unittest.skipUnless(importlib.util.find_spec('capstone'), 'optional static-reader dependency')
class AndroidOpeningDialogue(unittest.TestCase):
    def test_lists_constructors_and_timing(self):
        from android_fixture import TEXT
        from gof2_content.opening_dialogue import extract_arrival_dialogue
        lib, labels = android_radio()
        opening = extract_opening_dialogue(lib)
        # Android text 2000 + i is Mac 1.0.7 text 1989 + i.
        expected = [{'text_id': text - 11, 'speaker_id': speaker, 'condition': condition, 'values': list(range(value, value + amount))}
                    for text, speaker, condition, value, amount in opening_events()]
        self.assertEqual(opening['events'], expected)
        # Synthetic timing (the game accepts only the original 2000/1500/2000).
        self.assertEqual(opening['timing'], {'display_delay_ms': 1792, 'base_duration_ms': 1400, 'per_line_ms': 1920})
        provenance = opening['provenance']
        self.assertEqual({k: v['bytes'] for k, v in provenance.items() if k != 'declaration'},
                         {'dispatch': 18, 'dispatch_table': 324, 'single_constructor': 36, 'range_wrapper': 4, 'range_constructor': 78, 'duration': 26, 'display_delay': 30})
        self.assertEqual(provenance['declaration'], {'offset': labels['case0'], 'bytes': labels['case1'] - labels['case0']})
        self.assertEqual((provenance['dispatch']['offset'], provenance['single_constructor']['offset']), (TEXT + 0x204, TEXT + 0x40))
        arrival = extract_arrival_dialogue(lib, opening)
        self.assertEqual(arrival['events'], [{'text_id': 2012, 'speaker_id': 2, 'condition': 5, 'values': [10000]},
                                             {'text_id': 2013, 'speaker_id': 2, 'condition': 6, 'values': [0]},
                                             {'text_id': 2014, 'speaker_id': 2, 'condition': 6, 'values': [1]}])
        self.assertEqual(arrival['provenance']['shared_store'], {'offset': labels['tail'], 'bytes': 12})
        self.assertEqual(arrival['provenance']['declaration'], {'offset': labels['case1'], 'bytes': labels['end'] - labels['case1']})
        # The rescue may also store its last event in its own run.
        lib = android_radio(rescue_tail=False)[0]
        arrival = extract_arrival_dialogue(lib, extract_opening_dialogue(lib))
        self.assertEqual((len(arrival['events']), 'shared_store' in arrival['provenance']), (3, False))

    def test_each_broken_declaration_is_unsupported(self):
        from gof2_content.opening_dialogue import RANGE, SINGLE, extract_arrival_dialogue
        events = opening_events()
        def opening_with(index, **options):
            return ''.join(radio_event(i, *row, **(options if i == index else {})) for i, row in enumerate(events))
        cases = {'store order': dict(opening_text=opening_with(3, store='str r5, [r0, #0x10]')),
                 'stored object': dict(opening_text=opening_with(3, store='str r6, [r0, #0xc]')),
                 'message size': dict(opening_text=opening_with(4, size=0x24)),
                 'other callee': dict(opening_text=opening_with(5, ctor='_Znaj')),
                 'unknown field': dict(opening_text=opening_with(6, value_register='r7')),
                 'other instruction': dict(opening_text=opening_with(7).replace('mov r0, r5\n', 'adds r1, #1\nmov r0, r5\n', 1)),
                 'text outside the table': dict(opening_text=''.join(radio_event(i, *((3500,) + row[1:] if i == 2 else row)) for i, row in enumerate(events))),
                 'no range': dict(opening_text=''.join(radio_event(i, *((2009, 0, 6, 8, 1) if i == 9 else row)) for i, row in enumerate(events))),
                 'list size': dict(list_counts=(22, 3), opening_text=''.join(radio_event(i, *row) for i, row in enumerate(events[:22]))),
                 'constructor after code': dict(single_prefix='nop\n'), 'range constructor after code': dict(range_prefix='nop\n'),
                 'constructed elsewhere': dict(opening_text=''.join(radio_event(i, *row, store='str r6, [r0, #0xc]').replace('mov r0, r5\n', 'mov r0, r6\n')
                                                            if i == 3 else radio_event(i, *row) for i, row in enumerate(events))),
                 'stale argument': dict(opening_text=opening_with(5).replace('movs r2, #1\n', '', 1))}
        for name, options in cases.items():
            self.assertEqual(extract_opening_dialogue(android_radio(**options)[0]), {}, name)
        for name in (SINGLE, RANGE, '_ZN5Radio6updateElP9PlayerEgoP11LevelScript', '_ZN5Radio4drawExP9PlayerEgoP11LevelScript'):
            self.assertEqual(extract_opening_dialogue(android_radio(omit=(name,))[0]), {}, name)
        # The rescue ends where the opening does; its dependencies stay fixed.
        for options in (dict(ends={'tail': 'other'}), dict(rescue=radio_event(0, 2023, 2, 5, 10000) + radio_event(1, 2024, 2, 6, 0, value_register='r6')
                                                              + radio_event(2, 2025, 2, 6, 0, value_register='r6', store=False))):
            lib = android_radio(**options)[0]
            self.assertEqual(extract_arrival_dialogue(lib, extract_opening_dialogue(lib)), {}, options)

if __name__ == '__main__': unittest.main()
