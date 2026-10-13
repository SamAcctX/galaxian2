"""Android proofs of the Void visit, pursuers and return dialogue."""
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gof2_content import post_sahi as reader


class PostSahiAndroidTests(unittest.TestCase):
    def test_android_proofs(self):
        import android_fixture
        from gof2_content.android_library import AndroidLibrary
        from test_mido_travel import roomy
        with patch.object(android_fixture, 'library', roomy(android_fixture.library)):
            android_fixture.verify_android_proof(self, reader, lambda lib: reader.extract_post_sahi(lib, {'scope': 'rescue_choreography'}), values='VALUES')
            image, layout, _ = android_fixture.layout_library(reader.ANDROID)
        with patch.object(reader, 'ANDROID', layout):
            self.assertEqual(reader.extract_post_sahi(AndroidLibrary(image), {}), ({}, {}))

    def test_android_native_declarations(self):
        # The game file writes `const VALUES:=`, which assert_native_android's pattern does not read.
        source = (Path(__file__).resolve().parents[1] / 'game/src/content/post_sahi_definitions.gd').read_text()
        spans = {k: [v[5] if len(v) == 6 else v[1], v[2]] for k, v in reader.ANDROID.items()}
        for name, value in [('VALUES', reader.VALUES), ('ANDROID_SPANS', spans)]:
            found = re.findall(r'^const ' + name + r' ?:?= ?(.+)$', source, re.MULTILINE)
            self.assertEqual(len(found), 1, name)
            self.assertEqual(json.loads(found[0]), value, name)


if __name__ == '__main__':
    unittest.main()
