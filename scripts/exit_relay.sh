#!/bin/bash

# Learn more about relay requirements:
# https://community.torproject.org/relay/relays-requirements/

whiptail --title "Exit Relay Warning" --msgbox "You're about to set up an exit relay. Before doing so make sure you understand your local laws and the implications of acting as a Tor exit node.\n\nNever operate an exit relay from home." 16 64
whiptail --title "Are You Sure You're Sure?" --msgbox "We'll stress this again - make sure you understand your local laws, and NEVER RUN AN EXIT RELAY FROM HOME." 16 64
WIDTH=$(tput cols)
whiptail --title "Read The Articles 👇" --msgbox "Okay, so you're still here. Just to drive the point home, check out some of these articles about the risks of operating an exit relay from home:\n\n* When a Dark Web Volunteer Gets Raided by The Police, NPR - https://www.npr.org/sections/alltechconsidered/2016/04/04/472992023/when-a-dark-web-volunteer-gets-raided-by-the-police\n\n* What happened when we got subpoenaed over our Tor exit node, Boing Boing - https://boingboing.net/2015/08/04/what-happened-when-the-fbi-sub.html\n\n* Access Now and EFF Condemn the Arrest of Tor Node Operator Dmitry Bogatov in Russia, EFF - https://www.eff.org/deeplinks/2017/04/access-now-and-eff-condemn-arrest-tor-node-operator-dmitry-bogatov-russia" 24 $WIDTH

# Verify the CPU architecture
architecture=$(dpkg --print-architecture)
echo "CPU architecture is $architecture"

# Install Packages
sudo apt-get install -y apt-transport-https whiptail unattended-upgrades apt-listchanges bc nginx

# Determine the codename of the operating system
codename=$(lsb_release -c | cut -f2)

# Add the tor repository to the sources.list.d
echo "deb [arch=$architecture signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $codename main" | sudo tee /etc/apt/sources.list.d/tor.list
echo "deb-src [arch=$architecture signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $codename main" | sudo tee -a /etc/apt/sources.list.d/tor.list

# Download and add the gpg key used to sign the packages
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | sudo tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null

# Update system packages
sudo apt-get update && sudo apt-get -y dist-upgrade && sudo apt-get -y autoremove

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
Unattended-Upgrade::Automatic-Reboot "true";
EOL

cat > /etc/apt/apt.conf.d/20auto-upgrades << EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::AutocleanInterval "5";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Verbose "1";
EOL

SERVER_IP=$(hostname -I | awk '{print $1}')
current_dir=$(pwd)

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
DirPort 8080
DirPortFrontPage /var/www/html/index.html

# Reject server's own IP
ExitPolicy reject $SERVER_IP:*

# Reject private networks
ExitPolicy reject 0.0.0.0/8:*
ExitPolicy reject 169.254.0.0/16:*
ExitPolicy reject 127.0.0.0/8:*
ExitPolicy reject 192.168.0.0/16:*
ExitPolicy reject 10.0.0.0/8:*
ExitPolicy reject 172.16.0.0/12:*

# Accept common web ports and other ports
ExitPolicy accept *:80
ExitPolicy accept *:443
ExitPolicy accept *:20-23
ExitPolicy accept *:53
ExitPolicy accept *:110
ExitPolicy accept *:143
ExitPolicy accept *:993
ExitPolicy accept *:995

# Reject common P2P ports
ExitPolicy reject *:6881-6889

# Reject everything else
ExitPolicy reject *:*

# Paths to the private data directories for this relay
DataDirectory /var/lib/tor
DisableDebuggerAttachment 0" | sudo tee /etc/tor/torrc

    sudo systemctl restart tor
    sudo systemctl enable tor
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

    bandwidth=$(whiptail --inputbox "Enter your desired bandwidth per second. Fast relays are >=12.5 MB/s." 8 78 "12.5 MB" --title "Bandwidth Rate" 3>&1 1>&2 2>&3)
    burst=$(whiptail --inputbox "Enter your burst rate per second" 8 78 "25 MB" --title "Bandwidth Burst" 3>&1 1>&2 2>&3)
    max=$(whiptail --inputbox "How much data would you like to share every month? It's required to share at least 200 GB." 8 78 "1.5 TB" --title "Accounting Max" 3>&1 1>&2 2>&3)
    contactname=$(whiptail --inputbox "Please enter your name" 8 78 "Random Person" --title "Contact Name" 3>&1 1>&2 2>&3)        
    email=$(whiptail --inputbox "Please enter your contact email. Use the provided format to help avoid spam." 8 78 "<nobody AT example dot com>" --title "Contact Email" 3>&1 1>&2 2>&3)        
    port=$(whiptail --inputbox "Which port do you want to use?" 8 78 "443" --title "Relay Port" 3>&1 1>&2 2>&3)
}

# Function to generate the index.html
generate_index() {
    cat > /var/www/html/index.html << EOL
<!doctype html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="author" content="Science & Design, Inc.">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="description" content="This router is part of the Tor Anonymity Network, which is dedicated to providing privacy to people who need it most.">
        <title>Tor Exit Relay</title>
        <link rel="icon" type="image/x-icon" href="design-system/images/favicon/favicon.ico">
        <style>
            header {position: fixed; top: 0; right: 0; left: 0; flex: 0 1 auto; z-index: 9; backdrop-filter: blur(1rem); -webkit-backdrop-filter: blur(1rem);}
            header {background-color: rgba(255, 255, 255, .8);}
            nav a:hover {box-shadow: inset 0 -3px #895BA5;}
            header .wrapper {display: flex; justify-content: space-between; flex-direction: row;}
            header h1 {width: fit-content; font-size: 1.325rem;white-space: nowrap;font-weight: 300;}
            header .logo {display: flex; align-items: center; padding: 1.5rem 0; line-height: 1.5; display: flex; width: fit-content; font-weight: bold;}
            header a {text-decoration: none;}
            header h1 a:hover {text-decoration: underline;}
            .mobileNav {display: none;}
            nav {display: flex; justify-content: flex-end; width: fit-content;}
            nav a.wrapper {max-width: initial;width: initial;display: flex;padding: 0 .875rem;}
            nav a {display: flex;height: 100%;align-items: center;font-size: .875rem;letter-spacing: .025rem;}
            .imageViewport {width: 100%;max-width: 640px;padding-top: 50%;background-repeat: no-repeat;background-size: contain;background-position: center;margin: 1rem 0;}
            .intro {background-size: cover;background-repeat: no-repeat;background-position-x: 1280px;background-position-y: center;transition: .3s;}
            .primaryBtn {background-color: #E7B1D2;color: #24093B;}
            .btn {font-size: 1rem;border-radius: 50vw; padding: 1rem 1.25rem; outline: 2px solid rgba(255, 255, 255, .5);border: 2px solid #895BA5; font-weight: 700;font-family: monospace; height: fit-content; align-self: center;}
            :focus {text-decoration: underline;outline: solid;}
            .btn:focus {text-decoration: underline;outline: solid;}
            .hidden {display: none;}
            input:focus {text-decoration: none;}
            html { font-family: monospace; }
            body {display: flex;flex-flow: column;height: 100%; margin: 0;background-color:#fafafa;}
            h2 {font-size: 4rem; margin: 0;}
            h2,h3,h4,h5,h6 {color:#CF63A6;font-weight: 300;}
            a {cursor: pointer; color: #333;}
            p {font-family: sans-serif; max-width: 640px; font-size: 1.25rem; line-height: 1.5; color: #333; letter-spacing: .0125rem;}
            ul {margin: .75rem 0;}
            ul li {margin: 1rem 0; font-size: 1.25rem; font-family: sans-serif;}
            ul li:first-of-type {margin: 0;}
            img {margin: 1rem 0;width: 100%;}
            header, article, section, footer {display: flex;justify-content: center;}
            section {margin: 0 0 4rem 0;}
            .wrapper {max-width: 1280px;width: 100%;display: flex;padding: 0 2rem;flex-direction: column;}
            .intro {height: 80vh;align-items: center;position: relative; background-color: white; border-bottom: 1px solid rgba(0,0,0,0.1);}
            .intro h2 {width: 60%;line-height: 1.2;}
            .intro p {font-size: 1rem;}
            .intro p:last-of-type {margin-bottom: 0;}
            .intro + div {display:flex; justify-content: center; margin-bottom: 4rem;}
            footer p {font-size: .875rem;}
            .banner p, .banner a {color: #24093B; font-family: monospace; font-size: .875rem}
            .banner {background-color: #E7B1D2;color: #24093B; height: 40px;text-align: center;position: fixed;top: 0;width: 100%;z-index: 1;display: flex;align-items: center;flex-direction: row;}
            .banner p {padding: 0;width: fit-content;margin: 0 auto;}
            .banner + header {top: 40px !important;}
            .banner.hidden + header {top: 0px !important;}
            .banner + header ~ div .intro h2 {margin-top: 40px;}
            .btn:hover {filter: brightness(105%);box-shadow: 0 2px 0 0 rgba(0,0,0,0.1);}
            .btn:active {box-shadow: inset 0 2px 0 rgba(0,0,0,0.1);filter: brightness(95%);}
            @media only screen and (max-width: 960px) {
                header h1 {font-size: 1.2rem;}
                .intro h2 {font-size: 3.5rem;}
            }
            @media only screen and (max-width: 768px) {
                header h1 {font-size: 1.2rem;}
                .intro h2 {width: 100%; font-size: 3rem;}
                .btn {font-size: 1rem; white-space: nowrap;}
            }
            @media only screen and (max-width: 375px) {
                header h1 {font-size: 1.2rem;}
                .btn {font-size: .875rem;}
            }
        </style>
    </head>
    <body>
        <div class="banner">
            <p>Is this resource helpful? <a href="https://opencollective.com/scidsg#category-CONTRIBUTE" target="_blank" rel="noopener noreferrer">Support our work</a>!</p>
        </div>
        <header>
            <div class="wrapper">
                <div class="logo">
                    <div class="logoMark"></div>
                    <h1><a href="#">🧅 Tor Exit Notice</a></h1>
                </div>
                <nav>
                    <a role="button" class="btn primaryBtn btnLrg" href="https://opencollective.com/scidsg/contribute/tor-relay-operator-50818" target="_blank" rel="noopener noreferrer">Sponsor a Relay</a>
                </nav>
            </div>
        </header>
        <div role="main">
            <section class="intro">
                <div class="wrapper">
                    <h2>This is a Tor Exit Router</h2>
                </div>
            </section>
            <div>
                <div class="wrapper">
                    <p>You are most likely accessing this website because you've had some issue with the traffic coming from this IP. This router is part of the <a href="https://www.torproject.org/">Tor Anonymity Network</a>, which is dedicated to <a href="https://2019.www.torproject.org/about/overview">providing privacy</a> to people who need it most: average computer users. This router IP should be generating no other traffic, unless it has been compromised.</p>
                    <p>Tor works by running user traffic through a random chain of encrypted servers, and then letting the traffic exit the Tor network through an exit node like this one. This design makes it very hard for a service to know which user is connecting to it, since it can only see the IP-address of the Tor exit node:</p>
                    <p style="text-align:center;margin:40px 0">
                        <svg xmlns="http://www.w3.org/2000/svg" width="500" viewBox="0 0 490.28 293.73" style="width:100%;max-width:600px">
                            <desc>Illustration showing how a user might connect to a service through the Tor network. The user first sends their data through three daisy-chained encrypted Tor servers that exist on three different continents. Then the last Tor server in the chain connects to the target service over the normal internet.</desc>
                            <defs>
                            <style>
                            .t{
                            fill: var(--text-color);
                            stroke: var(--text-color);
                            }
                            </style>
                            </defs>
                            <path fill="#6fc8b7" d="M257.89 69.4c-6.61-6.36-10.62-7.73-18.36-8.62-7.97-1.83-20.06-7.99-24.17-.67-3.29 5.85-18.2 12.3-16.87 2.08.92-7.03 11.06-13.28 17-17.37 8.69-5.99 24.97-2.87 26.1-10.28 1.04-6.86-8.33-13.22-8.55-2.3-.38 12.84-19.62 2.24-8.73-6.2 8.92-6.9 16.05-9.02 25.61-6.15 12.37 4.83 25.58-2.05 33.73-.71 12.37-2.01 24.69-5.25 37.39-3.96 13 .43 24.08-.14 37.06.63 9.8 1.58 16.5 2.87 26.37 3.6 6.6.48 17.68-.82 24.3 1.9 8.3 4.24.44 10.94-6.89 11.8-8.79 1.05-23.59-1.19-26.6 1.86-5.8 7.41 10.75 5.68 11.27 14.54.57 9.45-5.42 9.38-8.72 16-2.7 4.2.3 13.93-1.18 18.45-1.85 5.64-19.64 4.47-14.7 14.4 4.16 8.34 1.17 19.14-10.33 12.02-5.88-3.65-9.85-22.04-15.66-21.9-11.06.27-11.37 13.18-12.7 17.52-1.3 4.27-3.79 2.33-6-.63-3.54-4.76-7.75-14.22-12.01-17.32-6.12-4.46-10.75-1.17-15.55 2.83-5.63 4.69-8.78 7.82-7.46 16.5.78 9.1-12.9 15.84-14.98 24.09-2.61 10.32-2.57 22.12-8.81 31.47-4 5.98-14.03 20.12-21.27 14.97-7.5-5.34-7.22-14.6-9.56-23.08-2.5-9.02.6-17.35-2.57-26.2-2.45-6.82-6.23-14.54-13.01-13.24-6.5.92-15.08 1.38-19.23-2.97-5.65-5.93-6-10.1-6.61-18.56 1.65-6.94 5.79-12.64 10.38-18.63 3.4-4.42 17.45-10.39 25.26-7.83 10.35 3.38 17.43 10.5 28.95 8.57 3.12-.53 9.14-4.65 7.1-6.62zm-145.6 37.27c-4.96-1.27-11.57 1.13-11.8 6.94-1.48 5.59-4.82 10.62-5.8 16.32.56 6.42 4.34 12.02 8.18 16.97 3.72 3.85 8.58 7.37 9.3 13.1 1.24 5.88 1.6 11.92 2.28 17.87.34 9.37.95 19.67 7.29 27.16 4.26 3.83 8.4-2.15 6.52-6.3-.54-4.54-.6-9.11 1.01-13.27 4.2-6.7 7.32-10.57 12.44-16.64 5.6-7.16 12.74-11.75 14-20.9.56-4.26 5.72-13.86 1.7-16.72-3.14-2.3-15.83-4-18.86-6.49-2.36-1.71-3.86-9.2-9.86-12.07-4.91-3.1-10.28-6.73-16.4-5.97zm11.16-49.42c6.13-2.93 10.58-4.77 14.61-10.25 3.5-4.28 2.46-12.62-2.59-15.45-7.27-3.22-13.08 5.78-18.81 8.71-5.96 4.2-12.07-5.48-6.44-10.6 5.53-4.13.38-9.2-5.66-8.48-6.12.8-12.48-1.45-18.6-1.73-5.3-.7-10.13-1-15.45-1.37-5.37-.05-16.51-2.23-25.13.87-5.42 1.79-12.5 5.3-16.73 9.06-4.85 4.2.2 7.56 5.54 7.45 5.3-.22 16.8-5.36 20.16.98 3.68 8.13-5.82 18.29-5.2 26.69.1 6.2 3.37 11 4.74 16.98 1.62 5.94 6.17 10.45 10 15.14 4.7 5.06 13.06 6.3 19.53 8.23 7.46.14 3.34-9.23 3.01-14.11 1.77-7.15 8.49-7.82 12.68-13.5 7.14-7.72 16.41-13.4 24.34-18.62zM190.88 3.1c-4.69 0-13.33.04-18.17-.34-7.65.12-13.1-.62-19.48-1.09-3.67.39-9.09 3.34-5.28 7.04 3.8.94 7.32 4.92 7.1 9.31 1.32 4.68 1.2 11.96 6.53 13.88 4.76-.2 7.12-7.6 11.93-8.25 6.85-2.05 12.5-4.58 17.87-9.09 2.48-2.76 7.94-6.38 5.26-10.33-1.55-1.31-2.18-.64-5.76-1.13zm178.81 157.37c-2.66 10.08-5.88 24.97 9.4 15.43 7.97-5.72 12.58-2.02 17.47 1.15.5.43 2.65 9.2 7.19 8.53 5.43-2.1 11.55-5.1 14.96-11.2 2.6-4.62 3.6-12.39 2.76-13.22-3.18-3.43-6.24-11.03-7.7-15.1-.76-2.14-2.24-2.6-2.74-.4-2.82 12.85-6.04 1.22-10.12-.05-8.2-1.67-29.62 7.17-31.22 14.86z"/>
                            <g fill="none">
                                <path stroke="#cf63a6" stroke-linecap="round" stroke-width="2.76" d="M135.2 140.58c61.4-3.82 115.95-118.83 151.45-103.33"/>
                                <path stroke="#cf63a6" stroke-linecap="round" stroke-width="2.76" d="M74.43 46.66c38.15 8.21 64.05 42.26 60.78 93.92M286.65 37.25c-9.6 39.44-3.57 57.12-35.64 91.98"/>
                                <path stroke="#e4c101" stroke-dasharray="9.06,2.265" stroke-width="2.27" d="M397.92 162.52c-31.38 1.26-90.89-53.54-148.3-36.17"/>
                                <path stroke="#cf63a6" stroke-linecap="round" stroke-width="2.77" d="M17.6 245.88c14.35 0 14.4.05 28-.03"/>
                                <path stroke="#e3bf01" stroke-dasharray="9.06,2.265" stroke-width="2.27" d="M46.26 274.14c-17.52-.12-16.68.08-30.34.07"/>
                            </g>
                            <g transform="translate(120.8 -35.81)">
                                <circle cx="509.78" cy="68.74" r="18.12" fill="#240a3b" transform="translate(-93.3 38.03) scale(.50637)"/>
                                <circle cx="440.95" cy="251.87" r="18.12" fill="#240a3b" transform="translate(-93.3 38.03) scale(.50637)"/>
                                <circle cx="212.62" cy="272.19" r="18.12" fill="#240a3b" transform="translate(-93.3 38.03) scale(.50637)"/>
                                <circle cx="92.12" cy="87.56" r="18.12" fill="#240a3b" transform="translate(-93.3 38.03) scale(.50637)"/>
                                <circle cx="730.88" cy="315.83" r="18.12" fill="#67727b" transform="translate(-93.3 38.03) scale(.50637)"/>
                                <circle cx="-102.85" cy="282.18" r="9.18" fill="#240a3b"/>
                                <circle cx="-102.85" cy="309.94" r="9.18" fill="#67727b"/>
                            </g>
                            <g class="t">
                                <text xml:space="preserve" x="-24.76" y="10.37" stroke-width=".26" font-size="16.93" font-weight="700" style="line-height:1.25" transform="translate(27.79 2.5)" word-spacing="0"><tspan x="-24.76" y="10.37">The user</tspan></text>
                                <text xml:space="preserve" x="150.63" y="196.62" stroke-width=".26" font-size="16.93" font-weight="700" style="line-height:1.25" transform="translate(27.79 2.5)" word-spacing="0"><tspan x="150.63" y="196.62">This server</tspan></text>
                                <text xml:space="preserve" x="346.39" y="202.63" stroke-width=".26" font-size="16.93" font-weight="700" style="line-height:1.25" transform="translate(27.79 2.5)" word-spacing="0"><tspan x="346.39" y="202.63">Your service</tspan></text>
                                <text xml:space="preserve" x="34.52" y="249.07" stroke-width=".26" font-size="16.93" font-weight="700" style="line-height:1.25" transform="translate(27.79 2.5)" word-spacing="0"><tspan x="34.52" y="249.07">Tor encrypted link</tspan></text>
                                <text xml:space="preserve" x="34.13" y="276.05" stroke-width=".26" font-size="16.93" font-weight="700" style="line-height:1.25" transform="translate(27.79 2.5)" word-spacing="0"><tspan x="34.13" y="276.05">Unencrypted link</tspan></text>
                                <path fill="none" stroke-linecap="round" stroke-width="1.67" d="M222.6 184.1c-2.6-15.27 8.95-23.6 18.43-38.86m186.75 45.61c-.68-10.17-9.4-17.68-18.08-23.49"/>
                                <path fill="none" stroke-linecap="round" stroke-width="1.67" d="M240.99 153.41c.35-3.41 1.19-6.17.04-8.17m-7.15 5.48c1.83-2.8 4.58-4.45 7.15-5.48"/>
                                <path fill="none" stroke-linecap="round" stroke-width="1.67" d="M412.43 173.21c-2.2-3.15-2.54-3.85-2.73-5.85m0 0c2.46-.65 3.85.01 6.67 1.24M61.62 40.8C48.89 36.98 36.45 27.54 36.9 18.96M61.62 40.8c.05-2.58-3.58-4.8-5.25-5.26m-2.65 6.04c1.8.54 6.8 1.31 7.9-.78"/>
                                <path fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.44" d="M1.22 229.4h247.74v63.1H1.22z"/>
                            </g>
                        </svg>
                    </p>
                    <p>Tor sees use by <a href="https://2019.www.torproject.org/about/torusers">many important segments of the population</a>, including whistle blowers, journalists, Chinese dissidents skirting the Great Firewall and oppressive censorship, abuse victims, stalker targets, the US military, and law enforcement, just to name a few.  While Tor is not designed for malicious computer users, it is true that they can use the network for malicious ends. In reality however, the actual amount of <a href="https://support.torproject.org/abuse/">abuse</a> is quite low. This is largely because criminals and hackers have significantly better access to privacy and anonymity than do the regular users whom they prey upon. Criminals can and do <a href="https://web.archive.org/web/20200131013910/http://voices.washingtonpost.com/securityfix/2008/08/web_fraud_20_tools.html">build, sell, and trade</a> far larger and <a href="https://web.archive.org/web/20200131013908/http://voices.washingtonpost.com/securityfix/2008/08/web_fraud_20_distributing_your.html">more powerful networks</a> than Tor on a daily basis. Thus, in the mind of this operator, the social need for easily accessible censorship-resistant private,
                    anonymous communication trumps the risk of unskilled bad actors, who are almost always more easily uncovered by traditional police work than by extensive monitoring and surveillance anyway.</p>
                    <p>In terms of applicable law, the best way to understand Tor is to consider it a network of routers operating as common carriers, much like the Internet backbone. However, unlike the Internet backbone routers, Tor routers explicitly do not contain identifiable routing information about the source of a packet, and no single Tor node can determine both the origin and destination of a given transmission.</p>
                    <p>As such, there is little the operator of this router can do to help you track the connection further. This router maintains no logs of any of the Tor traffic, so there is little that can be done to trace either legitimate or illegitimate traffic (or to filter one from the other).  Attempts to seize this router will accomplish nothing.</p>
                    <!-- FIXME: US-Only section. Remove if you are a non-US operator -->
                    <p>Furthermore, this machine also serves as a carrier of email, which means that its contents are further protected under the ECPA. <a href="https://www.law.cornell.edu/uscode/text/18/2707">18 USC 2707</a> explicitly allows for civil remedies (&dollar;1000/account <i>plus</i>  legal fees) in the event of a seizure executed without good faith or probable cause (it should be clear at this point that traffic with an originating IP address of FIXME_DNS_NAME should not constitute probable cause to seize the machine). Similar considerations exist for 1st amendment content on this machine.</p>
                    <!-- FIXME: May or may not be US-only. Some non-US tor nodes have in fact reported DMCA harassment... -->
                    <p>If you are a representative of a company who feels that this router is being used to violate the DMCA, please be aware that this machine does not host or contain any illegal content. Also be aware that network infrastructure maintainers are not liable for the type of content that passes over their equipment, in accordance with <a href="https://www.law.cornell.edu/uscode/text/17/512">DMCA "safe harbor" provisions</a>. In other words, you will have just as much luck sending a takedown notice to the Internet backbone providers. Please consult <a href="https://community.torproject.org/relay/community-resources/eff-tor-legal-faq/tor-dmca-response/">EFF's prepared response</a> for more information on this matter.</p>
                    <p>For more information, please consult the following documentation:</p>
                    <div class="links">
                        <ul>
                            <li><a href="https://2019.www.torproject.org/about/overview">Tor Overview</a></li>
                            <li><a href="https://support.torproject.org/abuse/">Tor Abuse FAQ</a></li>
                            <li><a href="https://community.torproject.org/relay/community-resources/eff-tor-legal-faq/">Tor Legal FAQ</a></li>
                        </ul>
                    </div>
                    <p>That being said, if you still have a complaint about the router,  you may email the <a href="mailto:$email">maintainer</a>. If complaints are related to a particular service that is being abused, I will consider removing that service from my exit policy, which would prevent my router from allowing that traffic to exit through it. I can only do this on an IP+destination port basis, however. Common P2P ports are
                    already blocked.</p>
                    <p>You also have the option of blocking this IP address and others on the Tor network if you so desire. The Tor project provides a <a href="https://check.torproject.org/torbulkexitlist">web service</a> to fetch a list of all IP addresses of Tor exit nodes that allow exiting to a specified IP:port combination, and an official <a href="https://dist.torproject.org/tordnsel/">DNSRBL</a> is also available to determine if a given IP address is actually a Tor exit server. Please be considerate when using these options. It would be unfortunate to deny all Tor users access to your site indefinitely simply because of a few bad apples.</p>
                </div>
            </div>
        </div>
        <footer>
            <div class="wrapper">
                <p><a property="dct:title" href="https://github.com/scidsg/tor-exit-notice/" target="_blank" rel="noopener noreferrer">This Exit Notice Page</a> by <a property="cc:attributionName" href="https://scidsg.org/" target="_blank" rel="cc:attributionURL dct:creator noopener noreferrer">Science & Design</a> is <a href="https://github.com/scidsg/tor-exit-notice/blob/main/LICENSE" target="_blank" rel="license noopener noreferrer">licensed in the public domain</a>.</p>
            </div>
        </footer>
    </body>
</html>
EOL
}

# Main function to orchestrate the setup
setup_tor_relay() {
    collect_info
    configure_tor "$nickname" "$bandwidth" "$burst" "$max" "$contactname" "$email" "$port"
    generate_index
}

sudo mkdir -p /var/log/tor
sudo chown debian-tor:debian-tor /var/log/tor
sudo chmod 700 /var/log/tor
sudo chown -R debian-tor:debian-tor /var/lib/tor
sudo chmod 700 /var/lib/tor
sudo chown debian-tor:debian-tor /var/www/html/index.html
sudo systemctl restart tor

setup_tor_relay

whiptail --title "Router Configuration" --msgbox "If you're operating this relay from a local server, you may need to modify some of your router's settings for the Tor network to find it:\n\n1. First, assign this device a static IP address. Your current IP is $SERVER_IP.\n\n2. Enable port forwarding for $SERVER_IP on port $port.\n\nPlease refer to your router's instructions manual if you're unfamiliar with any of these steps." 24 64

echo "
✅ Installation complete!
                                               
Pi Relay is a product by Science & Design. 
Learn more about us at https://scidsg.org.
Have feedback? Send us an email at feedback@scidsg.org.

To run Nyx, enter: sudo -u debian-tor nyx
"
