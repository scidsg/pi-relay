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