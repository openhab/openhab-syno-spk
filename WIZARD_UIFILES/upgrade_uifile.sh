#!/bin/bash -eux

SYNOPKG_PKGDEST_OPENHAB_ENV="${SYNOPKG_PKGDEST}/${SYNOPKG_PKGNAME}.env"

[[ -f ${SYNOPKG_PKGDEST_OPENHAB_ENV} ]] && source ${SYNOPKG_PKGDEST_OPENHAB_ENV}

cat `dirname $0`/upgrade_uifile.in \
    | sed -e "s/%OPENHAB_HTTP_ADDRESS%/${OPENHAB_HTTP_ADDRESS:-0.0.0.0}/g" \
    | sed -e "s/%OPENHAB_HTTP_ADDRESS_DEFAULT%/0.0.0.0/g" \
    | sed -e "s/%OPENHAB_HTTP_PORT%/${OPENHAB_HTTP_PORT:-8080}/g" \
    | sed -e "s/%OPENHAB_HTTP_PORT_DEFAULT%/8080/g" \
    | sed -e "s/%OPENHAB_HTTPS_PORT%/${OPENHAB_HTTPS_PORT:-8443}/g" \
    | sed -e "s/%OPENHAB_HTTPS_PORT_DEFAULT%/8443/g" \
    > `dirname $0`/upgrade_uifile

cat `dirname $0`/upgrade_uifile

exit 0
