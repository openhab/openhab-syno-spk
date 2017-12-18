#!/bin/sh

#--------openHAB start-stop-status script
#--------package based on work from pcloadletter.co.uk

DNAME="openHAB"
DAEMON_USER="$(echo ${SYNOPKG_PKGNAME} | awk {'print tolower($_)'})"
DAEMON_ID="${SYNOPKG_PKGNAME} daemon user"
ENGINE_SCRIPT="start.sh daemon"
PIDFILE="/var/services/homes/${DAEMON_USER}/.daemon.pid"
LOG="/var/log/${SYNOPKG_PKGNAME}-start_stop.log"
# Delete Log if older than 1 day
find ${LOG} -mtime +1 -type f -delete

daemon_status ()
{
  OHDAEMON_RUNNING=0
  if [ -n "$SYNOPKG_DSM_VERSION_MAJOR" -a $SYNOPKG_DSM_VERSION_MAJOR -ge 6 ]; then
    if [ -f ${PIDFILE} ] && ps -p $(cat "$PIDFILE") > /dev/null; then
      OHDAEMON_RUNNING=1
    fi
  else
    if [ -f ${PIDFILE} ] && ps | grep "^$(cat $PIDFILE)" > /dev/null; then
      OHDAEMON_RUNNING=1
    fi
  fi
  [ ${OHDAEMON_RUNNING} -eq 1 ] || return 1
}

stop_daemon ()
{
  su - ${DAEMON_USER} -s /bin/sh -c "cd ${SYNOPKG_PKGDEST}/runtime/bin && ./stop &"
  wait_for_status 1 20
  if [ $? -eq 1 ]; then
    echo "  stop_daemon: kill service" >>$LOG
    kill -9 $(cat ${PIDFILE})
  fi
  rm -f ${PIDFILE}
}

wait_for_status ()
{
  counter=$2
  while [ ${counter} -gt 0 ]; do
    daemon_status
    [ $? -eq $1 ] && return
    echo "  wait_for_status: $1" >>$LOG
    let counter=counter-1
    sleep 1
  done
  return 1
}

case $1 in
  start)
    echo "Start service" >>$LOG
    if daemon_status; then
      echo "  ${DNAME} is already running" >>$LOG
      exit 0
    fi
    
    #Are the port already used?
    if netstat -tlpn | grep ${SYNOPKG_PKGPORT}; then
      echo "  Port ${SYNOPKG_PKGPORT} already in use." >>$LOG
      exit 1
    fi

    DAEMON_HOME="`cat /etc/passwd | grep "${DAEMON_ID}" | cut -f6 -d':'`"
    
    #set the current timezone for Java so that log timestamps are accurate
    #we need to use the modern timezone names so that Java can figure out DST
    SYNO_TZ=$(cat /etc/synoinfo.conf | grep timezone | cut -f2 -d'"')
    if [ -n "$SYNOPKG_DSM_VERSION_MAJOR" -a $SYNOPKG_DSM_VERSION_MAJOR -ge 6 ]; then
      SYNO_TZ=$(jq ".${SYNO_TZ} | .nameInTZDB" /usr/share/zoneinfo/Timezone/synotztable.json | sed -e "s/\"//g")
    elif [ -n "$SYNOPKG_DSM_VERSION_MAJOR" -a $SYNOPKG_DSM_VERSION_MAJOR -ge 5 -a $SYNOPKG_DSM_VERSION_MINOR -ge 2 ]; then
      SYNO_TZ=$(grep "^${SYNO_TZ}" /usr/share/zoneinfo/Timezone/tzname | sed -e "s/^.*= //")
    else
      SYNO_TZ=$(grep "^${SYNO_TZ}" /usr/share/zoneinfo/Timezone/tzlist | sed -e "s/^.*= //")
    fi  
    grep "^export TZ" ${DAEMON_HOME}/.profile > /dev/null \
     && sed -i "s%^export TZ=.*$%export TZ='${SYNO_TZ}'%" ${DAEMON_HOME}/.profile \
     || echo export TZ=\'${SYNO_TZ}\' >> ${DAEMON_HOME}/.profile
    
    #start OpenHAB runtime in background mode
    echo "  call start.sh." >>$LOG
    su - ${DAEMON_USER} -s /bin/sh -c "cd ${SYNOPKG_PKGDEST} && ./${ENGINE_SCRIPT} &"   
    if [ $? -ne 0 ]; then echo "  FAILED (su)" >>$LOG; exit 1; fi
    wait_for_status 0 5
    rm -f ${PIDFILE}
    if [ -n "$SYNOPKG_DSM_VERSION_MAJOR" -a $SYNOPKG_DSM_VERSION_MAJOR -ge 6 ]; then
      echo $(ps aux | grep "^${DAEMON_USER}.*java" | awk '{print $2}') >>${PIDFILE}
    else
      echo $(ps | grep "^ *[0-9]* ${DAEMON_USER} .*java" | awk '{print $1}') >>${PIDFILE}
    fi
    echo "  PID file created." >>$LOG
    
    echo "done." >>$LOG
    exit 0
  ;;

  stop)
    echo "Stop service." >>$LOG
  
    if daemon_status; then
      echo "  Stopping ${DNAME} ..."  >>$LOG
      stop_daemon
    else
      echo "  ${DNAME} is not running" >>$LOG
    fi
    
    echo "done." >>$LOG
    exit 0
  ;;

  status)
    if daemon_status; then
      echo "  ${DNAME} is running"
      exit 0
    else
      echo "  ${DNAME} is not running"
      exit 1
    fi
  ;;

  log)
    echo "${SYNOPKG_PKGDEST}/userdata/logs/openhab.log"
    exit 0
  ;;
esac
