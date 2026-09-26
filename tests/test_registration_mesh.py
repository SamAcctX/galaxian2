"""Synthetic mesh records and explicit resource supplements; never executable."""
import hashlib
import struct
import unittest

from test_bindings import executable, PATH
from gof2_content.registrations import MachO, mac_records, mesh_supplement
from gof2_content.formats import ContentError


def fixture(gap=True, copies=1):
    data = bytearray(executable())
    text_address, string_address = 0x100002000, 0x100003000
    code = bytearray()
    for _ in range(copies):
        at = len(code)
        prefix = (bytes.fromhex('66 41 c7 44 24 08') + struct.pack('<H', 123)
                  + bytes.fromhex('41 c6 44 24 0a 00 48 8d 3d')
                  + struct.pack('<i', string_address - text_address - at - 21)
                  + bytes.fromhex('e8 00 00 00 00 89 c3 ff c3 48 89 df e8 00 00 00 00'))
        body = (bytes.fromhex('49 89 04 24 48 8d 35')
                + struct.pack('<i', string_address - text_address - at - len(prefix) - 11)
                + bytes.fromhex('48 89 c7 48 89 da e8 00 00 00 00 66 41 c7 07')
                + struct.pack('<H', 17)
                + bytes.fromhex('41 c7 47 04 04 00 00 00 41 c7 47 08 ff ff ff ff')
                + (bytes.fromhex('48 8d b5 20 ff ff ff') if gap else b'')
                + bytes.fromhex('4d 89 67 10'))
        code.extend(prefix + body)
    data[512:512 + len(code)] = code
    struct.pack_into('<Q', data, 32 + 72 + 40, len(code))
    return bytes(data)


def header(source):
    result = dict(architecture='x86_64', base_content_id='a' * 64,
                  source_executable_sha256=hashlib.sha256(source).hexdigest(),
                  source_executable_bytes=len(source), records_sha256='b' * 64)
    identity = 'gof2-bindings-v1\n%s\n%s\nx86_64\n%s\n' % (
        result['base_content_id'], result['source_executable_sha256'], result['records_sha256'])
    result['binding_id'] = hashlib.sha256(identity.encode()).hexdigest()
    return result


class MeshRegistrationTests(unittest.TestCase):
    def test_stack_address_setup_preserves_mesh_and_material_link(self):
        before = mac_records(MachO(fixture(False), 'mac-full-hd'), lambda *_: None)
        after = mac_records(MachO(fixture(True), 'mac-full-hd'), lambda *_: None)
        self.assertEqual(after, before)
        self.assertEqual(len(after), 1)
        self.assertEqual((after[0]['id'], after[0]['resource'], after[0]['material_id'],
                          after[0]['mesh_flags']), (17, 'resources/' + PATH, 123, 0))

    def test_wrong_payload_or_scratch_register_is_not_a_mesh_declaration(self):
        source = fixture()
        for old, new in [('4d896710', '4d896f10'), ('488db5', '488dbd')]:
            broken = source.replace(bytes.fromhex(old), bytes.fromhex(new))
            self.assertEqual(mac_records(MachO(broken, 'mac-full-hd'), lambda *_: None), [])

    def test_explicit_supplement_retains_binding_identity(self):
        source = fixture()
        original = header(source)
        result = mesh_supplement(source, original, [17])
        self.assertEqual(result['binding_header'], original)
        self.assertIsNot(result['binding_header'], original)
        self.assertEqual(result['registrations'][0]['material_id'], 123)

    def test_duplicate_identifier_is_not_silently_selected(self):
        source = fixture(copies=2)
        rows = mac_records(MachO(source, 'mac-full-hd'), lambda *_: None)
        self.assertEqual(len(rows), 2)
        self.assertNotEqual(rows[0]['source_offset'], rows[1]['source_offset'])
        with self.assertRaisesRegex(ContentError, 'duplicate'):
            mesh_supplement(source, header(source), [17])
        with self.assertRaisesRegex(ContentError, 'distinct'):
            mesh_supplement(source, header(source), [17, 17])

    def test_supplement_refuses_foreign_source_and_missing_mapping(self):
        source = fixture()
        with self.assertRaisesRegex(ContentError, 'executable source'):
            mesh_supplement(source, header(fixture(False)), [17])
        with self.assertRaisesRegex(ContentError, 'Missing'):
            mesh_supplement(source, header(source), [18])
        changed = header(source)
        changed['binding_id'] = 'c' * 64
        with self.assertRaisesRegex(ContentError, 'identity mismatch'):
            mesh_supplement(source, changed, [17])
