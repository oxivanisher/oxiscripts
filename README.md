# OxiScripts

This is the code base for oxiscripts which are primarily backup and some maintenance scripts.
Be aware that this is a very old repository, even if its still in use in my private environment.

All of this is done with bash, be warned! Yes, today it would simply be ansible-based ... but today is not the day I rewrite this code. 😊

## Things to know
* The gentoo parts of this repository where not used or tested for at least 10 years
* If changes in the installer are required, please edit the `install_pure.sh` file
* To create a new `install.sh` file (which contains all required code withing), run `make_release.sh`
* The runtime timestamp of a `make_release.sh` run is imprinted in the resulting `install.sh` file (variable `INSTALLOXIRELEASE`). With this mechanism, it is able to detect if a update is required.
* Configure the variable `OXIMIRROR` variable to point to your own `install.sh`
* Some basic configuration is done in `/etc/oxiscripts/setup.sh`
