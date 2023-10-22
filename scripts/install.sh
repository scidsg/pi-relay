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

# Update and upgrade non-interactively
export DEBIAN_FRONTEND=noninteractive
apt update && apt -y dist-upgrade -o Dpkg::Options::="--force-confnew" && apt -y autoremove
apt install -y whiptail git wget curl gpg ufw fail2ban unattended-upgrades bc apt-transport-https apt-listchanges nginx

# Determine the codename of the operating system
codename=$(lsb_release -c | cut -f2)

# Add the tor repository to the sources.list.d
echo "deb [arch=$architecture signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $codename main" | tee /etc/apt/sources.list.d/tor.list
echo "deb-src [arch=$architecture signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $codename main" | tee -a /etc/apt/sources.list.d/tor.list

# Download and add the gpg key used to sign the packages
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null

# Update system packages
apt update && apt -y dist-upgrade && apt -y autoremove

# Install tor and tor debian keyring
apt install -y tor deb.torproject.org-keyring nyx

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

# Configure unattended-upgrades
cat >/etc/apt/apt.conf.d/50unattended-upgrades <<EOL
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=\${distro_codename}-updates";
        "origin=Debian,codename=\${distro_codename},label=Debian";
        "origin=Debian,codename=\${distro_codename},label=Debian-Security";
        "origin=Debian,codename=\${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOL

cat >/etc/apt/apt.conf.d/20auto-upgrades <<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOL

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

# Configure UFW (Uncomplicated Firewall)
echo "Configuring UFW..."

# Default rules
ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp
ufw allow 443/tcp

echo "Disabling SSH access..."
# ufw deny proto tcp from any to any port 22
ufw allow ssh

# Enable UFW non-interactively
echo "y" | ufw enable

echo "🔒 Firewall configured."

# Block Bluetooth
echo "Disabling Bluetooth..."
rfkill block bluetooth
echo "🔒 Bluetooth disabled."

# Disable USB
echo "Disabling USB access..."
echo "dtoverlay=disable-usb" | tee -a /boot/config.txt
echo "🔒 USB access disabled."
sleep 3

# Disable the trap before exiting
trap - ERR

# Reboot the device
echo "Rebooting..."
sleep 5
reboot

