"""Per-source voice tables, language pointers and radio timing stay connected."""
import copy
import struct
import unittest
from declaration_fixture import literal_fixture
from gof2_content import radio_audio as reader


def variants():
    return [('x86_64', reader.LAYOUTS['x86_64'], reader.DATA['x86_64']),
            ('armv7', reader.LAYOUTS['armv7'], reader.DATA['armv7']),
            ('x86_64', reader.MAC_ALTERNATE, reader.MAC_DATA)]


def fixture(arch,layout,data,shift=0,count=23):
    rows=copy.deepcopy(layout)
    table=b''.join(struct.pack('<ii',1000+i,200+i) for i in range(1504))
    values={'lookup_table':table,'language_table':bytes(data['language_table'][1]),
            'default_name':b'english\0','override_name':b'deutsch\0'}
    for key,(delta,size) in data.items():rows[key]=[delta,size,values[key].hex()]
    mach,origin,_,_=literal_fixture(arch,rows,shift,list(data))
    address=mach.text['address']+origin-mach.slice_offset-mach.text['offset']
    for key in ['default_name','override_name']:
        delta,size=data[key]
        mach.sections.append({'segment':b'__TEXT','name':b'__cstring','address':address+delta,
                              'offset':origin+delta-mach.slice_offset,'length':size})
    raw=bytearray(mach.data)
    struct.pack_into('<2Q' if arch=='x86_64' else '<2I',raw,
                     origin+data['language_table'][0]-mach.slice_offset,
                     address+data['default_name'][0],address+data['override_name'][0])
    mach.data=bytes(raw)
    dialogue={'campaign_cursor':0 if count==23 else 1,
              'events':[{'text_id':1000+i} for i in range(count)],
              'provenance':{k:{'offset':origin+layout[k][0],'bytes':layout[k][1]}
                            for k in ['display_delay','duration']}}
    fonts={'languages':{'rows':[{}, {'file':'de.lang','language_id':1}]}}
    return mach,dialogue,fonts,origin


class RadioAudioTests(unittest.TestCase):
    def test_relocated_owners_and_actual_table_values(self):
        for arch,layout,data in variants():
            for shift,count in [(0,23),(0x700000,3)]:
                mach,dialogue,fonts,origin=fixture(arch,layout,data,shift,count)
                result=reader.extract_radio_audio(mach,dialogue,fonts)
                self.assertEqual(result['event_ids'],list(range(200,200+count)))
                self.assertEqual(result['text_ids'],list(range(1000,1000+count)))
                self.assertEqual({k:result[k] for k in reader.VALUES},reader.VALUES)
                for span in result['provenance'].values():self.assertEqual(set(span),{'offset','bytes'})
                for valid in [-1,19999]:
                    raw=bytearray(mach.data)
                    struct.pack_into('<i',raw,origin+data['lookup_table'][0]-mach.slice_offset+4,valid)
                    mach.data=bytes(raw)
                    self.assertEqual(reader.extract_radio_audio(mach,dialogue,fonts)['event_ids'][0],valid)

    def test_every_proof_and_language_pointer(self):
        for arch,layout,data in variants():
            mach,dialogue,fonts,origin=fixture(arch,layout,data)
            for key,(delta,size,_) in layout.items():
                for endpoint in [0,size-1]:
                    bad=copy.copy(mach);raw=bytearray(mach.data)
                    raw[origin+delta+endpoint-mach.slice_offset]^=255;bad.data=bytes(raw)
                    self.assertFalse(reader.extract_radio_audio(bad,dialogue,fonts),(arch,key,endpoint))
            for key in ['language_table','default_name','override_name']:
                bad=copy.copy(mach);raw=bytearray(mach.data)
                raw[origin+data[key][0]-mach.slice_offset]^=1;bad.data=bytes(raw)
                self.assertFalse(reader.extract_radio_audio(bad,dialogue,fonts),(arch,key))

    def test_invalid_and_absent_voice_rows(self):
        for arch,layout,data in variants():
            mach,dialogue,fonts,origin=fixture(arch,layout,data)
            for column,row,value in [(4,0,-2),(4,0,20000),(0,0,-1),(0,0,65536),
                                     (0,0,65535),(0,1,1000)]:
                bad=copy.copy(mach);raw=bytearray(mach.data)
                struct.pack_into('<i',raw,origin+data['lookup_table'][0]-mach.slice_offset+row*8+column,value)
                bad.data=bytes(raw)
                self.assertFalse(reader.extract_radio_audio(bad,dialogue,fonts),(arch,column,row,value))

    def test_timing_language_and_section_boundaries(self):
        for arch,layout,data in variants():
            for change in ['duration','display_delay','language','language_id','count','cursor','section','truncation','arch']:
                mach,dialogue,fonts,origin=fixture(arch,layout,data)
                if change in ['duration','display_delay']:dialogue['provenance'][change]['offset']+=2
                elif change=='language':fonts['languages']['rows'][1]['file']='fr.lang'
                elif change=='language_id':fonts['languages']['rows'][1]['language_id']=0
                elif change=='count':dialogue['events'].pop()
                elif change=='cursor':dialogue['campaign_cursor']=2
                elif change=='section':mach.sections.pop()
                elif change=='truncation':mach.data=mach.data[:origin-mach.slice_offset]
                else:mach.architecture='unsupported'
                self.assertFalse(reader.extract_radio_audio(mach,dialogue,fonts),(arch,change))


def android_radio(texts=(1657, 1658, 1659), shift=0, fonts_file='de.lang', names=(b'english', b'deutsch'), missing=None):
    """A synthetic library holding every Android span, its language table pointing at
    two names and a voice table mapping each text's Android id to 700 + its index.
    Returns (library, patched layout, dialogue, fonts)."""
    import hashlib
    from android_fixture import layout_library
    from gof2_content.declaration_layouts import recognize_symbols
    from gof2_content.android_library import AndroidLibrary
    from gof2_content.text_ids import android_id
    # An extra synthetic table reserves .rodata room for the names.
    room = {'names': ('_ZN8GameText11getLanguageEv', 40, 32, 'sha256:' + '0' * 64, 'literal', 0)}
    image, layout, _ = layout_library({**reader.ANDROID, **room}, shift)
    proof = recognize_symbols(AndroidLibrary(image), layout)
    names_at = proof.pop('names')['offset']
    del layout['names']
    image = bytearray(image)
    for index, name in enumerate(names):
        image[names_at + 16 * index:names_at + 16 * index + len(name) + 1] = name + b'\0'
    at = proof['language_table']['offset']
    image[at:at + 8] = struct.pack('<2I', names_at, names_at + 16)  # .rodata addresses equal file offsets here
    rows = [(android_id(text), 700 + i) for i, text in enumerate(texts) if text != missing] + [(30000 + i, -1) for i in range(1504)]
    at = proof['lookup_table']['offset']
    image[at:at + 12032] = b''.join(struct.pack('<ii', *row) for row in rows[:1504])
    layout = {**layout, 'language_table': (*layout['language_table'][:3], image[proof['language_table']['offset']:][:8].hex(), *layout['language_table'][4:]),
              'lookup_table': (*layout['lookup_table'][:3], 'sha256:' + hashlib.sha256(bytes(image[at:at + 12032])).hexdigest(), *layout['lookup_table'][4:])}
    lib = AndroidLibrary(bytes(image))
    proof = recognize_symbols(lib, layout)
    timing = {key: {'offset': proof[key]['offset'], 'bytes': proof[key]['bytes']} for key in ('duration', 'display_delay')}
    dialogue = {'campaign_cursor': 1, 'events': [{'text_id': text} for text in texts], 'provenance': timing}
    fonts = {'languages': {'rows': [{'file': 'gb.lang', 'language_id': 0}, {'file': fonts_file, 'language_id': 1}]}}
    return lib, layout, dialogue, fonts


class AndroidRadioAudioTests(unittest.TestCase):
    def read(self, lib, layout, dialogue, fonts):
        from unittest.mock import patch
        with patch.object(reader, 'ANDROID', layout):
            return reader.extract_radio_audio(lib, dialogue, fonts)

    def test_voices_names_and_spans(self):
        for shift in (0, 0x1000):
            lib, layout, dialogue, fonts = android_radio(shift=shift)
            result = self.read(lib, layout, dialogue, fonts)
            self.assertEqual({k: v for k, v in result.items() if k not in ('event_ids', 'text_ids', 'provenance')}, reader.ANDROID_VALUES)
            # The table holds Android text ids; the result keeps the Mac 1.0.7 ones.
            self.assertEqual((result['text_ids'], result['event_ids']), ([1657, 1658, 1659], [700, 701, 702]))
            self.assertEqual(set(result['provenance']), set(reader.ANDROID) | {'default_name', 'override_name'})
            for key, rule in layout.items():
                span = result['provenance'][key]
                self.assertEqual((span['offset'] - span['anchor'], span['bytes']), (rule[5] if len(rule) == 6 else rule[1], rule[2]), key)
            names = result['provenance']['default_name'], result['provenance']['override_name']
            self.assertEqual([(n['bytes'], n['offset'] - n['anchor']) for n in names], [(8, 0), (8, 0)])
            self.assertEqual(names[1]['offset'] - names[0]['offset'], 16)

    def test_each_broken_proof_or_owner_is_unsupported(self):
        lib, layout, dialogue, fonts = android_radio()
        proof = self.read(lib, layout, dialogue, fonts)['provenance']
        for key in layout:
            span = proof[key]
            for index in {0, span['bytes'] - 1}:
                raw = bytearray(lib.data)
                raw[span['offset'] + index] ^= 0xff
                from gof2_content.android_library import AndroidLibrary
                self.assertFalse(self.read(AndroidLibrary(bytes(raw)), layout, dialogue, fonts), (key, index))
        cases = {'names': dict(names=(b'english', b'deutsc')), 'language file': dict(fonts_file='fr.lang'), 'unvoiced text': dict(missing=1658)}
        for name, options in cases.items():
            self.assertFalse(self.read(*android_radio(**options)), name)
        owner = copy.deepcopy(dialogue); owner['campaign_cursor'] = 0
        self.assertFalse(self.read(lib, layout, owner, fonts), 'owner size')
        owner = copy.deepcopy(dialogue); owner['provenance']['duration']['offset'] += 2
        self.assertFalse(self.read(lib, layout, owner, fonts), 'timing owner')

    def test_android_native_declarations(self):
        from android_fixture import assert_native_android
        assert_native_android(self, reader, 'radio_audio_definitions.gd')

if __name__=='__main__':unittest.main()
