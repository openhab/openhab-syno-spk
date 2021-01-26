# openhab-syno-spk - Synology DSM Software Package

This project build a Synology DiskStation SPK install package for [openHAB](https://www.openhab.org) (Home Automation Server).

Comments, suggestions and contributions are welcome!

## License
These packaging files are licensed as follows: [LICENSE](https://raw.githubusercontent.com/openhab/openhab-syno-spk/master/LICENSE)
Please inform yourself of the other licenses used by the software which come with openHAB and openHAB itself. While using these packaging files and all contents of resulting software package, you agreee with all licenses included.
## Download

Download the SPK package from the [releases section](https://github.com/openhab/openhab-syno-spk/releases) and follow the instructions below.

## Documentation

### Prerequirements
 * Download the SPK from our project package. You will find per OpenHAB release one download. The package comes with all required software.
 * (Backup and) uninstall the previous installation based on our old package. You can identify the old package by it's icon.
   TODO: ADD OLD ICON HERE

### Installation
1. Open your "Package Center" and click on the "Manual Install" button to start the install using the SPK file you have downloaded.
2. Click on the "Browse" button and select the SPK file you wish to install.
3. Configure your installation by making adjustments on the following pages. Generally we recommend to keep the default settins. Especially on the expert pages.
4. Confirm the installation

5. Optional: Register the Z-Wave script to be executed on system start. It is required to give OpenHAB permissions to access your dongle.
   1. Open your "Control Panel"
   2. Choose "Task Scheduler"
   3. Create a new "Triggered Task" based on a "User-defined script".
   4. Call the rule "openHAB Enable serial", choose as user root and ensure the event "Boot-up" is selected.
   5. Continue in the "Task Settings" tab and insert 'bash /var/packages/openHAB/target/helper/serial-enable.sh' as user-defined script.
   6. [You can find the content of the script for technical details here in the repo](helper/serial-enable.sh).


## Troubleshooting
The openHAB log files can be found here:
  * `/var/log/packages/openHAB.log` - Made by Synology's software center
  * `/var/packages/openHAB/userdata/logs/` - General logs made by openHAB instance
  * `/var/packages/openHAB/openHAB.log` - Log made by the service management

## Contributing

[![GitHub issues](https://img.shields.io/github/issues/openhab/openhab-syno-spk.svg)](https://github.com/openhab/openhab-syno-spk/issues) [![GitHub forks](https://img.shields.io/github/forks/openhab/openhab-syno-spk.svg)](https://github.com/openhab/openhab-syno-spk/network) [![GitHub stars](https://img.shields.io/github/stars/openhab/openhab-syno-spk.svg)](https://github.com/openhab/openhab-syno-spk/stargazers)

[Contribution guidelines](https://github.com/openhab/openhab-syno-spk/blob/master/CONTRIBUTING.md)
## Useful links:
  * [openHAB Community](https://community.openhab.org/t/synology-diskstation/1446)
  * [Gitter Chat](https://gitter.im/openhab/openhab-syno-spk?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
  * [Build](https://travis-ci.org/openhab/openhab-syno-spk)

