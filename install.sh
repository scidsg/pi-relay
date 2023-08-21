#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
                  _           
                 //           
   _   o __  _  //  __.  __  ,
  /_)_<_/ (_</_</_ (_/|_/ (_/_
 /                         /  
'                         '   

The easiest way to turn your Raspberry Pi into a Tor middle relay.

A free tool by Science & Design - https://scidsg.org
EOF
sleep 3

# Verify the CPU architecture
architecture=$(dpkg --print-architecture)
echo "CPU architecture is $architecture"

# Install apt-transport-https
sudo apt-get install -y apt-transport-https whiptail unattended-upgrades apt-listchanges

whiptail --title "Pi Relay Installation" --msgbox "Pi Relay transforms your Raspberry Pi intro a Tor Network middle relay.\n\nBefore continuing, please modify your router's port forwarding settings to allow traffic over port 443 for this device.\n\nIf you don't know what port forwarding is, stop now and search for your router's specific instructions." 16 64

# Determine the codename of the operating system
codename=$(lsb_release -c | cut -f2)

# Add the tor repository to the sources.list.d
echo "deb [arch=$architecture signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $codename main" | sudo tee /etc/apt/sources.list.d/tor.list
echo "deb-src [arch=$architecture signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $codename main" | sudo tee -a /etc/apt/sources.list.d/tor.list

# Download and add the gpg key used to sign the packages
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | sudo tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null

# Update system packages
sudo apt-get update

# Install tor and tor debian keyring
sudo apt-get install -y tor deb.torproject.org-keyring nyx

# Configure Tor Auto Updates
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOL
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
    "origin=TorProject";
};
Unattended-Upgrade::Package-Blacklist {
};
EOL

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::AutocleanInterval "5";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Verbose "1";
EOL

# Function to configure Tor as a middle relay
configure_tor() {
    # Parse the value and the unit from the provided accounting max
    max_value=$(echo "$4" | cut -d ' ' -f1)
    max_unit=$(echo "$4" | cut -d ' ' -f2)

    # Calculate the new max value (half of the provided value)
    new_max_value=$(echo "scale=2; $max_value / 2" | bc -l)

    echo "Log notice file /var/log/tor/notices.log
RunAsDaemon 1
ControlPort 9051
CookieAuthentication 1
ORPort 443
Nickname $1
RelayBandwidthRate $2
RelayBandwidthBurst $3
# The script takes this input and configures Tor's AccountingMax to be half of the user-specified amount. It does this because the AccountingMax limit in Tor applies separately to sent (outbound) and received (inbound) bytes. In other words, if you set AccountingMax to 1 TB, your Tor node could potentially send and receive up to 1 TB each, totaling 2 TB of traffic.
AccountingMax $new_max_value $max_unit
ContactInfo $5 $6
ExitPolicy reject *:*
DisableDebuggerAttachment 0" | sudo tee /etc/tor/torrc

    sudo systemctl restart tor
    sudo systemctl enable tor
}

# Function to collect user information
collect_info() {
    nickname="pirelay$(date +"%y%m%d")"
    bandwidth=$(whiptail --inputbox "Enter your desired bandwidth per second" 8 78 "1 MB" --title "Bandwidth Rate" 3>&1 1>&2 2>&3)
    burst=$(whiptail --inputbox "Enter your burst rate per second" 8 78 "2 MB" --title "Bandwidth Burst" 3>&1 1>&2 2>&3)
    max=$(whiptail --inputbox "Set your maximum bandwidth each month" 8 78 "1.5 TB" --title "Accounting Max" 3>&1 1>&2 2>&3)
    contactname=$(whiptail --inputbox "Please enter your name" 8 78 "Random Person" --title "Contact Name" 3>&1 1>&2 2>&3)        
    email=$(whiptail --inputbox "Please enter your contact email. Use the provided format to help avoid spam." 8 78 "<nobody AT example dot com>" --title "Contact Email" 3>&1 1>&2 2>&3)        
}

# Main function to orchestrate the setup
setup_tor_relay() {
    collect_info
    configure_tor "$nickname" "$bandwidth" "$burst" "$max" "$contactname" "$email"
}

sudo mkdir -p /var/log/tor
sudo chown debian-tor:debian-tor /var/log/tor
sudo chmod 700 /var/log/tor
sudo systemctl restart tor

setup_tor_relay

echo "
✅ Installation complete!
                                               
Pi Relay is a product by Science & Design. 
Learn more about us at https://scidsg.org.
Have feedback? Send us an email at feedback@scidsg.org.

To run Nyx, enter: sudo -u debian-tor nyx
"

python3 relay_status.py &