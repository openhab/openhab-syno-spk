#!/bin/sh

#--------openHAB installer script
#--------package based on work from pcloadletter.co.uk

LOG="/var/log/${SYNOPKG_PKGNAME}-install.log"
# Delete Log if older than 1 day
find ${LOG} -mtime +1 -type f -delete
echo "#### S T A R T  -  o p e n H A B  S P K ####" >>$LOG
echo "$(date +%Y-%m-%d:%H:%M:%S)" >>$LOG
echo "" >>$LOG

echo "Set instance variables..." >>$LOG
DOWNLOAD_PATH="https://bintray.com/openhab/mvn/download_file?file_path=org/openhab/distro/openhab/2.5.0"
DOWNLOAD_FILE1="openhab-2.5.0.zip"

# Add more files by separating them using spaces
INSTALL_FILES="${DOWNLOAD_PATH}/${DOWNLOAD_FILE1}"

EXTRACTED_FOLDER="openHAB-2.5.0"

DAEMON_USER="$(echo ${SYNOPKG_PKGNAME} | awk {'print tolower($_)'})"
DAEMON_PASS="$(openssl rand 12 -base64 2>null)"
DAEMON_ID="${SYNOPKG_PKGNAME} daemon user"
DAEMON_ACL="user:${DAEMON_USER}:allow:rwxpdDaARWc--:fd--"
ENGINE_SCRIPT="start.sh daemon"
PIDFILE="/var/services/homes/${DAEMON_USER}/.daemon.pid"

source /etc/profile

TEMP_FOLDER="$(find / -maxdepth 2 -name '@tmp' | head -n 1)"

echo "  public:    ${pkgwizard_public_std}" >>$LOG
echo "  smarthome: ${pkgwizard_public_shome}" >>$LOG
echo "  home:      ${pkgwizard_home_dir}" >>$LOG
echo "  TMPFS:     ${pkgwizard_tmpfs}"  >>$LOG
echo "  Z-Wave:    ${pkgwizard_zwave}"  >>$LOG

if [ "${pkgwizard_public_std}" == "true" ]; then
  SHARE_FOLDER="$(synoshare --get public | grep Path | awk -F[ '{print $2}' | awk -F] '{print $1}')"
  OH_FOLDER="${SHARE_FOLDER}/${SYNOPKG_PKGNAME}"
elif [ "${pkgwizard_public_shome}"  == "true" ]; then
  SHARE_FOLDER="$(synoshare --get smarthome | grep Path | awk -F[ '{print $2}' | awk -F] '{print $1}')"
  OH_FOLDER="${SHARE_FOLDER}/${SYNOPKG_PKGNAME}"
else
  SHARE_FOLDER="/var/services/homes"
  OH_FOLDER="${SHARE_FOLDER}/${DAEMON_USER}"
fi

if [ ! -z "${pkgwizard_txt_port}" ]; then
  echo "  port:    ${pkgwizard_txt_port}" >>$LOG
  if netstat -tlpn | grep :${pkgwizard_txt_port}; then
    echo "  Your selected port ${pkgwizard_txt_port} is already in use." >>$LOG
    echo "  Please choose another one and try again." >>$LOG
    echo " Port ${pkgwizard_txt_port} already in use. Please try again." >> $SYNOPKG_TEMP_LOGFILE
    exit 1
  fi
fi

if [ ! -z "${pkgwizard_txt_ports}" ]; then
  echo "  port:    ${pkgwizard_txt_ports}" >>$LOG
  if netstat -tlpn | grep :${pkgwizard_txt_ports}; then
    echo "  Your selected port ${pkgwizard_txt_ports} is already in use." >>$LOG
    echo "  Please choose another one and try again." >>$LOG
    echo " Port ${pkgwizard_txt_ports} already in use. Please try again." >> $SYNOPKG_TEMP_LOGFILE
    exit 1
  fi
fi

OH_FOLDERS_EXISTS=no
OH_CONF="${OH_FOLDER}/conf"
OH_ADDONS="${OH_FOLDER}/addons"
OH_USERDATA="${OH_FOLDER}/userdata"
TIMESTAMP="$(date +%Y%m)"
BACKUP_FOLDER="${SYNOPKG_PKGDEST}-backup-$TIMESTAMP"

echo "  tmp:    ${TEMP_FOLDER}" >>$LOG
echo "  share:  ${SHARE_FOLDER}" >>$LOG
echo "  oh:     ${OH_FOLDER}" >>$LOG
echo "  backup: ${BACKUP_FOLDER}" >>$LOG
echo "done" >>$LOG

#Print User that exec the Script
echo "User that exec the Installation"   >>$LOG
whoami >>$LOG

preinst ()
{
  echo "Start preinst..." >>$LOG
  # Is Java properly installed?
  if type -p java; then
    echo "  Found java executable in PATH" >>$LOG
    _java=java
  elif [[ -n "${JAVA_HOME}" ]] && [[ -x "${JAVA_HOME}/bin/java" ]]; then
    echo "Found java executable in JAVA_HOME" >>$LOG 
    _java="${JAVA_HOME}/bin/java"
  else
    echo "  ERROR:" >>$LOG
    echo "  Java is not installed, not properly configured or not executable." >>$LOG
    echo "  Download and install as described on http://wp.me/pVshC-z5" >>$LOG
    echo "  The Synology provided Java may not work with OpenHAB." >>$LOG
    echo " Java is not installed or could not be found. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
    exit 1
  fi

  if [[ "$_java" ]]; then
    version=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
    echo "  Java version ${version}"  >>$LOG
    if [[ "$version" > "1.8" ]]; then
      echo "  Version is more than 1.8" >>$LOG
    else         
      echo "  ERROR:" >>$LOG
      echo "  Version is less than 1.8. Please download and install Java 1.8 or higher." >>$LOG
      echo "  On DSM 4 or 5 you have to rename the file to java 7 like:" >>$LOG
      echo "  jdk-8u144-linux-i586.tar.gz to jdk-7u81-linux-i586.tar.gz (81 as example for version 8.1)" >>$LOG
      echo " Wrong Java version. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
      exit 1
    fi
  fi
  
  # Is the User Home service enabled?
  UH_SERVICE=$(synogetkeyvalue /etc/synoinfo.conf userHomeEnable)
  if [ "${UH_SERVICE}" != yes ]; then
    echo "  ERROR:" >>$LOG
    echo "  The User Home service is not enabled. Please enable this feature in the User control panel in DSM." >>$LOG
    echo " User Home service not enabled. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
    exit 1
  fi
  echo "  The User Home service is enabled. UH_SERVICE=${UH_SERVICE}" >>$LOG

  if [[ -z "${SHARE_FOLDER}" || ! -d "${SHARE_FOLDER}" ]]; then
    echo "  ERROR:" >>$LOG
    echo "  A shared folder called '${SHARE_FOLDER}' could not be found - note this name is case-sensitive. " >>$LOG
    echo "  Please create this using the Shared Folder DSM Control Panel and try again." >>$LOG
    echo " Shared folder not found. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
    exit 1
  fi
  echo "  The shared folder '${SHARE_FOLDER}' exists." >>$LOG

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
          echo " Downloading source failed. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
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
  DAEMON_HOME="$(synouser --get ${DAEMON_USER} | grep "User Dir" | awk -F[ '{print $2}' | awk -F] '{print $1}')"
  su - ${DAEMON_USER} -s /bin/sh -c "echo export HOME=\'${DAEMON_HOME}\' >> .profile"
  su - ${DAEMON_USER} -s /bin/sh -c "echo export OPENHAB_PID=~/.daemon.pid >> .profile"

  #extract main archive
  echo "  Install new version" >>$LOG
  cd ${TEMP_FOLDER}
  echo "    Extract ${DOWNLOAD_FILE1}" >>$LOG
  if [ -e /usr/bin/7z ]; then
    7z x ${TEMP_FOLDER}/${DOWNLOAD_FILE1} -o${EXTRACTED_FOLDER}
  else
    unzip ${TEMP_FOLDER}/${DOWNLOAD_FILE1} -d ${EXTRACTED_FOLDER}
  fi
  if [ $? -ne 0 ]; then 
    echo "    FAILED (extract)" >>$LOG;
    echo " Installation failed. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
    exit 1; 
  fi
  rm ${TEMP_FOLDER}/${DOWNLOAD_FILE1}
  
  echo "    Move files to ${SYNOPKG_PKGDEST}" >>$LOG
  mv ${TEMP_FOLDER}/${EXTRACTED_FOLDER}/* ${SYNOPKG_PKGDEST}
  rmdir ${TEMP_FOLDER}/${EXTRACTED_FOLDER}
  chmod +x ${SYNOPKG_PKGDEST}/${ENGINE_SCRIPT}

  # configurate new port for package center
  sed -i 's/^adminport=.*$/adminport="'${pkgwizard_txt_port}'"/g' /var/packages/${SYNOPKG_PKGNAME}/INFO
  if [ $? -ne 0 ]; then
    echo "    FAILED (sed)" >>$LOG;
    echo "    Could not change /var/packages/${SYNOPKG_PKGNAME}/INFO file with new port." >>$LOG;
    echo " Installation failed. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
    exit 1; 
  fi
  
  # configurate new http port for openhab
  sed -i "s/^.*HTTP_PORT=.*$/HTTP_PORT=${pkgwizard_txt_port}/g" ${SYNOPKG_PKGDEST}/runtime/bin/setenv
  if [ $? -ne 0 ]; then
    echo "    FAILED (sed)" >>$LOG;
    echo "    Could not change ${SYNOPKG_PKGDEST}/runtime/bin/setenv file with new http port." >>$LOG;
    echo " Installation failed. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
    exit 1; 
  fi

  # configurate new https port for openhab
  sed -i "s/^.*HTTPS_PORT=.*$/HTTPS_PORT=${pkgwizard_txt_ports}/g" ${SYNOPKG_PKGDEST}/runtime/bin/setenv
  if [ $? -ne 0 ]; then
    echo "    FAILED (sed)" >>$LOG;
    echo "    Could not change ${SYNOPKG_PKGDEST}/runtime/bin/setenv file with new https port." >>$LOG;
    echo " Installation failed. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
    exit 1; 
  fi  

  # configurate TMPFS
  if [ "${pkgwizard_tmpfs}" == "true" ]; then 
    sed -i "s|^OPENHAB2_ROOT=.*$|OPENHAB2_ROOT=""${OH_FOLDER}""|g" "${SYNOPKG_PKGDEST}/openHAB-tmpfs.sh"
    if [ $? -ne 0 ]; then
      echo "    FAILED (sed)" >>$LOG;
      echo "    Could not change ${SYNOPKG_PKGDEST}/openHAB-tmpfs.sh with new path." >>$LOG;
      echo " Installation failed. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
      exit 1; 
    fi
  
    mv "${SYNOPKG_PKGDEST}/openHAB-tmpfs.sh" /usr/local/etc/rc.d/
    if [ $? -ne 0 ]; then
      echo "Not able to move TMPFS-Script to /usr/local/etc/rc.d/" >> $SYNOPKG_TEMP_LOGFILE
      exit 2;
    fi
  
    chown root:root /usr/local/etc/rc.d/openHAB-tmpfs.sh
    chmod 755 /usr/local/etc/rc.d/openHAB-tmpfs.sh
    echo "Started TMPF"  >>$LOG;
    if [ -e ${OH_FOLDER}/saved ]; then
      echo "saved dir for TMPFS allready exists"   >>$LOG;
      else
      mkdir ${OH_FOLDER}/saved
    fi
    echo "Moved TMPFS script to Autostart at Boot"  >>$LOG;
    /usr/local/etc/rc.d/openHAB-tmpfs.sh start
  else
  echo "No TMPFS Install needed"   >>$LOG; 
  fi

  # if selected create folders for home dir 
  if [ "${pkgwizard_home_dir}" == "true" ]; then
    echo "  Create conf/addon/userdata folders for home dir" >>$LOG
    mkdir -p ${OH_CONF}
    mkdir -p ${OH_ADDONS}
    mkdir -p ${OH_USERDATA}
  fi
  
  #if configdir exists in public folder -> create a symbolic link
  if [ -d ${OH_CONF} ]; then
    echo "    Move conf to ${OH_CONF} and create conf link" >>$LOG
    OH_FOLDERS_EXISTS=yes
    mv -u ${SYNOPKG_PKGDEST}/conf/* ${OH_CONF}
    rm -r ${SYNOPKG_PKGDEST}/conf
    ln -s ${OH_CONF} ${SYNOPKG_PKGDEST}
    synoacltool -get ${OH_CONF} | grep -F ${DAEMON_ACL} > /dev/null || synoacltool -add ${OH_CONF} ${DAEMON_ACL}
  fi

  #if public addons dir exists in public folder -> create a symbolic link
  if [ -d ${OH_ADDONS} ]; then
    echo "    Move addons to ${OH_ADDONS} and create addons link" >>$LOG
    OH_FOLDERS_EXISTS=yes
    mv -u ${SYNOPKG_PKGDEST}/addons/* ${OH_ADDONS}
    rm -r ${SYNOPKG_PKGDEST}/addons
    ln -s ${OH_ADDONS} ${SYNOPKG_PKGDEST}
    synoacltool -get ${OH_ADDONS} | grep -F ${DAEMON_ACL} > /dev/null || synoacltool -add ${OH_ADDONS} ${DAEMON_ACL}
  fi
  
  #if public userdata dir exists in public folder -> create a symbolic link
  if [ -d ${OH_USERDATA} ]; then
    echo "    Move userdata to ${OH_USERDATA} and create userdata link" >>$LOG
    OH_FOLDERS_EXISTS=yes
    mv -u ${SYNOPKG_PKGDEST}/userdata/* ${OH_USERDATA}
    rm -r ${SYNOPKG_PKGDEST}/userdata
    ln -s ${OH_USERDATA} ${SYNOPKG_PKGDEST}
    synoacltool -get ${OH_USERDATA} | grep -F ${DAEMON_ACL} > /dev/null || synoacltool -add ${OH_USERDATA} ${DAEMON_ACL}
  fi

  #add log file
  mkdir -p ${SYNOPKG_PKGDEST}/userdata/logs
  touch ${SYNOPKG_PKGDEST}/userdata/logs/openhab.log
  
  # Restore UserData if exists
  if [ -d ${BACKUP_FOLDER} ]; then
    echo "  Restore userdata to ${SYNOPKG_PKGDEST}" >>$LOG
    cp -arf ${BACKUP_FOLDER}/userdata ${SYNOPKG_PKGDEST}/
    if [ -d ${BACKUP_FOLDER}/userdir ]; then
      echo "  Restore configuration files to ${OH_FOLDER}" >>$LOG
      cp -arf ${BACKUP_FOLDER}/userdir/* ${OH_FOLDER}
    fi 
  fi
    
    #Change logrotation to 3MB for TMPFS 
  if [ "${pkgwizard_tmpfs}" == "true" ]; then 
    echo "Change Filesize for Logrotation to keep Peristance Running"  >>$LOG;
    sed -i "s|^log4j2.appender.out.policies.size.size =.*$|log4j2.appender.out.policies.size.size = 3MB|g" "${OH_USERDATA}/etc/org.ops4j.pax.logging.cfg"
      if [ $? -ne 0 ]; then
      echo "    FAILED (sed)" >>$LOG;
      echo "    Could not change openhab.log filesize ${OH_USERDATA}/etc/org.ops4j.pax.logging.cfg with new value." >>$LOG;
      echo " Installation failed. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
      exit 1; 
    fi
    
    sed -i "s|log4j2.appender.event.policies.size.size =.*$|log4j2.appender.event.policies.size.size = 3MB|g" "${OH_USERDATA}/etc/org.ops4j.pax.logging.cfg"
    if [ $? -ne 0 ]; then
      echo "    FAILED (sed)" >>$LOG;
      echo "    Could not change event.log filesize ${OH_USERDATA}/etc/org.ops4j.pax.logging.cfg with new value." >>$LOG;
      echo " Installation failed. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
      exit 1; 
    fi

    sed -i "s|log4j2.appender.audit.policies.size.size =.*$|log4j2.appender.audit.policies.size.size = 3MB|g" "${OH_USERDATA}/etc/org.ops4j.pax.logging.cfg"
    if [ $? -ne 0 ]; then
      echo "    FAILED (sed)" >>$LOG;
      echo "    Could not change audit.log filesize ${OH_USERDATA}/etc/org.ops4j.pax.logging.cfg with new value." >>$LOG;
      echo " Installation failed. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
      exit 1; 
    fi
  fi

  #change owner of folder tree
  echo "  Fix permissions" >>$LOG
  if [ $OH_FOLDERS_EXISTS == yes ]; then
    if [ "${pkgwizard_public_std}" == "true" ]; then
      synoshare --setuser public RO + ${DAEMON_USER}
    elif [ "${pkgwizard_public_shome}"  == "true" ]; then
      synoshare --setuser smarthome RO + ${DAEMON_USER}
    fi
    chown -hR ${DAEMON_USER}:users ${OH_CONF}
    chown -hR ${DAEMON_USER}:users ${OH_ADDONS}
    chown -hR ${DAEMON_USER}:users ${OH_USERDATA}
  fi
  chown -hR ${DAEMON_USER}:users ${SYNOPKG_PKGDEST}
  echo "done" >>$LOG

  #change rights for Z-Wave binding
  if [ "${pkgwizard_zwave}" == "true" ]; then 
  echo "copy Startupscript for z-wave binding. Then start it" >>$LOG
  mv "${SYNOPKG_PKGDEST}/openHAB-zwave.sh" /usr/local/etc/rc.d/
  chown root:root /usr/local/etc/rc.d/openHAB-zwave.sh
  chmod 755 /usr/local/etc/rc.d/openHAB-zwave.sh
  else 
  echo "No Z-Wave Wanted"  >>$LOG;
  fi
  echo "Installation done." > $SYNOPKG_TEMP_LOGFILE;

  exit 0
}


preuninst ()
{
  echo "Start preuninst..." >>$LOG
  #make sure server is stopped
  if su - ${DAEMON_USER} -s /bin/sh -c "cd ${SYNOPKG_PKGDEST}/runtime/bin && ./stop &"; then
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
  DAEMON_HOME="$(synouser --get ${DAEMON_USER} | grep "User Dir" | awk -F[ '{print $2}' | awk -F] '{print $1}')"
  
  #Stop TMPFS
  if [ -e /usr/local/etc/rc.d/openHAB-tmpfs.sh ]; then
    /usr/local/etc/rc.d/openHAB-tmpfs.sh stop
    if [ $? -ne 0 ]; then
      echo "Stop TMPFS was Failed, check TMPFS log in '${OH_FOLDER}' " >> $SYNOPKG_TEMP_LOGFILE
      exit 1;
     fi
    rm /usr/local/etc/rc.d/openHAB-tmpfs.sh
  fi
  # Remove daemon user
  synouser --del ${DAEMON_USER}
  sleep 3

  # Sanity check daemon had valid folder
  if [ -e "${DAEMON_HOME}" ]; then
    rm -r "${DAEMON_HOME}"
  else
    echo "  Daemon user folder '${DAEMON_HOME}' not found - nothing deleted" >>$LOG
  fi

  #Remove Z-Wave Script when its here 
  if [ -e /usr/local/etc/rc.d/openHAB-zwave.sh ]; then 
    rm /usr/local/etc/rc.d/openHAB-zwave.sh
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
    echo " Shared folder not found. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
    exit 1
  fi
  
  #make sure server is stopped
  echo "  Stop server" >>$LOG
  if su - ${DAEMON_USER} -s /bin/sh -c "cd ${SYNOPKG_PKGDEST}/runtime/bin && ./stop &"; then
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

  #Stop TMPFS and delete Scripts
  if [ -e /usr/local/etc/rc.d/openHAB-tmpfs.sh ]; then 
    /usr/local/etc/rc.d/openHAB-tmpfs.sh stop
    if [ $? -ne 0 ]; then
      echo "Stop TMPFS was Failed, check TMPFS log in '${OH_FOLDER}' " >> $SYNOPKG_TEMP_LOGFILE
      exit 1;
    fi

    rm /usr/local/etc/rc.d/openHAB-tmpfs.sh
  fi

  if [ -e /usr/local/etc/rc.d/openHAB-zwave.sh ]; then 
    rm /usr/local/etc/rc.d/openHAB-zwave.sh
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
    echo "  Save symbolic link folders" >>$LOG
    LINK_FOLDER="$(dirname ${LINK_FOLDER})"

    if [[ -z "${LINK_FOLDER}" || ! -d "${LINK_FOLDER}" ]]; then
      echo "  ERROR:" >>$LOG
      echo "  Update failed. Link folder '${LINK_FOLDER}' could not be found. " >>$LOG
      echo "  Please try again or contact the github contributors." >>$LOG
      echo " Link folder not found. See log file $LOG for more details." >> $SYNOPKG_TEMP_LOGFILE
      exit 1
    fi

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
