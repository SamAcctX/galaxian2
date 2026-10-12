"""Unpack KiritoJPK's Android release into a private stage, without running anything.

The source is the release's .xapk, or the GOF2FHD_XAPK.7z that holds it. Only
the expansion file (OBB) and the game APK are copied out, by streaming the
XAPK's ZIP records once; 7-Zip writes the XAPK to a pipe, never to disk. The
stage is removed on exit, whether the import finished, failed or was cancelled.
"""
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import tempfile
import zlib

from .dmg import HEADROOM, MAX_LISTING, seven_zip
from .formats import ContentError

PACKAGE = 'net.fishlabs.gof2hdallandroid2012'
OBB = re.compile(r'Android/obb/' + re.escape(PACKAGE) + r'/(main\.[0-9]{1,10}\.' + re.escape(PACKAGE) + r'\.obb)')
APK = PACKAGE + '.apk'
MAX_OBB = 4 * 1024 * 1024 * 1024
MAX_APK = 256 * 1024 * 1024
MAX_XAPK = 6 * 1024 * 1024 * 1024
CHUNK = 1024 * 1024


def read_exact(stream, size):
    data = stream.read(size)
    if len(data) != size:
        raise ContentError('The Android release archive is truncated')
    return data


def unpack_xapk(stream, stage, checkpoint):
    """Copy the OBB and the game APK out of an XAPK ZIP stream; return their paths."""
    found = {}
    total = 0
    while True:  # every local record, so a second OBB or APK cannot hide behind the first
        signature = stream.read(4)
        if signature != b'PK\x03\x04':
            break  # Central directory or end: no more local records.
        _, flags, method, _, _, crc, packed, size, name_length, extra_length = struct.unpack(
            '<HHHHHIIIHH', read_exact(stream, 26))
        name = read_exact(stream, name_length).decode('utf-8', errors='replace')
        read_exact(stream, extra_length)
        if flags & 0x9:
            raise ContentError('Unsupported encrypted or streamed XAPK entry: ' + name)
        total += packed
        if total > MAX_XAPK:
            raise ContentError('The XAPK exceeds the import size limit')
        match = OBB.fullmatch(name)
        target = match[1] if match else 'game.apk' if name == APK else None
        if target is None:
            for done in range(0, packed, CHUNK):
                read_exact(stream, min(CHUNK, packed - done))
            continue
        if size > (MAX_OBB if match else MAX_APK) or method not in (0, 8):
            raise ContentError('Unsupported XAPK entry: ' + name)
        if any(n.endswith('.obb') for n in found) if match else 'game.apk' in found:
            raise ContentError('The XAPK holds more than one game expansion or APK')
        path = stage / target
        inflater = zlib.decompressobj(-15) if method == 8 else None
        written, check = 0, 0
        with path.open('xb') as output:
            left = packed
            while left:
                block = read_exact(stream, min(CHUNK, left))
                left -= len(block)
                if inflater:
                    try:
                        block = inflater.decompress(block)
                    except zlib.error as error:
                        raise ContentError('An XAPK entry is damaged: ' + name) from error
                written += len(block)
                if written > size:
                    raise ContentError('An XAPK entry is larger than declared: ' + name)
                check = zlib.crc32(block, check)
                output.write(block)
                checkpoint('Unpacking the Android release', written / max(size, 1))
            if inflater:
                tail = inflater.flush()
                written += len(tail)
                check = zlib.crc32(tail, check)
                output.write(tail)
                if not inflater.eof:
                    raise ContentError('An XAPK entry is truncated: ' + name)
        if written != size or check != crc:
            raise ContentError('An XAPK entry does not match its checksum: ' + name)
        found[target] = path
    obb = [p for n, p in found.items() if n.endswith('.obb')]
    if len(obb) != 1 or 'game.apk' not in found:
        raise ContentError('Choose KiritoJPK\'s Galaxy on Fire 2 HD .xapk (it holds the game APK and its OBB)')
    return found['game.apk'], obb[0]


class AndroidRelease:
    """Context manager: the unpacked stage directory (game.apk + main.*.obb)."""

    def __init__(self, source, checkpoint=lambda *_: None, work=None):
        self.source = Path(source).absolute()
        self.checkpoint = checkpoint
        self.work = work
        self.stage = None

    def __enter__(self):
        try:
            return self.extract()
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, *_):
        if self.stage is not None:
            self.stage.cleanup()
            self.stage = None

    def extract(self):
        suffix = self.source.suffix.lower()
        if suffix not in ('.xapk', '.7z') or self.source.is_symlink() or not self.source.is_file():
            raise ContentError('Choose the Android release .xapk or its GOF2FHD_XAPK.7z')
        size = self.source.stat().st_size
        self.stage = tempfile.TemporaryDirectory(prefix='gof2-android-', dir=self.work)
        root = Path(self.stage.name) / 'android'
        root.mkdir()
        # The OBB, the base content and the decoded textures coexist until activation.
        if shutil.disk_usage(root).free < size * 3 + HEADROOM:
            raise ContentError('Import needs more free storage for the Android release; keep at least '
                               + str((size * 3 + HEADROOM + 1024**3 - 1) // 1024**3) + ' GiB available')
        if suffix == '.xapk':
            with self.source.open('rb') as stream:
                unpack_xapk(stream, root, self.checkpoint)
        else:
            self.unpack_7z(root)
        self.checkpoint('Android release unpacked', 1.0)
        return root

    def unpack_7z(self, root):
        tool = seven_zip('The Android importer')
        listing = subprocess.run([tool, 'l', '-slt', '-ba', '-sccUTF-8', '-p-', '--', str(self.source)],
                                 stdin=subprocess.DEVNULL, capture_output=True, timeout=600)
        if listing.returncode or len(listing.stdout) > MAX_LISTING:
            raise ContentError('Could not read this .7z archive')
        names = re.findall(r'^Path = (.+)$', listing.stdout.decode('utf-8', errors='replace').replace('\r\n', '\n'), re.M)
        xapks = [n for n in names if n.lower().endswith('.xapk') and PurePosixPath(n.replace('\\', '/')).name == n]
        if len(xapks) != 1:
            raise ContentError('The .7z must hold exactly one Android .xapk (GOF2FHD_XAPK.7z)')
        child = subprocess.Popen([tool, 'e', '-so', '-p-', '-bd', '--', str(self.source), xapks[0]],
                                 stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        try:
            unpack_xapk(child.stdout, root, self.checkpoint)
        finally:
            child.stdout.close()
            if child.poll() is None:
                child.terminate()
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill(); child.wait()
