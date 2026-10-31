# QNX SDP 6.5.0 build image

A Docker image for cross-compiling applications for QNX Neutrino 6.5.0 targets.
It holds only the host toolchain (`host/linux/x86`) and the target headers and
libraries (`target/qnx6`). It does not include the IDE, docs or bundled Python.

## How it works

The SDP ISO's Linux installer is an InstallShield MultiPlatform jar
(`qnx_linux_setup.jar`). `qnx650_extract.py` reads its file index and
md5-named zlib blobs directly. It checks each file's md5, restores
permissions and mtimes, and lays the files out as `/opt/qnx650` would be after
a normal install. The payload can't hold symlinks, so the build then runs the
installer's own `post_install.sh`, `post_installGPL.sh` and `qconfig-link`
scripts. These create about 490 links: tool aliases, `lib*.so → lib*.so.N`,
and `usr/include/qconfig.mk`. The `repository/*.tarx` files are encrypted and
are only used by the self-hosted (Neutrino) installer, so the extractor does
not touch them.

The host tools are 32-bit i386 Linux binaries that need only glibc, so the
runtime stage is `i386/debian:bookworm-slim`. The host kernel needs IA32
emulation, which is the default on x86_64.

## Build

```sh
docker build --build-context sdp=/mnt/iso -t qnx650-sdk .                # all CPU variants
docker build --build-context sdp=/mnt/iso \
    --build-arg TARGET_ARCHS="x86 armle-v7" -t qnx650-sdk .              # ~1.1 GB
```

This needs BuildKit (`docker buildx`). Without it, copy the jar next to
`Dockerfile.legacy` and run `docker build -f Dockerfile.legacy .`.

## Licence

`qcc`/`QCC`, and so QNX recursive make (`qrules.mk`), check
`$QNX_CONFIGURATION/license/licenses`. The image sets `QNX_CONFIGURATION=/etc/qnx`.
The `nto<arch>-gcc/g++/ld` drivers don't check it. Create the file once with:

```sh
./make-license.sh /mnt/iso XXXX-XXXX-XXXX-XXXX-XXXX ./qnx-config
```

This calls QNX's own `License.addLicense()` from `qnxlm_linux.so`, the call the
installer's key panel makes, in a 32-bit JVM container with no network access.
The key is not baked into any image.

File format (XML, one `<key>` per licence):

```xml
<?xml version="1.0" standalone="yes"?>
<qnx><licenses>
  <key>
    <license>XXXX-XXXX-XXXX-XXXX-XXXX</license>  <!-- the key; 5 bits/char, dashes ignored -->
    <check>…52 chars…</check>                     <!-- library-generated state, scrambled with the key -->
    <product-type>4</product-type>                <!-- decoded from the key -->
    <product-flags>0xe02</product-flags>
    <serial>NNNNNN</serial>
    <!-- only for keys that need activation: -->
    <activate-send>…</activate-send>              <!-- prompt key sent to QNX -->
    <activate-key>…</activate-key>                <!-- response key from QNX -->
    <!-- only for expiring keys: <expire>YYYY-MM-DDUTC</expire> -->
  </key>
</licenses></qnx>
```

You can't write `<check>` by hand. Without it the key is rejected, which is
why it has to be created by QNX's library.

A key whose flags lack `ACTIVATE` (`make-license.sh` prints `no-activation`)
doesn't need activation, and the file works in any container. A key that does
need it must then go through QNX's manual activation (`qnxactivate`, prompt
key → response key); that path has not been tested here.

## Use

```sh
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/src \
    -v "$PWD/qnx-config/license":/etc/qnx/license qnx650-sdk make
```

The licence directory must be writable, because `qcc` creates a `licenses.lck`
next to the file. If it can't, it loops forever printing `can't open file: …/licenses.lck`.

Environment set in the image: `QNX_HOST`, `QNX_TARGET`, `QNX_CONFIGURATION`,
`MAKEFLAGS=-I$QNX_TARGET/usr/include` (for recursive makefiles) and `PATH`.
For QNX recursive-make projects (`addvariant`), set `NAME`, `USEFILE` and so on
*before* `include $(MKFILES_ROOT)/qtargets.mk`, and link C++ with `LDFLAGS += -lang-c++`.
