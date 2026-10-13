"""Android proofs of the post-contest B'akka return."""
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gof2_content import bakka_return as reader


class BakkaReturnAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        import android_fixture
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_bakka_return(lib, {'scope': 'rescue_choreography'}, reader.CONTEST), values='VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(reader.extract_bakka_return(AndroidLibrary(image), {}, reader.CONTEST), ({}, {}))
            arrival = {'scope': 'rescue_choreography'}
            self.assertTrue(reader.extract_bakka_return(AndroidLibrary(image), arrival, reader.CONTEST)[1])
            # The Android library continues only after its own preceding declaration.
            for parent in (reader.MAC_CONTEST, {}, None):
                self.assertEqual(reader.extract_bakka_return(AndroidLibrary(image), arrival, parent), ({}, {}))

    def test_android_native_declarations(self):
        # The game file writes `const NAME:=`, which assert_native_android's pattern does not read.
        source = (Path(__file__).resolve().parents[1] / 'game/src/content/bakka_return_definitions.gd').read_text()
        spans = {k: [v[5] if len(v) == 6 else v[1], v[2]] for k, v in reader.ANDROID.items()}
        for name, value in [('VALUES', reader.VALUES), ('ANDROID_SPANS', spans)]:
            found = re.findall(r'^const ' + name + r' ?:?= ?(.+)$', source, re.MULTILINE)
            self.assertEqual(len(found), 1, name)
            self.assertEqual(json.loads(found[0]), value, name)


if __name__ == '__main__':
    unittest.main()
