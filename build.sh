#!/bin/bash -eux

[[ -z "${OPENHAB_VERSION:-}" ]] && echo "OPENHAB_VERSION is not set!" && exit 1
[[ -z "${SPK_VERSION:-}" ]] && echo "SPK_VERSION is not set!" && exit 1

# General
BUILD_DIR=./build
DL_DIR=./dl
PACKAGE_DIR=./package

# OpenJDK
OPENJDK_DOWNLOAD_URL_X64="https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.9.1%2B1/OpenJDK11U-jre_x64_linux_hotspot_11.0.9.1_1.tar.gz"
OPENJDK_DOWNLOAD_CHECKSUM_X64="73ce5ce03d2efb097b561ae894903cdab06b8d58fbc2697a5abe44ccd8ecc2e5"

OPENJDK_DOWNLOAD_URL_ARM32="https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.9.1%2B1/OpenJDK11U-jre_arm_linux_hotspot_11.0.9.1_1.tar.gz"
OPENJDK_DOWNLOAD_CHECKSUM_ARM32="11628830c3c912edd10b91620ef0b9566640c5ea46439f1d028f3ebd98682dbb"

# openHAB
OPENHAB_DOWNLOAD_URL="https://dl.bintray.com/openhab/mvn/org/openhab/distro/openhab/${OPENHAB_VERSION}/openhab-${OPENHAB_VERSION}.zip"
OPENHAB_DOWNLOAD_CHECKSUM="NONE"

function download_and_verify
{
    local download_url=$1
    local download_checksum=$2
    
    local download_filename="$(basename ${download_url})"
    local download_filepath="${DL_DIR}/${download_filename}"
    
    # Ensure download directory
    mkdir -p $DL_DIR

    # Download
    [[ -e "${download_filepath}" ]] || wget -nv --no-clobber --no-hsts --no-check-certificate --output-document="${download_filepath}" ${download_url}
    returncode=$?
    if [[ $returncode != 0 ]]; then
        echo " Downloading Java failed with: $returncode"
        exit 1
    fi
    
    # Verify
    if [[ ${download_checksum} != "NONE" ]]; then
        echo "${download_checksum} ${download_filepath}" | sha256sum --check --status || returncode=$?
        if [[ $returncode != 0 ]]; then
            echo " Checksum is: $(sha256sum ${download_filepath})"
            echo " Verifying Java failed with: $returncode"
            exit 1
        fi
    fi
}

function download_and_extract_tgz
{
    local download_url=$1
    local download_checksum=$2
    local download_extract_dir=$3

    local download_filename="$(basename ${download_url})"
    local download_filepath="${DL_DIR}/${download_filename}"
    local download_extract_dirpath="${PACKAGE_DIR}/${download_extract_dir}"

    # Download and verify
    download_and_verify $1 $2

    # Unpack the downloaded tgz
    mkdir -p ${download_extract_dirpath}

    tar --strip-components=1 --directory=${download_extract_dirpath} -xvzf ${download_filepath}

    returncode=$?
    if [[ $returncode != 0 ]]; then
        echo " Installation of OpenJDK with code $returncode failed."
        exit 1;
    fi
}

function download_and_extract_zip
{
    local download_url=$1
    local download_checksum=$2
    local download_extract_dir=$3

    local download_filename="$(basename ${download_url})"
    local download_filepath="${DL_DIR}/${download_filename}"
    local download_extract_dirpath="${PACKAGE_DIR}/${download_extract_dir}"

    # Download and verify
    download_and_verify $1 $2

    # Unpack the downloaded tgz
    mkdir -p ${download_extract_dirpath}

    if [ -e $(which 7z) ]; then
        7z x ${DL_DIR}/${download_filename} -o${PACKAGE_DIR}/openHAB
        returncode=$?
    else
        unzip ${DL_DIR}/${download_filename} -d ${PACKAGE_DIR}/openHAB
        returncode=$?
    fi

    returncode=$?
    if [[ $returncode != 0 ]]; then
        echo " Installation of OpenJDK with code $returncode failed."
        exit 1;
    fi
}

#############################
# Preparing build directory #
#############################

mkdir -p ${BUILD_DIR}
rm -rfv ${BUILD_DIR}/*

#########################
# Preparing package.tgz #
#########################

mkdir -p ${PACKAGE_DIR}
rm -rfv ${PACKAGE_DIR}/*

# Java X64
download_and_extract_tgz ${OPENJDK_DOWNLOAD_URL_X64} ${OPENJDK_DOWNLOAD_CHECKSUM_X64} "OpenJDK_X64"
ln -s ./OpenJDK_X64 ${PACKAGE_DIR}/OpenJDK_x86_64

# Java ARM32
download_and_extract_tgz ${OPENJDK_DOWNLOAD_URL_ARM32} ${OPENJDK_DOWNLOAD_CHECKSUM_ARM32} "OpenJDK_ARM32"
ln -s ./OpenJDK_X64 ${PACKAGE_DIR}/OpenJDK_armv5tel

# Downloading openHAB
download_and_extract_zip ${OPENHAB_DOWNLOAD_URL} "NONE" "openHAB"

# Adding little UI
cp -rf ./ui ${PACKAGE_DIR}

# Adding helper script(s)
cp -rf ./helper ${PACKAGE_DIR}

tar --directory=${PACKAGE_DIR} \
    --file=${BUILD_DIR}/package.tgz \
    -czv \
    .

rm -rfv ${PACKAGE_DIR}

#######################
# Preparing final SPK #
#######################

cp -rfv \
    conf \
    scripts \
    WIZARD_UIFILES \
    INFO \
    LICENSE \
    NOTICE \
    PACKAGE_ICON*.PNG \
    ${BUILD_DIR}

FILE_NAME=openHAB-${OPENHAB_VERSION}-syno-noarch-${SPK_VERSION}.spk
echo ${FILE_NAME}

rm -f ${FILE_NAME}

tar cf ${FILE_NAME} \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    conf \
    scripts \
    package.tgz \
    INFO \
    LICENSE \
    NOTICE \
    PACKAGE_ICON_120.PNG \
    PACKAGE_ICON.PNG \
    WIZARD_UIFILES
