#!/bin/sh

#--------openHAB2 installer script
#--------package based on work from pcloadletter.co.uk

LOG="/var/packages/${SYNOPKG_PKGNAME}/install.log"
echo "#### S T A R T  -  o p e n H A B  S P K ####" >>$LOG
echo "$(date +%Y-%m-%d:%H:%M:%S)" >>$LOG
echo "" >>$LOG

echo "Set instance variables..." >>$LOG
DOWNLOAD_PATH="https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab/target"
DOWNLOAD_FILE1="openhab-2.2.0-SNAPSHOT.tar.gz"

# Add more files by separating them using spaces
INSTALL_FILES="${DOWNLOAD_PATH}/${DOWNLOAD_FILE1}"

EXTRACTED_FOLDER="openHAB-2.2.0-SNAPSHOT"

DAEMON_USER="$(echo ${SYNOPKG_PKGNAME} | awk {'print tolower($_)'})"
DAEMON_PASS="$(openssl rand 12 -base64 2>nul)"
DAEMON_ID="${SYNOPKG_PKGNAME} daemon user"
DAEMON_ACL="user:${DAEMON_USER}:allow:rwxpdDaARWc--:fd--"
ENGINE_SCRIPT="start.sh"
PIDFILE="/var/services/homes/${DAEMON_USER}/.daemon.pid"

source /etc/profile

TEMP_FOLDER="$(find / -maxdepth 2 -name '@tmp' | head -n 1)"
PRIMARY_VOLUME="$(echo ${TEMP_FOLDER} | grep -oP '^/[^/]+')"

if [ "${pkgwizard_public_std}" == "true" ]; then
  SHARE_FOLDER="$(synoshare --get public | grep -oP 'Path.+\[\K[^]]+')"
  OH_FOLDER="${SHARE_FOLDER}/${SYNOPKG_PKGNAME}"
elif [ "${pkgwizard_public_shome}"  == "true" ]; then
  SHARE_FOLDER="$(synoshare --get smarthome | grep -oP 'Path.+\[\K[^]]+')"
  OH_FOLDER="${SHARE_FOLDER}/${SYNOPKG_PKGNAME}"
else
  SHARE_FOLDER="/var/services/homes"
  OH_FOLDER="${SHARE_FOLDER}/${DAEMON_USER}"
fi

OH_FOLDERS_EXISTS=no
OH_CONF="${OH_FOLDER}/conf"
OH_ADDONS="${OH_FOLDER}/addons"
TIMESTAMP="$(date +%Y%m)"
BACKUP_FOLDER="${SYNOPKG_PKGDEST}-backup-$TIMESTAMP"

echo "  primary: ${PRIMARY_VOLUME}" >>$LOG
echo "  share:   ${SHARE_FOLDER}" >>$LOG
echo "  oh:      ${OH_FOLDER}" >>$LOG
echo "  backup:  ${BACKUP_FOLDER}" >>$LOG
echo "done" >>$LOG

preinst ()
{
  echo "Start preinst..." >>$LOG
  # Is Java properly installed?
  if [[ -z "${JAVA_HOME}" || ! -f "${JAVA_HOME}/bin/java" ]]; then
    echo "  ERROR:" >>$LOG
    echo "  Java is not installed or not properly configured." >>$LOG
    echo "  Download and install as described on http://wp.me/pVshC-z5" >>$LOG
    echo "  The Synology provided Java may not work with OpenHAB." >>$LOG
    exit 1
  fi

  # Is the User Home service enabled?
  UH_SERVICE=$(synogetkeyvalue /etc/synoinfo.conf userHomeEnable)
  if [ "${UH_SERVICE}" == "no" ]; then
    echo "  ERROR:" >>$LOG
    echo "  The User Home service is not enabled. Please enable this feature in the User control panel in DSM." >>$LOG
    exit 1
  fi

  if [[ ! -d ${SHARE_FOLDER} ]]; then
    echo "  ERROR:" >>$LOG
    echo "  A shared folder called '${SHARE_FOLDER}' could not be found - note this name is case-sensitive. " >>$LOG
    echo "  Please create this using the Shared Folder DSM Control Panel and try again." >>$LOG
    exit 1
  fi

  echo "  Get new version" >>$LOG
  cd ${TEMP_FOLDER}
  # go through list of files
  for WGET_URL in ${INSTALL_FILES}; do
    WGET_FILENAME="$(echo ${WGET_URL} | sed -r "s%^.*/(.*)%\1%")"
    echo "  Processing ${WGET_FILENAME}" >>$LOG
    [ -f "${TEMP_FOLDER}/${WGET_FILENAME}" ] && rm ${TEMP_FOLDER}/${WGET_FILENAME}
    # use local file first
    if [ -f "${SHARE_FOLDER}/${WGET_FILENAME}" ]; then
      echo "  Found file locally - copying" >>$LOG
      cp ${SHARE_FOLDER}/${WGET_FILENAME} ${TEMP_FOLDER}
    else
      wget -nv --no-check-certificate --output-document=${WGET_FILENAME} ${WGET_URL}
      if [[ $? != 0 ]]; then
          echo "  ERROR:" >>$LOG
          echo "  There was a problem downloading ${WGET_FILENAME} from the download link:" >>$LOG
          echo "  '${WGET_URL}'" >>$LOG
          echo "  Alternatively, download this file manually and place it in the '${SHARE_FOLDER}' shared folder and start installation again." >>$LOG
          if [ -z "${SHARE_FOLDER}" ]; then
            echo "  Note: You must create a '${SHARE_FOLDER}' shared folder first on your primary volume" >>$LOG
          fi
          exit 1
      fi
    fi
  done

  echo "done" >>$LOG
  exit 0
}


postinst ()
{
  echo "Start postinst..." >>$LOG
  #create daemon user if not exists
  echo "  Create '${DAEMON_USER}' daemon user" >>$LOG
  synouser --add ${DAEMON_USER} ${DAEMON_PASS} "${DAEMON_ID}" 0 "" ""
  sleep 3
  
  #add openhab user & handle possible device groups
  synogroup --member dialout ${DAEMON_USER}
  synogroup --member uucp ${DAEMON_USER}

  #determine the daemon user homedir and save that variable in the user's profile
  #this is needed because new users seem to inherit a HOME value of /root which they have no permissions for
  DAEMON_HOME="$(synouser --get ${DAEMON_USER} | grep -oP 'User Dir.+\[\K[^]]+')"
  su - ${DAEMON_USER} -s /bin/sh -c "echo export HOME=\'${DAEMON_HOME}\' >> .profile"
  su - ${DAEMON_USER} -s /bin/sh -c "echo export OPENHAB_PID=~/.daemon.pid >> .profile"

  #extract main archive
  echo "  Install new version" >>$LOG
  cd ${TEMP_FOLDER}
  mkdir ${EXTRACTED_FOLDER}
  tar -xf ${TEMP_FOLDER}/${DOWNLOAD_FILE1} -C ${EXTRACTED_FOLDER} && rm ${TEMP_FOLDER}/${DOWNLOAD_FILE1}
  mv ${TEMP_FOLDER}/${EXTRACTED_FOLDER}/* ${SYNOPKG_PKGDEST}
  rmdir ${TEMP_FOLDER}/${EXTRACTED_FOLDER}
  chmod +x ${SYNOPKG_PKGDEST}/${ENGINE_SCRIPT}

  echo "  Create conf/addon links" >>$LOG
  # if selected create folders for home dir 
  if [ "${pkgwizard_home_dir}" == "true" ]; then
    mkdir -p ${OH_CONF}
    mkdir -p ${OH_ADDONS}
  fi
  #if configdir exists in public folder -> create a symbolic link
  if [ -d ${OH_CONF} ]; then
    OH_FOLDERS_EXISTS=yes
    mv -u ${SYNOPKG_PKGDEST}/conf/* ${OH_CONF}
    rm -r ${SYNOPKG_PKGDEST}/conf
    ln -s ${OH_CONF} ${SYNOPKG_PKGDEST}
    synoacltool -get ${OH_CONF} | grep -F ${DAEMON_ACL} > /dev/null || synoacltool -add ${OH_CONF} ${DAEMON_ACL}
  fi

  #if public addons dir exists in public folder -> create a symbolic link
  if [ -d ${OH_ADDONS} ]; then
    OH_FOLDERS_EXISTS=yes
    mv -u ${SYNOPKG_PKGDEST}/addons/* ${OH_ADDONS}
    rm -r ${SYNOPKG_PKGDEST}/addons
    ln -s ${OH_ADDONS} ${SYNOPKG_PKGDEST}
    synoacltool -get ${OH_ADDONS} | grep -F ${DAEMON_ACL} > /dev/null || synoacltool -add ${OH_ADDONS} ${DAEMON_ACL}
  fi

  #add log file
  mkdir -p ${SYNOPKG_PKGDEST}/userdata/logs
  touch ${SYNOPKG_PKGDEST}/userdata/logs/openhab.log
  
  # Restore UserData if exists
  if [ -d ${BACKUP_FOLDER} ]; then
    cp -arf ${BACKUP_FOLDER}/userdata ${SYNOPKG_PKGDEST}/
    if [ -d ${BACKUP_FOLDER}/userdir ]; then
      mv -f ${BACKUP_FOLDER}/userdir/* ${OH_FOLDER}
    fi 
  fi
  
  #change owner of folder tree
  echo "  Fix permissions" >>$LOG
  if [ $OH_FOLDERS_EXISTS == yes ]; then
    synoshare --setuser public RO + ${DAEMON_USER}
    chown -hR ${DAEMON_USER} ${OH_CONF}
    chown -hR ${DAEMON_USER} ${OH_ADDONS}
  fi
  chown -hR ${DAEMON_USER} ${SYNOPKG_PKGDEST}
  chmod -R u+w ${SYNOPKG_PKGDEST}/userdata

  #if Z-Wave dir exists -> change rights for binding
  if [ -d /dev/ttyACM0 ]; then
    chmod 777 /dev/ttyACM0
  fi
  if [ -d /dev/ttyACM1 ]; then
    chmod 777 /dev/ttyACM1
  fi
  
  echo "done" >>$LOG
  echo "Installation done." > $SYNOPKG_TEMP_LOGFILE;

  exit 0
}


preuninst ()
{
  echo "Start preuninst..." >>$LOG
  #make sure server is stopped
  if su - ${DAEMON_USER} -s /bin/sh -c "cd ${SYNOPKG_PKGDEST}/runtime/karaf/bin && ./stop &"; then
    rm -f $PIDFILE
  fi
  sleep 10

  echo "done" >>$LOG
  exit 0
}


postuninst ()
{
  echo "Start postuninst..." >>$LOG
  # Determine folder before deleting daemon
  DAEMON_HOME="$(synouser --get ${DAEMON_USER} | grep -oP 'User Dir.+\[\K[^]]+')"

  # Remove daemon user
  synouser --del ${DAEMON_USER}
  sleep 3

  # Sanity check daemon had valid folder
  if [ -e "${DAEMON_HOME}" ]; then
    rm -r "${DAEMON_HOME}"
  else
    echo "  Daemon user folder '${DAEMON_HOME}' not found - nothing deleted" >>$LOG
  fi
  
  echo "done" >>$LOG
  exit 0
}


preupgrade ()
{
  echo "Start preupgrade..." >>$LOG
  
  if [[ ! -d ${SHARE_FOLDER} ]]; then
    echo "  ERROR:" >>$LOG
    echo "  A shared folder called '${SHARE_FOLDER}' could not be found - note this name is case-sensitive. " >>$LOG
    echo "  Please create this using the Shared Folder DSM Control Panel and try again." >>$LOG
    exit 1
  fi
  
  #make sure server is stopped
  echo "  Stop server" >>$LOG
  if su - ${DAEMON_USER} -s /bin/sh -c "cd ${SYNOPKG_PKGDEST}/runtime/karaf/bin && ./stop &"; then
    rm -f $PIDFILE
  fi
  sleep 10
  
  echo "  Remove tmp, cache and runtime dirs" >>$LOG
  # Remove tmp, logs, cache and runtime dirs
  if [ -d ${SYNOPKG_PKGDEST}/userdata/tmp ]; then
  	rm -rf ${SYNOPKG_PKGDEST}/userdata/tmp
  fi

  if [ -d ${SYNOPKG_PKGDEST}/userdata/cache ]; then
  	rm -rf ${SYNOPKG_PKGDEST}/userdata/cache
  fi

  if [ -d ${SYNOPKG_PKGDEST}/userdata/log ]; then
  	rm -rf ${SYNOPKG_PKGDEST}/userdata/log
  fi

  if [ -d ${SYNOPKG_PKGDEST}/userdata/logs ]; then
  	rm -rf ${SYNOPKG_PKGDEST}/userdata/logs
  fi
  
  if [ -d ${SYNOPKG_PKGDEST}/runtime ]; then
    rm -rf ${SYNOPKG_PKGDEST}/runtime
  fi
  
  echo "  Remove openHAB system files" >>$LOG
  # Remove openHAB system files...
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/all.policy
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/branding.properties
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/branding-ssh.properties
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/config.properties
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/custom.properties
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/version.properties
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/distribution.info
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/jre.properties
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/profile.cfg
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/startup.properties
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/org.apache.karaf*
  rm -f ${SYNOPKG_PKGDEST}/userdata/etc/org.ops4j.pax.url.mvn.cfg
  
  echo "  Create backup" >>$LOG
  # Create backup
  mkdir -p ${BACKUP_FOLDER}/userdata
  mv ${SYNOPKG_PKGDEST}/userdata/* ${BACKUP_FOLDER}/userdata
  
  # save home dir content if exists or save current content for the new location
  LINK_FOLDER="$(readlink ${SYNOPKG_PKGDEST}/conf)"
  if [[ "${pkgwizard_home_dir}" == "true" || ${LINK_FOLDER} != ${OH_CONF} ]]; then
    LINK_FOLDER="$(dirname ${LINK_FOLDER})"
    mkdir -p ${BACKUP_FOLDER}/userdir
    mv ${LINK_FOLDER}/* ${BACKUP_FOLDER}/userdir
  fi

  echo "done" >>$LOG
  exit 0
}


postupgrade ()
{
  echo "Start postupgrade..." >>$LOG
  # Remove all backups after installation
  rm -rf ${SYNOPKG_PKGDEST}-backup*
  
  echo "done" >>$LOG
  echo "Update done." > $SYNOPKG_TEMP_LOGFILE
  
  exit 0
}
