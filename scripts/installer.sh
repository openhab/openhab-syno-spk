#!/bin/sh

#--------OpenHAB installer script
#--------package based on work from pcloadletter.co.uk

DOWNLOAD_FILE="openhab-offline-2.0.0.b2.zip"
DOWNLOAD_PATH="https://bintray.com/artifact/download/openhab/mvn/org/openhab/distro/openhab-offline/2.0.0.b2"

EXTRACTED_FOLDER="OpenHAB-runtime-2.0.0-beta2"
DOWNLOAD_URL="${DOWNLOAD_PATH}/${DOWNLOAD_FILE}"
DAEMON_USER="`echo ${SYNOPKG_PKGNAME} | awk {'print tolower($_)'}`"
DAEMON_PASS="`openssl rand 12 -base64 2>nul`"
DAEMON_ID="${SYNOPKG_PKGNAME} daemon user"
ENGINE_SCRIPT="start_runtime.sh"
INSTALL_FILES="${DOWNLOAD_URL}"
source /etc/profile
TEMP_FOLDER="`find / -maxdepth 2 -name '@tmp' | head -n 1`"
PRIMARY_VOLUME="/`echo $TEMP_FOLDER | cut -f2 -d'/'`"
PUBLIC_CONF="/volume1/public/OpenHAB2/configurations"
PUBLIC_ADDONS="/volume1/public/OpenHAB2/addons"

preinst ()
{
  if [ -z ${JAVA_HOME} ]; then
    echo "Java is not installed or not properly configured. JAVA_HOME is not defined. "
    echo "Download and install the Java Synology package from http://wp.me/pVshC-z5"
    exit 1
  fi
  
  if [ ! -f ${JAVA_HOME}/bin/java ]; then
    echo "Java is not installed or not properly configured. The Java binary could not be located. "
    echo "Download and install the Java Synology package from http://wp.me/pVshC-z5"
    exit 1
  fi
  
  #is the User Home service enabled?
  UH_SERVICE=`synogetkeyvalue /etc/synoinfo.conf userHomeEnable`
  if [ ${UH_SERVICE} == "no" ]; then
    echo "The User Home service is not enabled. Please enable this feature in the User control panel in DSM."
    exit 1
  fi

  cd ${TEMP_FOLDER}
  for WGET_URL in ${INSTALL_FILES}
  do
    WGET_FILENAME="`echo ${WGET_URL} | sed -r "s%^.*/(.*)%\1%"`"
    [ -f ${TEMP_FOLDER}/${WGET_FILENAME} ] && rm ${TEMP_FOLDER}/${WGET_FILENAME}
    wget --no-check-certificate --output-document=${WGET_FILENAME} ${WGET_URL}
    if [[ $? != 0 ]]; then
      if [ -d ${PUBLIC_FOLDER} ] && [ -f ${PUBLIC_FOLDER}/${DOWNLOAD_FILE} ]; then
        cp ${PUBLIC_FOLDER}/${DOWNLOAD_FILE} ${TEMP_FOLDER}
      else     
        echo "There was a problem downloading ${WGET_FILENAME} from the official download link, "
        echo "which was \"${WGET_URL}\" "
        echo "Alternatively, you may download this file manually and place it in the 'public' shared folder. "
        exit 1
      fi
    fi
  done
  
  exit 0
}


postinst ()
{
  #create daemon user
  synouser --add ${DAEMON_USER} ${DAEMON_PASS} "${DAEMON_ID}" 0 "" ""
  sleep 3
  
  #determine the daemon user homedir and save that variable in the user's profile
  #this is needed because new users seem to inherit a HOME value of /root which they have no permissions for
  DAEMON_HOME="`cat /etc/passwd | grep "${DAEMON_ID}" | cut -f6 -d':'`"
  su - ${DAEMON_USER} -s /bin/sh -c "echo export HOME=\'${DAEMON_HOME}\' >> .profile"
  su - ${DAEMON_USER} -s /bin/sh -c "echo export OPENHAB_PID=~/.daemon.pid >> .profile"
  
  #extract main archive
  cd ${TEMP_FOLDER}
  7z x ${TEMP_FOLDER}/${DOWNLOAD_FILE} -o${EXTRACTED_FOLDER} && rm ${TEMP_FOLDER}/${DOWNLOAD_FILE}
  mv ${TEMP_FOLDER}/${EXTRACTED_FOLDER}/* ${SYNOPKG_PKGDEST}
  rmdir ${TEMP_FOLDER}/${EXTRACTED_FOLDER}
  chmod +x ${SYNOPKG_PKGDEST}/${ENGINE_SCRIPT}
  
  #TCP port 8081 is in use on Synology so we need to move Catalina to another port - 18581
  #This regex was tricky, but possible thanks to http://austinmatzko.com/2008/04/26/sed-multi-line-search-and-replace/
  #sed -i -n '1h;1!H;${;g;s%\(<Connector executor="HTTP-ThreadPool".*port="\)8080\(".* />\)%\118581\2%;p;}' ${SYNOPKG_PKGDEST}/conf/server.xml
  #sed -i "s/^webapp.port=.*$/webapp.port=18581/" ${SYNOPKG_PKGDEST}/webapps/controller/WEB-INF/classes/config.properties

  #if configdir exists in public folder -> create a symbolic link
  if [ -d ${PUBLIC_CONF} ]; then
    rm -r ${SYNOPKG_PKGDEST}/configurations
    ln -s ${PUBLIC_CONF} ${SYNOPKG_PKGDEST}
  fi

  #if public addons dir exists in public folder -> create a symbolic link
  if [ -d ${PUBLIC_ADDONS} ]; then
    rm -r ${SYNOPKG_PKGDEST}/addons
    ln -s ${PUBLIC_ADDONS} ${SYNOPKG_PKGDEST}
  fi


  #change owner of folder tree
  chown -R ${DAEMON_USER} ${SYNOPKG_PKGDEST}
  
  exit 0
}


preuninst ()
{
  #make sure server is stopped
  su - ${DAEMON_USER} -s /bin/sh -c "${SYNOPKG_PKGDEST}/stop_runtime.sh"
  sleep 10
  
  exit 0
}


postuninst ()
{
  #remove daemon user
  synouser --del ${DAEMON_USER}
  sleep 3
  
  #remove daemon user's home directory (needed since DSM 4.1)
  [ -e /var/services/homes/${DAEMON_USER} ] && rm -r /var/services/homes/${DAEMON_USER}
  
  exit 0
}
