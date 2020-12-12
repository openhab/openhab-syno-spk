#!/bin/bash -eux

[[ -z "${OPENHAB_VERSION:-}" ]] && echo "OPENHAB_VERSION is not set!" && exit 1

FILE_NAME=openHAB-${OPENHAB_VERSION}-syno-noarch-0.001.spk
echo ${FILE_NAME}

rm -f ${FILE_NAME}

tar cf ${FILE_NAME} \
    --exclude=.git* \
    --exclude=\*.md \
    --exclude=.travis.\* \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    *
