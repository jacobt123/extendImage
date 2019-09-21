#!/bin/bash -e

# Add a banner 
cat >> /etc/motd << EOF
*******************************************************
**                 Hello                             **
**      Welcome to a VM that was customized with     **
**            the azure image builder                 **
*******************************************************
EOF

#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./installWeblogic.sh <acceptOTNLicenseAgreement> <otnusername> <otnpassword>"
}

function validateJDKZipCheckSum()
{
  jdkZipFile="$1"
  jdk18u131Sha256Checksum="62b215bdfb48bace523723cdbb2157c665e6a25429c73828a32f00e587301236"

  downloadedJDKZipCheckSum=$(sha256sum $jdkZipFile | cut -d ' ' -f 1)

  if [ "${jdk18u131Sha256Checksum}" == "${downloadedJDKZipCheckSum}" ];
  then
    echo "Checksum match successful. Proceeding with Weblogic Install Kit Zip Download from OTN..."
  else
    echo "Checksum match failed. Please check the supplied OTN credentials and try again."
    exit 1
  fi
}

#Function to cleanup all temporary files
function cleanup()
{
    echo "Cleaning up temporary files..."

    rm -f $BASE_DIR/jdk-8u131-linux-x64.tar.gz
    rm -f $BASE_DIR/fmw_12.2.1.3.0_wls_Disk1_1of1.zip

    rm -rf $JDK_PATH/jdk-8u131-linux-x64.tar.gz
    rm -rf $WLS_PATH/fmw_12.2.1.3.0_wls_Disk1_1of1.zip

    rm -rf $WLS_PATH/silent-template

    rm -rf $WLS_JAR
    echo "Cleanup completed."
}

#Function to create Weblogic Installation Location Template File for Silent Installation
function create_oraInstlocTemplate()
{
    echo "creating Install Location Template..."

    cat <<EOF >$WLS_PATH/silent-template/oraInst.loc.template
inventory_loc=[INSTALL_PATH]
inst_group=[GROUP]
EOF
}

#Function to create Weblogic Installation Response Template File for Silent Installation
function create_oraResponseTemplate()
{

    echo "creating Response Template..."

    cat <<EOF >$WLS_PATH/silent-template/response.template
[ENGINE]

#DO NOT CHANGE THIS.
Response File Version=1.0.0.0.0

[GENERIC]

#Set this to true if you wish to skip software updates
DECLINE_AUTO_UPDATES=false

#My Oracle Support User Name
MOS_USERNAME=

#My Oracle Support Password
MOS_PASSWORD=<SECURE VALUE>

#If the Software updates are already downloaded and available on your local system, then specify the path to the directory where these patches are available and set SPECIFY_DOWNLOAD_LOCATION to true
AUTO_UPDATES_LOCATION=

#Proxy Server Name to connect to My Oracle Support
SOFTWARE_UPDATES_PROXY_SERVER=

#Proxy Server Port
SOFTWARE_UPDATES_PROXY_PORT=

#Proxy Server Username
SOFTWARE_UPDATES_PROXY_USER=

#Proxy Server Password
SOFTWARE_UPDATES_PROXY_PASSWORD=<SECURE VALUE>

#The oracle home location. This can be an existing Oracle Home or a new Oracle Home
ORACLE_HOME=[INSTALL_PATH]/Oracle/Middleware/Oracle_Home

#Set this variable value to the Installation Type selected. e.g. WebLogic Server, Coherence, Complete with Examples.
INSTALL_TYPE=WebLogic Server

#Provide the My Oracle Support Username. If you wish to ignore Oracle Configuration Manager configuration provide empty string for user name.
MYORACLESUPPORT_USERNAME=

#Provide the My Oracle Support Password
MYORACLESUPPORT_PASSWORD=<SECURE VALUE>

#Set this to true if you wish to decline the security updates. Setting this to true and providing empty string for My Oracle Support username will ignore the Oracle Configuration Manager configuration
DECLINE_SECURITY_UPDATES=true

#Set this to true if My Oracle Support Password is specified
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false

#Provide the Proxy Host
PROXY_HOST=

#Provide the Proxy Port
PROXY_PORT=

#Provide the Proxy Username
PROXY_USER=

#Provide the Proxy Password
PROXY_PWD=<SECURE VALUE>

#Type String (URL format) Indicates the OCM Repeater URL which should be of the format [scheme[Http/Https]]://[repeater host]:[repeater port]
COLLECTOR_SUPPORTHUB_URL=


EOF
}

#Function to create Weblogic Uninstallation Response Template File for Silent Uninstallation
function create_oraUninstallResponseTemplate()
{
    echo "creating Uninstall Response Template..."

    cat <<EOF >$WLS_PATH/silent-template/uninstall-response.template
[ENGINE]

#DO NOT CHANGE THIS.
Response File Version=1.0.0.0.0

[GENERIC]

#This will be blank when there is nothing to be de-installed in distribution level
SELECTED_DISTRIBUTION=WebLogic Server~[WLSVER]

#The oracle home location. This can be an existing Oracle Home or a new Oracle Home
ORACLE_HOME=[INSTALL_PATH]/Oracle/Middleware/Oracle_Home/

EOF
}

#Install Weblogic Server using Silent Installation Templates
function installWLS()
{
    # Using silent file templates create silent installation required files
    echo "Creating silent files for installation from silent file templates..."

    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/uninstall-response.template > ${SILENT_FILES_DIR}/uninstall-response
    sed -i 's@\[WLSVER\]@'"$WLS_VER"'@' ${SILENT_FILES_DIR}/uninstall-response
    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/response.template > ${SILENT_FILES_DIR}/response
    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/oraInst.loc.template > ${SILENT_FILES_DIR}/oraInst.loc
    sed -i 's@\[GROUP\]@'"$USER_GROUP"'@' ${SILENT_FILES_DIR}/oraInst.loc

    echo "Created files required for silent installation at $SILENT_FILES_DIR"

    export UNINSTALL_SCRIPT=$INSTALL_PATH/Oracle/Middleware/Oracle_Home/oui/bin/deinstall.sh
    if [ -f "$UNINSTALL_SCRIPT" ]
    then
            currentVer=`. $INSTALL_PATH/Oracle/Middleware/Oracle_Home/wlserver/server/bin/setWLSEnv.sh 1>&2 ; java weblogic.version |head -2`
            echo "#########################################################################################################"
            echo "Uninstalling already installed version :"$currentVer
            runuser -l oracle -c "$UNINSTALL_SCRIPT -silent -responseFile ${SILENT_FILES_DIR}/uninstall-response"
            sudo rm -rf $INSTALL_PATH/*
            echo "#########################################################################################################"
    fi

    echo "---------------- Installing WLS ${WLS_JAR} ----------------"
    echo $JAVA_HOME/bin/java -d64 -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation
    runuser -l oracle -c "$JAVA_HOME/bin/java -d64 -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation"

    # Check for successful installation and version requested
    if [[ $? == 0 ]];
    then
      echo "Weblogic Server Installation is successful"
    else

      echo_stderr "Installation is not successful"
      exit 1
    fi
    echo "#########################################################################################################"

}
