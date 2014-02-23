#!/bin/sh

PRSERVFILE="$1"
if [ -e "${PRSERVFILE}" ] ; then
    cp ${PRSERVFILE} .
    . ./environment-angstrom-v2013.12
    bitbake-prserv-tool import $(basename ${PRSERVFILE})
fi
