#!/bin/bash

#Run as root
if [[ $EUID -ne 0 ]]; then
  echo "Script needs to run as root. Elevating permissions now."
  exec sudo /bin/bash "$0" "$@"
fi

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
ORPort $7
Nickname $1
RelayBandwidthRate $2
RelayBandwidthBurst $3
AccountingMax $new_max_value $max_unit
ContactInfo $5 $6
BridgeRelay 1
ExitPolicy reject *:*
DataDirectory /var/lib/tor
DisableDebuggerAttachment 0" | tee /etc/tor/torrc

    systemctl restart tor
    systemctl enable tor
}


# Function to validate Tor relay nickname
validate_nickname() {
    local nn="$1"
    
    # Check for length
    if [ "${#nn}" -lt 1 ] || [ "${#nn}" -gt 19 ]; then
        return 1
    fi

    # Check for valid characters: only alphanumeric characters
    if [[ ! "$nn" =~ ^[a-zA-Z0-9]+$ ]]; then
        return 1
    fi

    return 0
}

# Function to collect user information
collect_info() {
    while true; do
        nickname=$(whiptail --inputbox "Give your relay a nickname. Avoid special characters and spaces." 8 78 "piExitRelay$(date +"%y%m%d")" --title "Nickname" 3>&1 1>&2 2>&3)
        if validate_nickname "$nickname"; then
            break
        else
            whiptail --title "Invalid Nickname" --msgbox "Please enter a valid nickname. It must be between 1 and 19 characters and can only include alphanumeric characters." 10 78
        fi
    done

    bandwidth=$(whiptail --inputbox "Enter your desired bandwidth per second. It's recommended to share >= 2 MB/s." 8 78 "2 MB" --title "Bandwidth Rate" 3>&1 1>&2 2>&3)
    burst=$(whiptail --inputbox "Enter your burst rate per second." 8 78 "4 MB" --title "Bandwidth Burst" 3>&1 1>&2 2>&3)
    max=$(whiptail --inputbox "How much data would you like to share every month? It's required to share at least 200 GB" 8 78 "1.5 TB" --title "Accounting Max" 3>&1 1>&2 2>&3)
    contactname=$(whiptail --inputbox "Please enter your name." 8 78 "Random Person" --title "Contact Name" 3>&1 1>&2 2>&3)        
    email=$(whiptail --inputbox "Please enter your contact email. Use the provided format to help avoid spam." 8 78 "<nobody AT example dot com>" --title "Contact Email" 3>&1 1>&2 2>&3)        
    port=$(whiptail --inputbox "Which port do you want to use?" 8 78 "443" --title "Relay Port" 3>&1 1>&2 2>&3)
}

# Main function to orchestrate the setup
setup_tor_relay() {
    collect_info
    configure_tor "$nickname" "$bandwidth" "$burst" "$max" "$contactname" "$email" "$port"
}

mkdir -p /var/log/tor
chown debian-tor:debian-tor /var/log/tor
chmod 700 /var/log/tor
systemctl restart tor

setup_tor_relay

SERVER_IP=$(hostname -I | awk '{print $1}')
whiptail --title "Router Configuration" --msgbox "If you're operating this relay from a local server, you may need to modify some of your router's settings for the Tor network to find it:\n\n1. First, assign this device a static IP address. Your current IP is $SERVER_IP.\n\n2. Enable port forwarding for $SERVER_IP on port $port.\n\nPlease refer to your router's instructions manual if you're unfamiliar with any of these steps." 20 64

# Configure UFW (Uncomplicated Firewall)
echo "Configuring UFW..."

# Default rules
ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow $7
ufw allow ssh

# Enable UFW non-interactively
echo "y" | ufw enable

echo "🔒 Firewall configured."

echo "
✅ Installation complete!
                                               
Pi Relay is a product by Science & Design. 
Learn more about us at https://scidsg.org.
Have feedback? Send us an email at feedback@scidsg.org.

To run Nyx, enter: -u debian-tor nyx

To configure a Waveshare 2.13 inch e-paper display, enter: curl -sSL https://raw.githubusercontent.com/scidsg/pi-relay/main/scripts/waveshare-2_13in-eink-display.sh | bash
"
