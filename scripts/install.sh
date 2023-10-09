#!/bin/bash

#Run as root
if [[ $EUID -ne 0 ]]; then
  echo "Script needs to run as root. Elevating permissions now."
  exec sudo /bin/bash "$0" "$@"
fi

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

# Function to display error message and exit
error_exit() {
    echo "An error occurred during installation. Please check the output above for more details."
    exit 1
}

# Trap any errors and call the error_exit function
trap error_exit ERR

# Install whiptail if not present
apt update && apt -y dist-upgrade && apt -y autoremove
apt install -y whiptail git wget curl gpg ufw fail2ban unattended-upgrades

cd $HOME
git clone https://github.com/scidsg/pi-relay.git
if [ $? -ne 0 ]; then
    echo "Failed to clone the repository. Exiting."
    exit 1
fi

sleep 6

if [ -d $HOME/pi-relay/scripts/ ]; then
    cd $HOME/pi-relay/scripts/
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

# Enable the "security" and "updates" repositories
sed -i 's/\/\/\s\+"\${distro_id}:\${distro_codename}-security";/"\${distro_id}:\${distro_codename}-security";/g' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i 's/\/\/\s\+"\${distro_id}:\${distro_codename}-updates";/"\${distro_id}:\${distro_codename}-updates";/g' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i 's|//\s*Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i 's|//\s*Unattended-Upgrade::Remove-Unused-Dependencies "true";|Unattended-Upgrade::Remove-Unused-Dependencies "true";|' /etc/apt/apt.conf.d/50unattended-upgrades

sh -c 'echo "APT::Periodic::Update-Package-Lists \"1\";" > /etc/apt/apt.conf.d/20auto-upgrades'
sh -c 'echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades'

# Configure unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "true";' | tee -a /etc/apt/apt.conf.d/50unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot-Time "02:00";' | tee -a /etc/apt/apt.conf.d/50unattended-upgrades

systemctl restart unattended-upgrades

echo "Automatic updates have been installed and configured."

# Configure Fail2Ban

echo "Configuring fail2ban..."

systemctl start fail2ban
systemctl enable fail2ban
cp /etc/fail2ban/jail.{conf,local}

cat >/etc/fail2ban/jail.local <<EOL
[DEFAULT]
bantime  = 10m
findtime = 10m
maxretry = 5

[sshd]
enabled = true

# 404 Errors
[nginx-http-auth]
enabled  = true
filter   = nginx-http-auth
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 5

# Rate Limiting
[nginx-limit-req]
enabled  = true
filter   = nginx-limit-req
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 5

# 403 Errors
[nginx-botsearch]
enabled  = true
filter   = nginx-botsearch
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 10

# Bad Bots and Crawlers
[nginx-badbots]
enabled  = true
filter   = nginx-badbots
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 2
EOL

systemctl restart fail2ban

# Disable the trap before exiting
trap - ERR

# Reboot the device
echo "Rebooting..."
sleep 5
reboot

