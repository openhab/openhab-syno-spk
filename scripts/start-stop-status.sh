#!/bin/sh

#--------OPENREMOTE start-stop-status script
#--------package based on work from pcloadletter.co.uk

DAEMON_USER="`echo ${SYNOPKG_PKGNAME} | awk {'print tolower($_)'}`"
DAEMON_ID="${SYNOPKG_PKGNAME} daemon user"
ENGINE_SCRIPT="start.sh"
DAEMON_USER_SHORT=`echo ${DAEMON_USER} | cut -c 1-8`


daemon_status ()
{
  ps | grep "^ *[0-9]* ${DAEMON_USER_SHORT} .*java" > /dev/null
}

case $1 in
  start)
    DAEMON_HOME="`cat /etc/passwd | grep "${DAEMON_ID}" | cut -f6 -d':'`"
    
    #set the current timezone for Java so that log timestamps are accurate
    #we need to use the modern timezone names so that Java can figure out DST
    SYNO_TZ=`cat /etc/synoinfo.conf | grep timezone | cut -f2 -d'"'`
    SYNO_TZ=`grep "^${SYNO_TZ}" /usr/share/zoneinfo/Timezone/tzlist | sed -e "s/^.*= //"`
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
    su - ${DAEMON_USER} -s /bin/sh -c "${SYNOPKG_PKGDEST}/stop_runtime.sh"
    
    #remove DSM icon symlinks
    rm /usr/syno/synoman/webman/3rdparty/OpenHAB*
    
    exit 0
  ;;

  status)
    if daemon_status ; then
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
