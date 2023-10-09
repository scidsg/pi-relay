#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
                  _                          
                 //                          
   _   o __  _  //  __.  __  ,  
  /_)_<_/ (_</_</_ (_/|_/ (_/_    
 /                         /                
'                         '                 

The easiest way set up a Tor exit, middle, or bridge relay.

A free tool by Science & Design - https://scidsg.org

EOF
sleep 3

# Install whiptail if not present
sudo apt update && sudo apt -y dist-upgrade && sudo apt -y autoremove
sudo apt install -y whiptail git wget curl gpg

git clone https://github.com/glenn-sorrentino/Pi-Relay-Test.git
if [ $? -ne 0 ]; then
    echo "Failed to clone the repository. Exiting."
    exit 1
fi

sleep 6

if [ -d ~/Pi-Relay/scripts/ ]; then
    cd ~/Pi-Relay/scripts/
else
    echo "Directory not found. Exiting."
    exit 1
fi

sleep 3

OPTION=$(whiptail --title "Tor Relay Configurator" --menu "Choose your relay type" 15 60 4 \
"1" "Middle relay" \
"2" "Bridge relay" \
"3" "Exit relay" 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Your chosen option:" $OPTION
    case $OPTION in
        1) bash middle_relay.sh ;;
        2) bash bridge_relay.sh ;;
        3) bash exit_relay.sh ;;
        *) echo "Invalid option. Exiting." ;;
    esac
else
    echo "You chose Cancel."
fi
