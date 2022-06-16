#!/bin/sh

# Arguments:
#             Target folder for Tomcat
#             Target folder for XDS External Cache
#             XDS Toolkit Version
#             Tomcat Version (Default  )

function check_arguments() {
  if [ $# -lt 4 ] ; then
    echo "Arguments: "
    echo "    Target folder for Tomcat"
    echo "    Target folder for XDS External Cache"
    echo "    XDS Toolkit Version"
    echo "    Path on your system to ImageCache-YYYYmmDD.zip"
    echo "    [Tomcat Version (Default  )]"
    echo ""
    echo " You will find the ImageCache zip file here: https://drive.google.com/drive/folders/1gxn_f-bE_rZU5H06gwwjrZoZtDLafsMg"
    echo " You should download and place the file in a location where this script can access it."
    echo " You can remove the zip file after you have verified the installation is complete."
    echo ""
    echo "Aborting installation"
    exit 1
  fi

  if [[ ! -e $4 ]] ; then
    echo "Did not find Image Cache zip you specified: $4"
    echo " You will find the ImageCache zip file here: https://drive.google.com/drive/folders/1gxn_f-bE_rZU5H06gwwjrZoZtDLafsMg"
    echo " You should download and place the file in a location where this script can access it."
    echo " You can remove the zip file after you have verified the installation is complete."
    echo ""
    echo "Aborting installation"
    exit 1
  fi

  if ! rm -rf $1 ; then
    echo "Could not remove a previous tomcat installation folder: $1"
    echo "Aborting installation"
    exit 1
  fi

  if ! mkdir -p $1 ; then
    echo "Could not create folder for tomcat installation: $1"
    echo "Aborting installation"
    exit 1
  fi


  if ! rm -rf $2 ; then
    echo "Could not remove a previous Toolkit Externcal Cache installation folder: $2"
    echo "Aborting installation"
    exit 1
  fi

  if ! mkdir -p $2 ; then
    echo "Could not create folder for Toolkit External Cache installation: $1"
    echo "Aborting installation"
    exit 1
  fi
}

# Arguments
#             Target folder for Tomcat
#             Tomcat URL
function install_tomcat() {
  echo "Installing Tomcat: "
  echo "Tomcat URL:        $2"
  echo "Target folder:     $1"

  local_tomcat_zip=/tmp/tomcat.zip

  http_response=$(curl --write-out '%{http_code}' --silent --output $local_tomcat_zip $2)
  if [[ "$http_response" -ne 200 ]] ; then
    echo "Could not execute: curl --silent --output $local_tomcat_zip $2"
    echo "HTTP Status Code: $http_response"
    echo "Aborting installation"
    exit 1
  fi 
  echo "  Tomcat zip retrieved and written to $local_tomcat_zip"

  staging_folder=/tmp/tomcat_staging

  echo "  Creating staging area: $staging_folder"
  if ! rm -rf $staging_folder ; then
    echo "Could not remove staging folder: $staging_folder"
    echo "Aborting installation"
    exit 1
  fi

  if ! mkdir -p $staging_folder ; then
    echo "Could not create staging folder: $staging_folder"
    echo "Aborting installation"
    exit 1
  fi

  echo "  Unzip tomcat into staging and move to target folder: $1"
  unzip -q -d $staging_folder $local_tomcat_zip
  chmod +x $staging_folder/*/bin/*sh
  rm -f    $staging_folder/*/bin/*.bat
  mv $staging_folder/*/* $1
  echo "$2" > $1/tomcat_url.txt

  echo "  Cleanup"
  rmdir $staging_folder/* $staging_folder
  rm -rf $1/webapps/*
  rm $local_tomcat_zip

  echo "  Files/folders installed: $1"
  ls -ld $1/*
  echo ""
}

# Arguments
#             Target folder for Tomcat
#             Toolkit Version
#             Application folder name (probably xdsi)
function install_toolkit_war () {
  echo "Installing Toolkit War: "
  echo "Target folder:     $1"
  echo "Tookit version:    $2"
  echo "Application name:  $3"

  toolkit_release_war=https://github.com/usnistgov/iheos-toolkit2/releases/download/v$2/xdstools$2.war
  local_toolkit_war=/tmp/xds_toolkit_release.war

  http_response=$(curl --write-out '%{http_code}' -L --silent --output $local_toolkit_war $toolkit_release_war)
  if [[ "$http_response" -ne 200 ]] ; then
    echo "Could not execute: curl -L --silent --output $local_toolkit_war $toolkit_release_war"
    echo "HTTP Status Code: $http_response"
    echo "Aborting installation"
    exit 1
  fi 
  echo "  Toolkit war retrieved and written to $local_toolkit_war"

  staging_folder=/tmp/xds_toolkit_staging
  echo "  Creating staging area: $staging_folder"

  if ! rm -rf $staging_folder ; then
    echo "Could not remove staging folder: $staging_folder"
    echo "Aborting installation"
    exit 1
  fi

  if ! mkdir -p $staging_folder ; then
    echo "Could not create staging folder: $staging_folder"
    echo "Aborting installation"
    exit 1
  fi

  if ! mkdir -p $1/webapps/$3; then
    echo "Could not create staging folder: $1/webapps/$3"
    echo "Aborting installation"
    exit 1
  fi

  echo "  Explode Toolkit war into staging area"
  pushd $staging_folder > /dev/null
  jar xf $local_toolkit_war
  popd > /dev/null

  echo "  Backup and replace ConfTestsTabs-imaging.xml"
  cp -p		\
	$staging_folder/toolkitx/tool-tab-configs/ConfTestsTabs.xml	\
	$staging_folder/toolkitx/tool-tab-configs/ConfTestsTabs.xml.bak
  cp		\
	etc/tool-tab-configs/ConfTestsTabs.xml	\
	$staging_folder/toolkitx/tool-tab-configs/ConfTestsTabs.xml

  echo "  Move toolkit files/folders to Tomcat webapps: $1/webapps/$3"
  mv $staging_folder/* $1/webapps/$3
  
  echo "Installation date: " `date` > $1/installation_notes.txt
  echo "XDS Toolkit Release WAR: $toolkit_release_war" >> $1/installation_notes.txt
  echo "Modified tomcat/webapps/$3/toolkitx/tool-tab-configs/ConfTestsTabs.xml" >> $1/installation_notes.txt
  echo "  Only imaging tests are included" >> $1/installation_notes.txt

  echo "  Cleanup"
  rmdir $staging_folder
  rm $local_toolkit_war

  echo "  Files/folders installed: $1/webapps/$3"
  ls -ld $1/webapps/$3/*
  echo ""
}

# Arguments
#             Target folder for Tomcat
#             Target folder for XDS External Cache
#             Application folder name (probably xdsi)
#             Toolkit HTTP port (38080)
#             Toolkit HTTPS port (38443)
#             Toolkit Proxy Port (37297)
#             HL7 V2 listener ports (6000-6125)

function modify_toolkit_properties () {
  echo "Modify toolkit.properties"
  echo "Tomcat folder:      $1"
  echo "External cache:     $2"
  echo "Application name:   $3"
  echo "Toolkit Port:       $4"
  echo "Toolkit HTTPS Port: $5"
  echo "Proxy Port:         $6"

  external_cache=$2
  http_port=$4
  https_port=$5
  proxy_port=$6
  v2_port_range=$7

  properties_file=$1/webapps/$3/WEB-INF/classes/toolkit.properties
  echo "  Check for existence of installed properties file: $properties_file"
  if [[ ! -e $properties_file ]] ; then
    echo "Something went wrong with tomcat and/or toolkit installation"
    echo "Did not find this expected file: $properties_file"
    echo "Aborting installation"
    exit 1
  fi

  echo "  Copy template toolkit.properties to /tmp and work from there"
  cp etc/toolkit.properties /tmp


  sed -i ''	\
        -e "s@^External_Cache=.*@External_Cache=$external_cache@"		\
        -e "s/^Toolkit_TLS_Port=.*/Toolkit_TLS_Port=https_port/"		\
        -e "s/^Toolkit_Port=.*/Toolkit_Port=$http_port/"			\
        -e "s/^Proxy_Port=.*/Proxy_Port=$proxy_port/"				\
        -e "s/^Listener_Port_Range=.*/Listener_Port_Range=$v2_port_range/"	\
    /tmp/toolkit.properties

  echo "  Copy updated template toolkit.properties to $properties_file"
  cp /tmp/toolkit.properties $properties_file

  echo "  Cleanup"
  rm /tmp/toolkit.properties
  echo ""
}

# Arguments
#             Target folder for Tomcat
function modify_tomcat_properties () {
  echo "Modify Tomcat properties"
  echo "Tomcat folder:     $1"

  tomcat_server_config=$1/conf/server.xml

  echo "  Change default tomcat ports to 18080 and 18443"
  sed -i ''	\
        -e 's/8080/18080/g'		\
        -e 's/8443/18443/g'		\
    $tomcat_server_config
  echo ""
}


# Arguments
#             Target folder for Tomcat
#             Target folder for XDS External Cache
function create_external_cache() {
  echo "Create external cache: "
  echo "Tomcat folder:     $1"
  echo "External cache:    $2"

  echo "  Remove existing cache if it exists"
  touch $2
  if ! rm -rf $2 ; then
    echo "Failed to remove existing external cache folder: $2"
    echo "Aborting installation"
    exit 1
  fi

  echo "  Make new cache folder"
  if ! mkdir -p $2; then
    echo "Failed to create new external cache folder: $2"
    echo "Aborting installation"
    exit 1
  fi

  echo "  Add xdsi environment"
  mkdir -p $2/environment/xdsi
  cp -rp   $1/webapps/xdsi/toolkitx/environment/default/* $2/environment/xdsi
#  cp -rp   etc/tool-tab-configs                           $2/environment/xdsi
#
#  if [[ ! -e $2/environment/xdsi/tool-tab-configs/ConfTestsTabs.xml ]] ; then
#    echo "Failure when creating external cache"
#    echo " The file $2/environments/xdsitool-tab-configs/ConfTestsTabs.xml did not get created"
#    echo "Aborting installation"
#    exit 1
#  fi
  echo ""
}

# Arguments
#             Target folder for Tomcat
#             Target folder for XDS External Cache
#             Application folder name (probably xdsi)
#             Path on your system to ImageCache-YYYYmmDD.zip
function final_instructions () {
  echo "Final instructions:"
  echo "Tomcat folder:           $1"
  echo "External cache:          $2"
  echo "Application name:        $3"
  echo "Path to Image Cache zip: $4"

  tomcat_server_config=$1/conf/server.xml
  properties_file=$1/webapps/$3/WEB-INF/classes/toolkit.properties

  echo "Check tomcat server configuration: $tomcat_server_config"
  echo "Check toolkit war exploded here:   $1/webapp/$3"
  echo "Check toolkit properties:          $properties_file"
  echo "Check external cache:              $2"
  echo "  xdsi environment exists"
  echo "  images have been added"
  echo "Optional:"
  echo " Remove $4 after you are sure your system is operational"
}
# Arguments
#             Target folder for XDS External Cache
#             Path on your system to ImageCache-YYYYmmDD.zip
function install_images_in_external_cache () {
  echo "Install images in external cache:"
  echo "External cache:          $1"
  echo "Path to Image Cache zip: $2"

  if ! unzip -q -d $1 $2 ; then
   echo "Could not execute: unzip -q -d $1 $2"
    echo "Aborting installation"
    exit 1
  fi

  echo " No cleanup needed; you can remove $2 later."
}

### Main starts here ###

# Arguments:
#             Target folder for Tomcat
#             Target folder for XDS External Cache
#             XDS Toolkit Version
#             Path on your system to ImageCache-YYYYmmDD.zip
#             Tomcat Version (Default  )

check_arguments $*

tomcat_url=https://dlcdn.apache.org/tomcat/tomcat-8/v8.5.81/bin/apache-tomcat-8.5.81.zip

install_tomcat $1 $tomcat_url
install_toolkit_war $1 $3 xdsi
modify_toolkit_properties $1 $2 xdsi 38080 38443 37297 "6000,6125"
modify_tomcat_properties $1

create_external_cache $1 $2
install_images_in_external_cache $2 $4

final_instructions $1 $2 xdsi $4
