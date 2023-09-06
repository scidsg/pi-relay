# Pi Relay

Pi Relay is a free and open-source tool that transforms a Raspberry Pi into a relay for the Tor Network, aiming to enhance internet safety and access. It is especially beneficial in regions where internet censorship is present. Users such as journalists, librarians, and businesses can utilize Pi Relay to contribute the resiliency and performance of the Tor Network. Pi Relay facilitates the navigation through internet restrictions, upholds privacy, and assists in secure access. By supporting a network that counters digital security threats, it contributes to the broader goals of human rights, open societies, and internet freedom. Add an e-paper display to visualize your relay's activity.

## Easy Install:
 ```
 curl -sSL https://install.pirelay.computer | bash
 ```

### Install an e-Paper Display:

```
curl -sSL https://raw.githubusercontent.com/scidsg/pi-relay/main/scripts/waveshare-2_13in-eink-display.sh | bash
```

## System Requirements

### Raspberry Pi
- **Hardware:** [Raspberry Pi 4](https://www.amazon.com/Raspberry-Model-2019-Quad-Bluetooth/dp/B07TC2BK1X/?&_encoding=UTF8&tag=scidsg-20&linkCode=ur2&linkId=ee402e41cd98b8767ed54b1531ed1666&camp=1789&creative=9325)/[3B+](https://www.amazon.com/ELEMENT-Element14-Raspberry-Pi-Motherboard/dp/B07P4LSDYV/?&_encoding=UTF8&tag=scidsg-20&linkCode=ur2&linkId=d76c1db453c42244fe465c9c56601303&camp=1789&creative=9325)
- **Memory:**
   - Non-exit relay @ <5 MB/s: >= 512 MB RAM (Default settings)
   - Non-exit relay @ >5 MB/s: >=1 GB RAM
- **Default Settings:**
   - Relay Type: Middle
   - Monthly data: 1.5 TB
   - Bandwidth rate: 2 MB/s
   - Bandwidth burst: 4 MB/s
   - ORPort: 443
- **Storage:** >=[8 GB Micro SD](https://www.amazon.com/SanDisk-Extreme-microSDXC-Memory-Adapter/dp/B09X7BK27V?crid=2EGJVK0HAQM9Q&keywords=micro%2Bsd%2Bcard&qid=1693975195&sbo=RZvfv%2F%2FHxDF%2BO5021pAnSA%3D%3D&sprefix=micro%2Bsd%2Bcard%2Caps%2C154&sr=8-5&th=1&linkCode=ll1&tag=scidsg-20&linkId=03e76df85abcf0b17acd93c4e09a9149&language=en_US&ref_=as_li_ss_tl)
- **OS:** Raspberry Pi OS (64-bit)
- **Display** (optional): [Waveshare 2.13" e-Paper display](https://www.amazon.com/gp/product/B07Z1WYRQH/?&_encoding=UTF8&tag=scidsg-20&linkCode=ur2&linkId=edc2337499023ba20f7ac43e49dd041d&camp=1789&creative=9325)
- (👆 Affiliate links)

Learn more: https://community.torproject.org/relay/relays-requirements/

<img src="https://github.com/scidsg/pi-relay/assets/28545431/62d0d39a-3bc4-4ece-a464-1cf50e7ed3a7" alt="Pi Relay Devices" width="75%">

## Why Pi Relay?

Pi Relay is designed to make setting up a Tor relay easy for everyone:

* No manually editing files
* Smart defaults
* Tor repositories automatically included
* Set limits on your relay's data usage
* Settings that minimize risk - only middle relay config
* Automatic relay naming
* Nyx setup included
* Automatic updates
* Add an e-ink display to see up-to-date information about your relay's usage
