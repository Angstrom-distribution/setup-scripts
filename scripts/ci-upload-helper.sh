#!/bin/sh

HOST="$1"
nightlydir="$2"

# create directory on remote machines
ssh ${HOST} "mkdir -p ${nightlydir}"

mkdir -p deploy/glibc/images

# Compress raw images and extX files if needed
for i in $(find deploy/glibc/images/ -name "A*.ext3"; find deploy/glibc/images/ -name "A*img" ; find deploy/glibc/images/ -name "A*.ext2" ; find deploy/glibc/images/ -name "A*.ext4" ; find deploy/glibc/images/ -name "A*sdcard" ; find deploy/glibc/images/ -name "A*iso") ; do xz -f -v -z -T0 -9 -e $i ; done

# Clean up broken symlinks
find deploy/glibc/images/ -type l -exec sh -c "file -b {} | grep -q ^broken" \; -print | xargs rm || true

# Copy over images/kernels/modules/etc
rsync -l deploy/glibc/images/$machine/* ${HOST}:${nightlydir}
