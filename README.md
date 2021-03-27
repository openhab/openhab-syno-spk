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
 * (Backup and) uninstall the previous installation based on our old package. You can identify the old package by it's icon. \
   ![image](https://user-images.githubusercontent.com/1847437/105901208-54535e80-601d-11eb-9228-0cd2ac720e05.png)

### Installation
1. Open your "Package Center" and click on the "Manual Install" button to start the install using the SPK file you have downloaded. \
   ![Screenshot_20210104_194226](https://user-images.githubusercontent.com/1847437/105900269-17d33300-601c-11eb-8370-9f855a727502.png)
2. Click on the "Browse" button and select the SPK file you wish to install. \
   ![Screenshot_20210104_194650](https://user-images.githubusercontent.com/1847437/105900313-2883a900-601c-11eb-896e-9846d9df86c7.png)
3. Configure your installation by making adjustments on the following pages. Generally we recommend to keep the default settins. Especially on the expert pages.
4. Confirm the installation

5. Optional: Register the Z-Wave script to be executed on system start. It is required to give OpenHAB permissions to access your dongle.
   1. Open your "Control Panel" \
      ![Screenshot_20210126_204910](https://user-images.githubusercontent.com/1847437/105899967-b1e6ab80-601b-11eb-9d33-2974ff2a2ebe.png)
   2. Choose "Task Scheduler" \
      ![Screenshot_20210126_212029](https://user-images.githubusercontent.com/1847437/105900458-5bc63800-601c-11eb-8875-7011c45a38ce.png)
   3. Create a new "Triggered Task" based on a "User-defined script". \
      ![Screenshot_20210126_212128](https://user-images.githubusercontent.com/1847437/105900639-9d56e300-601c-11eb-91a9-d2c28bbf933e.png)
   4. Call the rule "openHAB Enable serial", choose as user root and ensure the event "Boot-up" is selected. \
      ![Screenshot_20210126_212319](https://user-images.githubusercontent.com/1847437/105900767-cd05eb00-601c-11eb-9c6e-2a9f9b634c26.png)
   5. Continue in the "Task Settings" tab and insert 'bash /var/packages/openHAB/target/helper/serial-enable.sh' as user-defined script. \
      ![Screenshot_20210126_212343](https://user-images.githubusercontent.com/1847437/105900813-da22da00-601c-11eb-84e9-cb602e99cc58.png)
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

