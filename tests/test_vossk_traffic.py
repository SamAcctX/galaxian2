"""Ordinary Vossk declarations require complete, source-specific evidence."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from declaration_fixture import declaration_fixture
from gof2_content import vossk_traffic as reader


class VosskTrafficTests(unittest.TestCase):
    def test_source_layouts_relocation_and_mutation(self):
        for attribute in ('LAYOUTS', 'MAC_ALTERNATE'):
            source = getattr(reader, attribute)
            for relocation in (0, 0x800000):
                mach, arrival, layouts = declaration_fixture(source, relocation)
                with patch.object(reader, attribute, layouts):
                    values, proof = reader.extract_vossk_traffic(mach, arrival)
                    self.assertEqual(values, reader.VALUES)
                    self.assertEqual(set(proof), set(layouts))
                    values['assembly']['body_resource_ids'].clear()
                    self.assertEqual(reader.extract_vossk_traffic(mach, arrival)[0], reader.VALUES)
                    for name, (delta, _, _, _) in layouts.items():
                        changed = copy.copy(mach)
                        raw = bytearray(mach.data)
                        raw[arrival['provenance']['actor']['offset'] - mach.slice_offset + delta] ^= 255
                        changed.data = bytes(raw)
                        self.assertEqual(reader.extract_vossk_traffic(changed, arrival), ({}, {}), name)
                    mach.architecture = 'armv7'
                    self.assertEqual(reader.extract_vossk_traffic(mach, arrival), ({}, {}))

    def test_distinct_hull_collision_and_wreck(self):
        self.assertEqual(reader.VALUES['hull_catalogue_id'], 13)
        self.assertEqual(len(reader.VALUES['boxes']), 5)
        self.assertEqual(reader.VALUES['death']['wreck_layout_id'], 4)
        self.assertTrue(all(all(value > 0 for value in box['half_extents']) for box in reader.VALUES['boxes']))
