#!/bin/sh
# This will change the sudoers file!
# Should not be called as root/with sudo
# On first call it will store the username
# And call visudo with this script as editor
# On second call the second block will be executed
# (as visudo should call this script with /etc/sudoers.tmp
# as an argument)
# and actual changes to sudoers file will be performed
# adapted from http://stackoverflow.com/a/3706774/1469195

if [ "$1" != "/etc/sudoers.tmp" ]; then
  # Save username to temporary file"   
  echo "${USER}" > username.tmp
  echo "Starting up visudo with this script as first parameter"
  export EDITOR=$0 && sudo -E visudo
else
  # Only run this if this script was not run before
  # i.e. sudoers.rizzoma.bkp had not been created
  if [ ! -f /etc/sudoers.rizzoma.bkp ]; then
    # Make backup of sudoers just in case :)
    sudo cp /etc/sudoers /etc/sudoers.rizzoma.bkp 
    USERNAME=`cat username.tmp`
    sudo sed -i "s/Defaults	env_reset/Defaults	env_reset\nDefaults	env_keep += \"INDEX_PREFIX INDEX_TYPE\"/" $1
    sudo echo -e "\n#run indexer without password prompt\n${USERNAME}	ALL=(sphinxsearch)NOPASSWD: /usr/bin/indexer * \n"  >> $1
    rm -f username.tmp
  else
    echo "Not changing sudoers file twice."
    echo "If you really want to rerun this sudoers change script, delete /etc/sudoers.rizzoma.bkp"
  fi
fi
