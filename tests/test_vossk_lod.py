"""Empty child declarations require a complete, immutable registry proof."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import vossk_lod as reader


class VosskLodTests(unittest.TestCase):
    def test_complete_source_layouts_relocation_and_mutation(self):
        for attribute in ('LAYOUTS', 'MAC_ALTERNATE'):
            for relocation in (0, 0x800000):
                mach, arrival, layouts = declaration_fixture(getattr(reader, attribute), relocation)
                with patch.object(reader, attribute, layouts):
                    values, proof = reader.extract_vossk_lod(mach, arrival)
                    self.assertEqual(values, reader.VALUES)
                    self.assertEqual(set(proof), set(layouts))
                    values['resource_ids'].clear()
                    self.assertEqual(reader.extract_vossk_lod(mach, arrival)[0], reader.VALUES)
                    for name, (delta, size, _, _) in layouts.items():
                        for endpoint in (0, size - 1):
                            changed = copy.copy(mach)
                            raw = bytearray(mach.data)
                            raw[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta + endpoint] ^= 255
                            changed.data = bytes(raw)
                            self.assertEqual(reader.extract_vossk_lod(changed, arrival), ({}, {}), name)
                    mach.architecture = 'armv7'
                    self.assertEqual(reader.extract_vossk_lod(mach, arrival), ({}, {}))

    def test_only_the_two_unregistered_children_are_optional(self):
        self.assertEqual(reader.VALUES, {'scope': 'vossk_empty_lod_children',
                                        'hull_catalogue_id': 13, 'resource_ids': [17040, 17041]})
        for source in (reader.LAYOUTS, reader.MAC_ALTERNATE):
            self.assertEqual(len(source), 7)
            self.assertGreater(source['vossk_traffic_lod_registry_main'][1], 300000)
            self.assertTrue(all(row[2] == '__text' for row in source.values()))
