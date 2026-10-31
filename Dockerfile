# syntax=docker/dockerfile:1
# check=skip=FromPlatformFlagConstDisallowed
#
# QNX SDP 6.5.0 cross-compilation image (applications only, no IDE / BSPs).
#
# Build (the ISO is passed as a named build context so the 720 MB jar is
# read in place rather than copied into the build context):
#
#   docker build --build-context sdp=/mnt/iso -t qnx650-sdk .
#
# Optionally restrict target CPU variants to save space (~140 MB each):
#
#   docker build --build-context sdp=/mnt/iso \
#       --build-arg TARGET_ARCHS="x86 armle-v7" -t qnx650-sdk .

FROM python:3.12-slim AS extract
ARG TARGET_ARCHS="x86 armle armle-v7 mipsbe mipsle ppcbe ppcbe-spe shle"
COPY qnx650_extract.py /usr/local/bin/
RUN --mount=type=bind,from=sdp,source=qnx_linux_setup.jar,target=/sdp.jar \
    python3 -I /usr/local/bin/qnx650_extract.py /sdp.jar /opt/qnx650
# The installer payload cannot hold symlinks; the installer recreates them
# (tool aliases, lib*.so -> lib*.so.N, qconfig.mk) with these scripts.
RUN cd /opt/qnx650/install/qnxsdp/6.5.0 \
 && for s in post_install.sh post_installGPL.sh qconfig-link; do sh "$s" /opt/qnx650; done \
 && cd /opt/qnx650/target/qnx6 \
 && for d in armle armle-v7 mipsbe mipsle ppcbe ppcbe-spe shle x86; do \
        case " $TARGET_ARCHS " in *" $d "*) ;; *) rm -rf "$d" ;; esac; \
    done \
 && find /opt/qnx650 -xtype l -delete \
 && find /opt/qnx650/host/linux/x86/unsupported /opt/qnx650/host/linux/x86/usr/qde \
        -depth -type d -empty -delete 2>/dev/null || true

# The SDP host tools are 32-bit i386 Linux binaries (glibc only), so a native
# i386 userland is the simplest base (pinned to linux/386 on purpose). Runs on
# any x86_64 host kernel with IA32 emulation enabled.
FROM --platform=linux/386 i386/debian:bookworm-slim
COPY --from=extract /opt/qnx650 /opt/qnx650

ENV QNX_HOST=/opt/qnx650/host/linux/x86 \
    QNX_TARGET=/opt/qnx650/target/qnx6 \
    QNX_CONFIGURATION=/etc/qnx \
    MAKEFLAGS=-I/opt/qnx650/target/qnx6/usr/include \
    PATH=/opt/qnx650/host/linux/x86/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# qcc reads $QNX_CONFIGURATION/license/licenses and must be able to create a
# lock file beside it. Mount a directory holding your licenses file here at
# run time (see README / make-license.sh); no key is baked into the image.
RUN mkdir -p /etc/qnx/license && chmod 1777 /etc/qnx/license

WORKDIR /src
