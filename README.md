# Pi Relay

Pi Relay is a free and open-source tool that transforms a Raspberry Pi into a relay for the Tor Network, aiming to enhance internet safety and access. It is especially beneficial in regions where internet censorship is present. Users such as journalists, librarians, and businesses can utilize Pi Relay to contribute the resiliency and performance of the Tor Network. Pi Relay facilitates the navigation through internet restrictions, upholds privacy, and assists in secure access. By supporting a network that counters digital security threats, it contributes to the broader goals of human rights, open societies, and internet freedom. Add an e-paper display to visualize your relay's activity.

## Easy Install:
 ```
 curl --proto '=https' --tlsv1.2 -sSfL https://install.pirelay.computer | bash
 ```

### Install an e-Paper Display:

```
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/scidsg/pi-relay/main/scripts/display.sh | bash
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
- **Storage:** >=[8 GB microSD](https://www.amazon.com/SanDisk-Extreme-microSDXC-Memory-Adapter/dp/B09X7BK27V?crid=2EGJVK0HAQM9Q&keywords=micro%2Bsd%2Bcard&qid=1693975195&sbo=RZvfv%2F%2FHxDF%2BO5021pAnSA%3D%3D&sprefix=micro%2Bsd%2Bcard%2Caps%2C154&sr=8-5&th=1&linkCode=ll1&tag=scidsg-20&linkId=03e76df85abcf0b17acd93c4e09a9149&language=en_US&ref_=as_li_ss_tl)
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

## Contribution Guidelines

🙌 We're excited that you're interested in contributing to Pi Relay. To maintain the quality of our codebase and ensure the best experience for everyone, we ask that you follow these guidelines:

### Code of Conduct

By contributing to Pi Relay, you agree to our [Code of Conduct](https://github.com/scidsg/business-resources/blob/main/Policies%20%26%20Procedures/Code%20of%20Conduct.md).

### Reporting Bugs

If you find a bug in the software, we appreciate your help in reporting it. To report a bug:

1. **Check Existing Issues**: Before creating a new issue, please check if it has already been reported. If it has, you can add any new information you have to the existing issue.
2. **Create a New Issue**: If the bug hasn't been reported, create a new issue and provide as much detail as possible, including:
   - A clear and descriptive title.
   - Steps to reproduce the bug.
   - Expected behavior and what actually happens.
   - Any relevant screenshots or error messages.
   - Your operating system, browser, and any other relevant system information.

### Submitting Pull Requests

Contributions to the codebase are submitted via pull requests (PRs). Here's how to do it:

1. **Create a New Branch**: Always create a new branch for your changes.
2. **Make Your Changes**: Implement your changes in your branch.
3. **Follow Coding Standards**: Ensure your code adheres to the coding standards set for this project.
4. **Write Good Commit Messages**: Write concise and descriptive commit messages. This helps maintainers understand and review your changes better.
5. **Test Your Changes**: Before submitting your PR, test your changes thoroughly. Please link to a [Gist](https://gist.github.com) containing your terminal's output of the end-to-end install of Pi Relay. For an example of a Gist, refer to the QA table below under the "Install Gist" column.
6. **Create a Pull Request**: Once you are ready, create a pull request against the main branch of the repository. In your pull request description, explain your changes and reference any related issue(s).
7. **Review by Maintainers**: Wait for the maintainers to review your pull request. Be ready to make changes if they suggest any.

By following these guidelines, you help to ensure a smooth and efficient contribution process for everyone.

## QA

| Repo           | Install Type | OS/Source                        | OS Codename  | Installed | Install Gist                                                                       | Display Working | Display Version | Host          | Auditor | Date        | Commit Hash
|----------------|--------------|----------------------------------|--------------|-----------|------------------------------------------------------------------------------------|-----------------|-----------------|---------------|---------|-------------|--------------|
| main           | Middle     | Raspberry Pi OS (64-bit)           |Bookworm      | ✅        | [link](https://gist.github.com/glenn-sorrentino/cc13f7d0cfd5aefb203362ddc5834f9c)  | ✅              | 1.1             | Pi 4B 4GB     | Glenn   | Nov-07-2023 | [08155d0](https://github.com/scidsg/hushline/commit/08155d07d582e44fc12617afdba9e3c95cacdc51) |
