#!/bin/sh

#--------OPENREMOTE start-stop-status script
#--------package based on work from pcloadletter.co.uk

DAEMON_USER="`echo ${SYNOPKG_PKGNAME} | awk {'print tolower($_)'}`"
DAEMON_ID="${SYNOPKG_PKGNAME} daemon user"
ENGINE_SCRIPT="start.sh"
DAEMON_USER_SHORT=`echo ${DAEMON_USER} | cut -c 1-8`
PIDFILE="/var/services/homes/${DAEMON_USER}/.daemon.pid"

daemon_status ()
{
  ps | grep "^ *[0-9]* ${DAEMON_USER_SHORT} .*java" > /dev/null
}

case $1 in
  start)
    #Are the port already used?
    if netstat -tlpn | grep ${SYNOPKG_PKGPORT}; then
      echo "Port ${SYNOPKG_PKGPORT} already in use."
      exit 1
    fi

    DAEMON_HOME="`cat /etc/passwd | grep "${DAEMON_ID}" | cut -f6 -d':'`"
    
    #set the current timezone for Java so that log timestamps are accurate
    #we need to use the modern timezone names so that Java can figure out DST
    if [ -n "$SYNOPKG_DSM_VERSION_MAJOR" -a $SYNOPKG_DSM_VERSION_MAJOR -ge 6 ]; then
      SYNO_TZ=$(cat /etc/synoinfo.conf | grep timezone | cut -f2 -d'"')
    else
      [ -e /usr/share/zoneinfo/Timezone/synotztable.json ] \
      && SYNO_TZ=$(jq ".${SYNO_TZ} | .nameInTZDB" /usr/share/zoneinfo/Timezone/synotztable.json | sed -e "s/\"//g") \
      || SYNO_TZ=$(grep "^${SYNO_TZ}" /usr/share/zoneinfo/Timezone/tzname | sed -e "s/^.*= //")
    fi  
    grep "^export TZ" ${DAEMON_HOME}/.profile > /dev/null \
     && sed -i "s%^export TZ=.*$%export TZ='${SYNO_TZ}'%" ${DAEMON_HOME}/.profile \
     || echo export TZ=\'${SYNO_TZ}\' >> ${DAEMON_HOME}/.profile
    
    #start OpenHAB runtime in background mode
    su - ${DAEMON_USER} -s /bin/sh -c "cd ${SYNOPKG_PKGDEST} && ./${ENGINE_SCRIPT} &"
  
    #set up symlinks for the DSM GUI
#    if [ -d /usr/syno/synoman/webman/3rdparty ]; then
#      ln -s ${SYNOPKG_PKGDEST}/DSM/OpenHAB /usr/syno/synoman/webman/3rdparty/OpenHAB
#    fi
  
    exit 0
  ;;

  stop)
    if su - ${DAEMON_USER} -s /bin/sh -c "cd ${SYNOPKG_PKGDEST}/runtime/bin && ./stop &"
    then
      rm -f $PIDFILE
    fi
    
    #remove DSM icon symlinks
#    rm /usr/syno/synoman/webman/3rdparty/OpenHAB*
    
    exit 0
  ;;

  status)
    [ ! -f "$PIDFILE" ] && return 1
    if ps -p $(cat "$PIDFILE") > /dev/null; then
      exit 0
    else
      exit 1
    fi
  ;;

  log)
    echo "${SYNOPKG_PKGDEST}/userdata/logs/openhab.log"
    exit 0
  ;;
esac
