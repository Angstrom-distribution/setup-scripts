#!/bin/sh

SHARED_DL_DIR="$1"
SHARED_SSTATE_DIR="$2"

if [ -e /usr/bin/getconf ] ; then
	NUMCPU="$(getconf _NPROCESSORS_ONLN)"
else
	NUMCPU="4"
fi

# Use more parallelism
sed -i -e "s:-j2:-j${NUMCPU}:" -e 's:THREADS = "2":THREADS = "4":' conf/local.conf

# Point to shared download dir
sed -i -e s:'${OE_SOURCE_DIR}/downloads':${SHARED_DL_DIR}: oebb.sh

if [ -e ${SHARED_DL_DIR}/../v2013.12-gits.tar.xz ] ; then
	tar xf ${SHARED_DL_DIR}/../v2013.12-gits.tar.xz
fi

# Point to shared sstate-dir
sed -i -e s:'${OE_BUILD_DIR}/build/sstate-cache':${SHARED_SSTATE_DIR}: oebb.sh

# Freescale EULA
echo 'ACCEPT_FSL_EULA = "1"' >> conf/local.conf

# Intel EMGD
echo 'LICENSE_FLAGS_WHITELIST += "license_emgd-driver-bin commercial"' >> conf/local.conf

if [ -e /usr/bin/autogen ] ; then
	echo 'ASSUME_PROVIDED += "autogen-native"' >> conf/local.conf
fi

if [ -e /usr/bin/svn ] ; then
	echo 'ASSUME_PROVIDED += "subversion-native"' >> conf/local.conf
fi

# Work around guile-native build problems
if [ "$(lsb_release -si)" = "Angstrom" ] ; then
	if [ -e /usr/bin/guile ] ; then
		echo 'ASSUME_PROVIDED += "guile-native"' >> conf/local.conf
	fi
fi
