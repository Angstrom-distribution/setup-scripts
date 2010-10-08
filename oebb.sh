#!/bin/bash

# Original script done by Don Darling
# Later changes by Koen Kooi and Brijesh Singh

# Revision history:
# 20090902: download from twice
# 20090903: Weakly assign MACHINE and DISTRO
# 20090904:  * Don't recreate local.conf is it already exists
#            * Pass 'unknown' machines to OE directly
# 20090918: Fix /bin/env location
#           Don't pass MACHINE via env if it's not set
#           Changed 'build' to 'bitbake' to prepare people for non-scripted usage
#           Print bitbake command it executes
# 20091012: Add argument to accept commit id.
# 20091202: Fix proxy setup
#
# For further changes consult 'git log' or browse to:
#   http://gitorious.org/angstrom/angstrom-setup-scripts/commits
# to see the latest revision history

###############################################################################
# User specific vars like proxy servers
###############################################################################

#PROXYHOST=wwwgate.ti.com
#PROXYPORT=80
PROXYHOST=""

###############################################################################
# OE_BASE    - The root directory for all OE sources and development.
###############################################################################
OE_BASE=${PWD}

#--------------------------------------------------------------------------
# Check if this script was cloned from http://gitorious.org/angstrom/angstrom-setup-scripts or not
#--------------------------------------------------------------------------

if [ -e ${OE_BASE}/.gitmodules ] ; then
    USE_SUBMODULES="sort-of-true"
fi

###############################################################################
# SET_ENVIRONMENT() - Setup environment variables for OE development
###############################################################################
function set_environment()
{

#--------------------------------------------------------------------------
# If an env already exists, use it, otherwise generate it
#--------------------------------------------------------------------------
if [ -e ~/.oe/environment ] ; then
    . ~/.oe/environment
else

    mkdir -p ~/.oe/

    #--------------------------------------------------------------------------
    # Specify distribution information
    #--------------------------------------------------------------------------
    DISTRO="angstrom-2008.1"
    DISTRO_DIRNAME=`echo $DISTRO | sed s#[.-]#_#g`

    echo "export DISTRO=\"${DISTRO}\"" > ~/.oe/environment
    echo "export DISTRO_DIRNAME=\"${DISTRO_DIRNAME}\"" >> ~/.oe/environment

    #--------------------------------------------------------------------------
    # Specify the root directory for your OpenEmbedded development
    #--------------------------------------------------------------------------
    OE_BUILD_DIR=${OE_BASE}/build
    OE_BUILD_TMPDIR="${OE_BUILD_DIR}/tmp-${DISTRO_DIRNAME}"
    OE_SOURCE_DIR=${OE_BASE}/sources

    mkdir -p ${OE_BUILD_DIR}
    mkdir -p ${OE_SOURCE_DIR}
    export OE_BASE

    echo "export OE_BUILD_DIR=\"${OE_BUILD_DIR}\"" >> ~/.oe/environment
    echo "export OE_BUILD_TMPDIR=\"${OE_BUILD_TMPDIR}\"" >> ~/.oe/environment
    echo "export OE_SOURCE_DIR=\"${OE_SOURCE_DIR}\"" >> ~/.oe/environment

    echo "export OE_BASE=\"${OE_BASE}\"" >> ~/.oe/environment

    #--------------------------------------------------------------------------
    # Include up-to-date bitbake in our PATH.
    #--------------------------------------------------------------------------
    export PATH=${OE_SOURCE_DIR}/bitbake/bin:${PATH}

    echo "export PATH=\"${PATH}\"" >> ~/.oe/environment

    #--------------------------------------------------------------------------
    # Make sure Bitbake doesn't filter out the following variables from our
    # environment.
    #--------------------------------------------------------------------------
    export BB_ENV_EXTRAWHITE="MACHINE DISTRO GIT_PROXY_COMMAND ANGSTROMLIBC"

    echo "export BB_ENV_EXTRAWHITE=\"${BB_ENV_EXTRAWHITE}\"" >> ~/.oe/environment

    #--------------------------------------------------------------------------
    # Specify proxy information
    #--------------------------------------------------------------------------
    if [ "x$PROXYHOST" != "x"  ] ; then
        export http_proxy=http://${PROXYHOST}:${PROXYPORT}/
        export ftp_proxy=http://${PROXYHOST}:${PROXYPORT}/

        export SVN_CONFIG_DIR=${OE_BUILD_DIR}/subversion_config
        export GIT_CONFIG_DIR=${OE_BUILD_DIR}/git_config

        echo "export http_proxy=\"${http_proxy}\"" >> ~/.oe/environment
        echo "export ftp_proxy=\"${ftp_proxy}\"" >> ~/.oe/environment
        echo "export SVN_CONFIG_DIR=\"${SVN_CONFIG_DIR}\"" >> ~/.oe/environment
        echo "export GIT_CONFIG_DIR=\"${GIT_CONFIG_DIR}\"" >> ~/.oe/environment

        config_svn_proxy
        config_git_proxy
    fi

    #--------------------------------------------------------------------------
    # Set up the bitbake path to find the OpenEmbedded recipes.
    #--------------------------------------------------------------------------
    export BBPATH=${OE_BUILD_DIR}:${OE_SOURCE_DIR}/openembedded${BBPATH_EXTRA}

    echo "export BBPATH=\"${BBPATH}\"" >> ~/.oe/environment

    #--------------------------------------------------------------------------
    # Reconfigure dash
    #--------------------------------------------------------------------------
    if [ $(readlink /bin/sh) = "dash" ] ; then
        sudo aptitude install expect -y
        expect -c 'spawn sudo dpkg-reconfigure -freadline dash; send "n\n"; interact;'
    fi

    echo "There now is a sourceable script in ~/.oe/enviroment. You can do '. ~/.oe/environment' and run 'bitbake something' without using $0 as wrapper"
fi # if -e ~/.oe/environment
}


###############################################################################
# UPDATE_ALL() - Make sure everything is up to date
###############################################################################
function update_all()
{
    set_environment
    update_bitbake
    update_oe
}

###############################################################################
# CLEAN_OE() - Delete TMPDIR
###############################################################################
function clean_oe()
{
    set_environment
    echo "Cleaning ${OE_BUILD_TMPDIR}"
    rm -rf ${OE_BUILD_TMPDIR}
}


###############################################################################
# OE_BUILD() - Build an OE package or image
###############################################################################
function oe_build()
{
    set_environment
    if [ -e ~/.oe/environment ] ; then
        echo "Using ~/.oe/environment to setup needed variables. It is recommended to do '. ~/.oe/environment' and run 'bitbake something' without using $0 as wrapper"
    fi
    cd ${OE_BUILD_DIR}
    if [ -z $MACHINE ] ; then
        echo "Executing: bitbake" $*
        bitbake $*
    else
        echo "Executing: MACHINE=${MACHINE} bitbake" $*
        MACHINE=${MACHINE} bitbake $*
    fi
}


###############################################################################
# OE_CONFIG() - Configure OE for a target
###############################################################################
function oe_config()
{
    set_environment
    config_oe

    echo ""
    echo "Setup for ${CL_MACHINE} completed"
}


###############################################################################
# UPDATE_BITBAKE() - Update Bitbake distribution
###############################################################################
function update_bitbake()
{
    if [ "x$PROXYHOST" != "x" ] ; then
        config_git_proxy
    fi

    if [ "USE_SUBMODULES" = "true" ] ; then
        echo "Updating bitbake submodule"
        git submodule update --init ${OE_SOURCE_DIR}/bitbake
    else
        if [ ! -d ${OE_SOURCE_DIR}/bitbake/bin ]; then
            rm -rf  ${OE_SOURCE_DIR}/bitbake
            echo Checking out bitbake
            git clone git://git.openembedded.org/bitbake ${OE_SOURCE_DIR}/bitbake
            cd ${OE_SOURCE_DIR}/bitbake && git checkout -b 1.10 origin/1.10
        else
            echo "Updating bitbake"
            echo "Executing: cd ${OE_SOURCE_DIR}/bitbake && git pull --rebase"
            cd ${OE_SOURCE_DIR}/bitbake && git pull --rebase
        fi
    fi
}


###############################################################################
# UPDATE_OE() - Update OpenEmbedded distribution.
###############################################################################
function update_oe()
{
    if [ "x$PROXYHOST" != "x" ] ; then
        config_git_proxy
    fi

    if [ "USE_SUBMODULES" = "true" ] ; then
        echo "Updating OE submodule"
        git submodule update --init ${OE_SOURCE_DIR}/openembedded
    else
        if [ ! -d  ${OE_SOURCE_DIR}/openembedded/conf ]; then
            rm -rf  ${OE_SOURCE_DIR}/openembedded/
            echo Checking out OpenEmbedded
            git clone "git://git.openembedded.org/openembedded" ${OE_SOURCE_DIR}/openembedded
            cd ${OE_SOURCE_DIR}/openembedded
            if [ ! -r ${OE_COMMIT_ID} ];
            then
                echo "Checkout commit id: ${OE_COMMIT_ID}"
                git checkout -b install ${OE_COMMIT_ID}
            else
                echo "Checking out OE, depending on your git version you might get a harmless, what git alarmingly calls 'fatal' error. It just means the branch already exists."
                git checkout -b org.openembedded.dev origin/org.openembedded.dev || true
            fi
        else
            echo Updating OpenEmbedded
            cd ${OE_SOURCE_DIR}/openembedded
            if [ ! -r ${OE_COMMIT_ID} ];
            then
                echo "Checkout commit id: ${OE_COMMIT_ID}"
                git remote update origin
                git checkout ${OE_COMMIT_ID}
                git checkout -b install
            else
                echo "Executing: git pull --rebase"
                git pull --rebase
            fi
        fi
    fi
}


###############################################################################
# CONFIG_OE() - Configure OpenEmbedded
###############################################################################
function config_oe()
{
    #--------------------------------------------------------------------------
    # Determine the proper machine name
    #--------------------------------------------------------------------------
    case ${CL_MACHINE} in
        beagle|beagleboard)
            MACHINE="beagleboard"
            ;;
        dm6446evm|davinci-evm)
            MACHINE="davinci-dvevm"
            ;;
        omap3evm)
            MACHINE="omap3evm"
            ;;
        shiva|omap3517-evm)
            MACHINE="omap3517-evm"
            ;;
        *)
            echo "Unknown machine ${CL_MACHINE}, passing it to OE directly"
            MACHINE="${CL_MACHINE}"
            ;;
    esac

    #--------------------------------------------------------------------------
    # Write out the OE bitbake configuration file.
    #--------------------------------------------------------------------------
    mkdir -p ${OE_BUILD_DIR}/conf

    if [ ! -e ${OE_BUILD_DIR}/conf/bblayers.conf ]; then
	cat > ${OE_BUILD_DIR}/conf/bblayers.conf <<_EOF
# LAYER_CONF_VERSION is increased each time build/conf/bblayers.conf
# changes incompatibly
LCONF_VERSION = "1"

BBFILES ?= ""
BBLAYERS = " \
  ${OE_SOURCE_DIR}/openembedded \
  ${OE_SOURCE_DIR}/meta-marmita \
  "
_EOF
    fi

    # There's no need to rewrite local.conf when changing MACHINE
    if [ ! -e ${OE_BUILD_DIR}/conf/local.conf ]; then
        cat > ${OE_BUILD_DIR}/conf/local.conf <<_EOF
# Where to store sources
DL_DIR = "${OE_SOURCE_DIR}/downloads"

INHERIT += "rm_work"

# Which files do we want to parse:
BBMASK = ""

# Qemu 0.12.x is giving too much problems recently (2010.05), so disable it for users
ENABLE_BINARY_LOCALE_GENERATION = "0"

# What kind of images do we want?
IMAGE_FSTYPES += "tar.bz2"

# Make use of SMP:
#   PARALLEL_MAKE specifies how many concurrent compiler threads are spawned per bitbake process
#   BB_NUMBER_THREADS specifies how many concurrent bitbake tasks will be run
#PARALLEL_MAKE     = "-j2"
BB_NUMBER_THREADS = "2"

DISTRO   = "${DISTRO}"
MACHINE ?= "${MACHINE}"

# Set TMPDIR instead of defaulting it to $pwd/tmp
TMPDIR = "${OE_BUILD_TMPDIR}"

# Don't generate the mirror tarball for SCM repos, the snapshot is enough
BB_GENERATE_MIRROR_TARBALLS = "0"

# Go through the Firewall
#HTTP_PROXY        = "http://${PROXYHOST}:${PROXYPORT}/"

_EOF
fi
}

###############################################################################
# CONFIG_SVN_PROXY() - Configure subversion proxy information
###############################################################################
function config_svn_proxy()
{
    if [ ! -f ${SVN_CONFIG_DIR}/servers ]
    then
        mkdir -p ${SVN_CONFIG_DIR}
        cat >> ${SVN_CONFIG_DIR}/servers <<_EOF
[global]
http-proxy-host = ${PROXYHOST}
http-proxy-port = ${PROXYPORT}
_EOF
    fi
}


###############################################################################
# CONFIG_GIT_PROXY() - Configure GIT proxy information
###############################################################################
function config_git_proxy()
{
    if [ ! -f ${GIT_CONFIG_DIR}/git-proxy.sh ]
    then
        mkdir -p ${GIT_CONFIG_DIR}
        cat > ${GIT_CONFIG_DIR}/git-proxy.sh <<_EOF
if [ -x /bin/env ] ; then
    exec /bin/env corkscrew ${PROXYHOST} ${PROXYPORT} \$*
else
    exec /usr/bin/env corkscrew ${PROXYHOST} ${PROXYPORT} \$*
fi
_EOF
        chmod +x ${GIT_CONFIG_DIR}/git-proxy.sh
        export GIT_PROXY_COMMAND=${GIT_CONFIG_DIR}/git-proxy.sh
        echo "export GIT_PROXY_COMMAND=\"\${GIT_CONFIG_DIR}/git-proxy.sh\"" >> ~/.oe/environment
    fi
}


###############################################################################
# Build the specified OE packages or images.
###############################################################################

# FIXME: convert to case/esac

if [ $# -gt 0 ]
then
    if [ $1 = "update" ]
    then
        shift
        if [ ! -r $1 ]; then
            if [  $1 == "commit" ]
            then
                shift
                OE_COMMIT_ID=$1
            fi
        fi
        update_all
        exit 0
    fi

    if [ $1 = "bitbake" ]
    then
        shift
        oe_build $*
        exit 0
    fi

    if [ $1 = "config" ]
    then
        shift
        CL_MACHINE=$1
        shift
        oe_config $*
        exit 0
    fi

    if [ $1 = "clean" ]
    then
        clean_oe
        exit 0
    fi
fi

# Help Screen
echo ""
echo "Usage: $0 config <machine>"
echo "       $0 update"
echo ""
echo "       Not recommended, but also possible:"
echo "       $0 bitbake <bitbake target>"
echo "       It is recommended to do '. ~/.oe/environment' and run 'bitbake something' without using oebb.sh as wrapper"
echo ""
echo "You must invoke \"$0 config <machine>\" and then \"$0 update\" prior"
echo "to your first bitbake command"
echo ""
echo "The <machine> argument can be one of the following"
echo "       beagleboard:    BeagleBoard"
echo "       davinci-evm:    DM6446 EVM"
echo "       omap3evm:       OMAP35x EVM"
echo "       am3517-evm:     AM3517 (Shiva) EVM"
echo ""
echo "Other machines are valid as well, but listing those would make this message way too long"
