#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"                                                        
                                                            
   __             _____      __      _____      __    _ __  
 /'__`\  _______ /\ '__`\  /'__`\   /\ '__`\  /'__`\ /\`'__\
/\  __/ /\______\\ \ \L\ \/\ \L\.\_ \ \ \L\ \/\  __/ \ \ \/ 
\ \____\\/______/ \ \ ,__/\ \__/.\_\ \ \ ,__/\ \____\ \ \_\ 
 \/____/           \ \ \/  \/__/\/_/  \ \ \/  \/____/  \/_/ 
                    \ \_\              \ \_\                
                     \/_/               \/_/                
A free tool by Science & Design - https://scidsg.org

Visualize your relay's activity.

EOF
sleep 3

# Install required packages for e-ink display
apt update
apt-get -y dist-upgrade
apt-get install -y python3-pip whiptail

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

# Download the app
wget https://raw.githubusercontent.com/scidsg/pi-relay/main/relay_status.py

# Download the splash screen
wget https://raw.githubusercontent.com/scidsg/pi-relay/main/images/splash.png

# Add a line to the .bashrc to run the relay_status.py script on boot
if ! grep -q "sudo python3 /home/pi/relay_status.py" /home/pi/.bashrc; then
    echo "sudo python3 /home/pi/relay_status.py &" >> /home/pi/.bashrc
fi
    else
        echo "Your relay is running!"
    fi
}

configure_display