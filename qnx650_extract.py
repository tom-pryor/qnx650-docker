#!/usr/bin/env python3
"""Extract the QNX SDP 6.5.0 host toolchain + target files from the
InstallShield MultiPlatform payload (qnx_linux_setup.jar) without running
the installer.

Layout of the jar:
  <wizard-id>/index        - 21 zlib chunks of fixed-format file records
  <wizard-id>/md5/<hash>   - zlib-compressed file contents, named by md5

Usage: qnx650_extract.py qnx_linux_setup.jar OUTDIR [--with-ide] [--with-docs]
OUTDIR becomes the equivalent of /opt/qnx650.
"""
import hashlib, os, struct, sys, zipfile, zlib

EMPTY = "d41d8cd98f00b204e9800998ecf8427e"

# index path prefix -> install path prefix (relative to base dir)
PREFIXES = [
    ("x86/", "host/linux/x86/"),
    ("qnx6/", "target/qnx6/"),
    ("qnxsdp/", "install/qnxsdp/"),  # metadata incl. post_install.sh, qconfig-link
]

def records(index):
    ver, n = struct.unpack(">II", index[:8])
    o = 8
    for _ in range(n):
        clen, = struct.unpack(">I", index[o:o+4]); o += 4
        c = zlib.decompress(index[o:o+clen]); o += clen
        cnt, = struct.unpack(">I", c[:4]); p = 4
        for _ in range(cnt):
            md5 = c[p+4:p+20].hex()
            pl, = struct.unpack(">H", c[p+20:p+22])
            path = c[p+22:p+22+pl].decode("utf-8"); p += 22 + pl
            _typ, size, _a, _b, _c, attr, _z, mtime = struct.unpack(">IqIIHIIq", c[p:p+38])
            p += 38 + 1 + 6
            yield path, md5, size, attr, mtime // 1000

def unix_mode(attr):
    # attr is written as octal digits (other, group, owner) with r=1 w=2 x=4
    mode = 0
    for shift, digit in ((0, (attr >> 6) & 7), (3, (attr >> 3) & 7), (6, attr & 7)):
        bits = (4 if digit & 1 else 0) | (2 if digit & 2 else 0) | (1 if digit & 4 else 0)
        mode |= bits << shift
    return mode | 0o200  # keep owner-writable so the tree can be cleaned up

def wanted(path, with_ide, with_docs):
    if not with_ide and path.startswith(("x86/usr/qde/", "x86/unsupported/")):
        return False
    if not with_docs and path.startswith("qnx6/usr/help/"):
        return False
    return any(path.startswith(src) or path + "/" == src for src, _ in PREFIXES)

def dest(path):
    for src, dst in PREFIXES:
        if path + "/" == src:
            return dst.rstrip("/")
        if path.startswith(src):
            return dst + path[len(src):]

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    with_ide, with_docs = "--with-ide" in sys.argv, "--with-docs" in sys.argv
    jar_path, outdir = args
    jar = zipfile.ZipFile(jar_path)
    wiz = next(n.split("/")[0] for n in jar.namelist() if n.endswith("/index"))
    dirs, nfiles, nbytes = [], 0, 0
    for path, md5, size, attr, mtime in records(jar.read(f"{wiz}/index")):
        if not wanted(path, with_ide, with_docs):
            continue
        out = os.path.join(outdir, dest(path))
        if attr & 0o10000:
            os.makedirs(out, exist_ok=True)
            dirs.append((out, mtime))
            continue
        os.makedirs(os.path.dirname(out), exist_ok=True)
        data = b"" if md5 == EMPTY else zlib.decompress(jar.read(f"{wiz}/md5/{md5}"))
        if hashlib.md5(data).hexdigest() != md5 or len(data) != size:
            sys.exit(f"checksum/size mismatch: {path}")
        with open(out, "wb") as f:
            f.write(data)
        os.chmod(out, unix_mode(attr))
        os.utime(out, (mtime, mtime))
        nfiles += 1; nbytes += size
    for d, mtime in reversed(dirs):
        os.utime(d, (mtime, mtime))
    print(f"extracted {nfiles} files, {nbytes/2**20:.0f} MiB -> {outdir}")

if __name__ == "__main__":
    main()
