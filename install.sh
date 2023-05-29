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
    contactname=$(whiptail --inputbox "Please enter your name" 8 78 "Art Vandelay" --title "Contact Name" 3>&1 1>&2 2>&3)        
    email=$(whiptail --inputbox "Please enter your contact email" 8 78 "demo@scidsg.org" --title "Contact Email" 3>&1 1>&2 2>&3)        
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

# Create a new script to display status on the e-ink display
cat > /home/pi/relay_status.py << EOL
import os
import sys
import time
import socket
import textwrap
from waveshare_epd import epd2in13_V3
from PIL import Image, ImageDraw, ImageFont
from stem import Signal
from stem.control import Controller

def bytes_to_human_readable(bytes, units=[' bytes',' KB',' MB',' GB',' TB', ' PB', ' EB']):
    """ Returns a human readable string reprentation of bytes"""
    if bytes == 0:
        return f"0{units[0]}"
    return f"{bytes:.2f}{units[0]}" if bytes < 1024 else bytes_to_human_readable(bytes / 1024, units[1:])

def get_tor_nickname():
    # Retrieve the Tor relay nickname from the Tor configuration
    with open('/etc/tor/torrc', 'r') as torrc:
        lines = torrc.readlines()
    for line in lines:
        if line.startswith('Nickname'):
            return line.split(' ')[1].strip()
    return ''

def get_accounting_max():
    """Get AccountingMax setting from the Tor configuration file and return it in bytes."""
    with open('/etc/tor/torrc', 'r') as torrc:
        for line in torrc.readlines():
            if line.startswith('AccountingMax'):
                # Split the line into components
                components = line.split()
                
                # Extract the value and unit
                if len(components) != 3:
                    print(f"Unexpected format in AccountingMax: {' '.join(components[1:])}")
                    return 'N/A'
                
                try:
                    value = float(components[1])  # Value can be a decimal
                    unit = components[2]
                except ValueError:
                    print(f"Unable to parse value and unit from AccountingMax: {components[1]} {components[2]}")
                    return 'N/A'
                
                # Convert the value to bytes
                if unit == 'KB':
                    value_in_bytes = value * 1024
                elif unit == 'MB':
                    value_in_bytes = value * 1024**2
                elif unit == 'GB':
                    value_in_bytes = value * 1024**3
                elif unit == 'TB':
                    value_in_bytes = value * 1024**4
                elif unit == 'PB':
                    value_in_bytes = value * 1024**5
                elif unit == 'EB':
                    value_in_bytes = value * 1024**6
                else:
                    print(f"Unexpected unit in AccountingMax: {unit}")
                    return 'N/A'

                return 2 * value_in_bytes
    return 'N/A'

def get_flags():
    with Controller.from_port(port=9051) as controller:
        controller.authenticate() 
        ns = controller.get_network_status(controller.get_info('fingerprint'))
        return ', '.join(ns.flags)

def get_status_info():
    with Controller.from_port(port=9051) as controller:  
        controller.authenticate()  

        tor_version = controller.get_version()
        fingerprint = controller.get_info("fingerprint")[-8:]
        nickname = get_tor_nickname()
        flags = get_flags()

        # Uptime in hours
        uptime = controller.get_info("uptime") 
        uptime_hours = int(uptime) // 3600
        if uptime_hours == 0:
            uptime_hours = "<1"

        # Accounting
        try:
            accounting_bytes = controller.get_info("accounting/bytes").split()
            read_bytes, written_bytes = int(accounting_bytes[0]), int(accounting_bytes[1])
            current_bytes = read_bytes + written_bytes
        except Exception as e:
            print(f"Unable to fetch accounting bytes: {e}")
            read_bytes, written_bytes, current_bytes = "N/A", "N/A", 0

        accounting_max = get_accounting_max()

        status_info = {
            "tor_version": tor_version,
            "nickname": nickname,
            "fingerprint": fingerprint,
            "uptime_hours": uptime_hours,
            "read_bytes": bytes_to_human_readable(read_bytes),
            "written_bytes": bytes_to_human_readable(written_bytes),
            "accounting_max": bytes_to_human_readable(accounting_max),
            "current_bytes": current_bytes,
            "max_bytes": accounting_max,
            "flags": flags,  # include the flags in the status info
        }

    return status_info

def draw_bar_chart(draw, total_width, y_start, current_value, max_value):
    # If max_value is 0, don't draw the chart
    if max_value == 0:
        return

    # Calculate the width of the bar representing the current value.
    bar_width = int((current_value / max_value) * total_width)

    # Ensure that the width of the bar doesn't exceed the total width of the bar chart.
    bar_width = min(bar_width, total_width)

    x_start = 5

    # Draw the bar representing the current value.
    draw.rectangle([(x_start, y_start), (x_start + bar_width, y_start + 10)], fill=0)

    # Draw the outline of the full bar chart.
    draw.rectangle([(x_start, y_start), (x_start + total_width, y_start + 10)], outline=0)

def truncate_text(draw, font, text, max_width):
    width, _ = draw.textsize(text, font=font)
    if width <= max_width:
        return text

    while width > max_width:
        text = text[:-1]
        width, _ = draw.textsize(text + '...', font=font)
        
    return text + '...'

def display_status(epd, status_info):
    print('Displaying status...')
    image = Image.new('1', (epd.height, epd.width), 255)
    draw = ImageDraw.Draw(image)
    chart_width = 240

    # Calculate the percentage of the bandwidth used
    if status_info['max_bytes'] != 0:  # To prevent division by zero
        percentage = (status_info['current_bytes'] / status_info['max_bytes']) * 100
    else:
        percentage = 0.0

    # Set the percentage string based on the percentage
    if percentage < 1.0 and percentage > 0.0:
        percentage_str = "<1%"
    else:
        percentage_str = f"{int(percentage)}%"

    # Generate each line of status text
    lines = [
        f"Tor: {status_info['tor_version']}",
        f"Nickname: {status_info['nickname']}",
        f"Fingerprint: {status_info['fingerprint']}",
        f"Uptime: {status_info['uptime_hours']} hours",
        f"Flags: {status_info['flags']}",  # add this line
        f"Accounting: {bytes_to_human_readable(status_info['current_bytes'])} / {status_info['accounting_max']} ({percentage_str})",
    ]

    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', 10)

    y_text = 5
    x_text = 5
    for line in lines:
        truncated_line = truncate_text(draw, font, line, epd.height - 10) 
        draw.text((x_text, y_text), truncated_line, font=font, fill=0)
        y_text += 15

    # After the text, draw the bar chart. Increase y_text by desired pixels.
    y_start_chart = y_text + 5
    draw_bar_chart(draw, chart_width, y_start_chart, status_info['current_bytes'], status_info['max_bytes'])

    epd.display(epd.getbuffer(image.rotate(90, expand=True)))

def display_splash_screen(epd, splash_screen_path, duration):
    """Displays a splash screen for a given duration."""
    # Open the splash screen image
    splash_image = Image.open(splash_screen_path)
    
    # Display the splash screen
    epd.display(epd.getbuffer(splash_image.rotate(90, expand=True)))
    
    # Wait for the given duration
    time.sleep(duration)

def main():
    print("Starting main function")
    epd = epd2in13_V3.EPD()
    epd.init()
    print("EPD initialized")
    
    # Display splash screen
    script_path = os.path.dirname(os.path.realpath(__file__))
    splash_screen_path = os.path.join(script_path, 'splash-sm.png')
    display_splash_screen(epd, splash_screen_path, 3)  # display splash screen for 3 seconds

    try:
        while True:
            status_info = get_status_info()
            display_status(epd, status_info)
            time.sleep(60)
    except KeyboardInterrupt:
        print('Exiting...')
        sys.exit(0)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    print("Starting status display script")
    try:
        main()
    except KeyboardInterrupt:
        print('Exiting...')
        sys.exit(0)
EOL

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

# Configure automatic updates
curl -sSL https://raw.githubusercontent.com/scidsg/tools/main/auto-updates.sh | bash

sudo reboot