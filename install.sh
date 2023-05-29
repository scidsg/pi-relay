#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
            _                   
  ,_   _   // __,        ,_    .
_/ (__(/__(/_(_/(__(_/_ _/_)__/_
                   _/_  /       
                  (/   /        

The easiest way to turn your Raspberry Pi into a Tor middle relay.

A free tool by Science & Design - https://scidsg.org
EOF

# Verify the CPU architecture
architecture=$(dpkg --print-architecture)
echo "CPU architecture is $architecture"

# Install apt-transport-https
sudo apt-get install -y apt-transport-https whiptail unattended-upgrades

whiptail --title "RelayPi Installation" --msgbox "RelayPi transforms your Raspberry Pi intro a Tor Network middle relay.\n\nBefore continuing, please modify your router's port forwarding settings to allow traffic over port 443 for this device.\n\nIf you don't know what port forwarding is, stop now and search for your router's specific instructions." 16 64

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

# Function to decide if Nyx should be launched
configure_display() {
    if (whiptail --title "Configure Display" --yesno "Would you like to add an e-ink display?" 10 60) then
        # Welcome Prompt
whiptail --title "E-Ink Display Setup" --msgbox "The e-paper hat communicates with the Raspberry Pi using the SPI interface, so you need to enable it.\n\nNavigate to \"Interface Options\" > \"SPI\" and select \"Yes\" to enable the SPI interface." 12 64
sudo raspi-config

sudo apt-get install -y python3-pip

# Install Waveshare e-Paper library
git clone https://github.com/waveshare/e-Paper.git
pip3 install ./e-Paper/RaspberryPi_JetsonNano/python/
pip3 install qrcode[pil]
pip3 install requests python-gnupg stem

# Install other Python packages
pip3 install RPi.GPIO spidev
apt-get -y autoremove

# Enable SPI interface
if ! grep -q "dtparam=spi=on" /boot/config.txt; then
    echo "dtparam=spi=on" | sudo tee -a /boot/config.txt
    echo "SPI interface enabled."
else
    echo "SPI interface is already enabled."
fi

# Download the app python
wget https://raw.githubusercontent.com/scidsg/relay-pi/main/relay_status.py

# Download the splash screen
wget https://raw.githubusercontent.com/scidsg/brand-resources/main/logos/splash-sm.png

# Add a line to the .bashrc to run the relay_status.py script on boot
if ! grep -q "sudo python3 /home/pi/relay_status.py" /home/pi/.bashrc; then
    echo "sudo python3 /home/pi/relay_status.py &" >> /home/pi/.bashrc
fi
    else
        echo "Your relay is running!"
    fi
}

configure_display

configure_two_factor() {
    if (whiptail --title "Configure Two-Factor Authentication" --yesno "We recommend setting up two-factor authentication for your relay since it'll be exposed to the internet. Would you like to configure two-factor now?" 10 60) then
        wget https://raw.githubusercontent.com/scidsg/tools/main/two-factor-setup.sh
chmod +x two-factor-setup.sh
./two-factor-setup.sh
fi
    else
        echo "You can configure two-factor any time by running:
wget https://raw.githubusercontent.com/scidsg/tools/main/two-factor-setup.sh
chmod +x two-factor-setup.sh
./two-factor-setup.sh        "
    fi
}

configure_two_factor

# Configure automatic updates
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/auto-updates.sh | bash

sudo reboot