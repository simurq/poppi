# poppi

POPPI is short for Pop!_OS Post-Installation, which is basically a set of methods to download and install files, apply settings, and make other tweaks to the Pop!_OS operating system after installation as necessary.

The script was tested under Pop!_OS 22.04 only. So, please use and modify with care.
# Pop!_OS Post-Installation (POPPI) Script

POPPI is a highly-customisable set of Bash methods developed for and tested on Pop!_OS 22.04 LTS. It will yield the best results when used on a fresh system installation. POPPI is a work in progress and will probably remain so as long as there is a strong interest from the user community.

[![build][build-badge]][build-link]
![website-deploy-badge]
[![version][version]][changelog]
[![license][gpl-badge]][license]

![Bash](https://raw.githubusercontent.com/odb/official-bash-logo/master/assets/Logos/Icons/PNG/128x128.png)

## Usage

### 1. Get the script

#### Using the latest stable version (Recommended)

```console
wget https://github.com/simurq/poppi/releases/latest/download/poppi.sh -O poppi.sh
chmod +x ./poppi.sh
```

#### Using latest master branch

```console
wget https://raw.githubusercontent.com/simurq/poppi/master/poppi.sh -O poppi.sh
chmod +x ./poppi.sh
```

### 2. Setup the JSON configuration file `configure.pop`

The JSON configuration file `configure.pop` is the key and intergral part of POPPI. It is where you'll spend most of your time adjusting POPPI's workflow to your individual needs. The script will read all the user settings from this file. You're strongly encouraged to modify the configuration file instead of making direct edits to the script.

By default, a new configuration file will be created in the same directory where you run the script. You can then make necessary changes to the file. Both files—`configure.pop` and `poppi.sh`—must stay in the same directory to make sure that POPPI runs properly. A detailed explanation of the JSON key/value pairs found in `configure.pop` is provided below.

#### Section `GENERAL`

This section specifies general settings for the script itself.

```"gen.colour_head": "rgb(72,185,199)"```
↳ sets the colour of headings in RGB* format (default=```#48b9c7```).

```"gen.colour_info": "#949494"```
↳ sets the colour of info messages in HEX format (default=```#949494```).

```"gen.colour_okay": "rgb(78,154,10)"```
↳ sets the colour of messages indicating the successful completion of an operation in RGB format (default=```#4e9a0a```).

```"gen.colour_stop": "#ff3232"```
↳ the colour of error messages in HEX format (default=```#ff3232```).

```"gen.colour_warn": "rgb(240,230,115)"```
↳ the colour of warning messages in RGB format (default=```#f0e673```).

```"gen.logfile_backup_no": "3"```
↳ sets the number of logfile backups (default=```3```; max=```99```).

```"gen.logfile_format": "Metric"```
↳ sets the textual format of logs (```US/Metric```; default=```Metric```).

```"gen.logfile_on": "1"```
↳ toggle to enable (default=```1```)/disable (```0```) logging.

```"gen.maximise_window": "1"```
↳ toggle to maximise (default=```1```)/disable (```0```) the main shell window running POPPI.

```"gen.set_timer": "1"```
↳ toggle to set the timer that calculates the running period of the script.

```"gen.test_server": "duckduckgo.com"```
↳ sets the server to check the Internet connectivity (default=```duckduckgo.com```)

**Note:**
* The colour of text messages displayed on the terminal window running POPPI can be specified either in RGB or HEX format.

#### Section `FIREFOX`

This section covers the operations with the Firefox browser, including but not limited to setting a user profile, download and installation of browser extensions, setting user's privacy environment, etc.

```"ffx.configure": "0"```
↳ toggle to enable (```1```)/disable (default=```0```) browser configuration. When disabled, POPPI will skip the browser configuration completely.

```"ffx.profile": "johndow"```
↳ sets a custom name for the browser profile

```"ffx.extensions": [```
  "groupspeeddial",
  "colorzilla",
  "deepl-translate",
  "diigo-web-collector",
  "downloader-4-reddit-redditsave",
  "gnome-shell-integration",
  "hoxx-vpn-proxy",
  "keepassxc-browser",
  "lumetrium-definer",
  "tampermonkey",
  "uaswitcher",
  "ublock-origin",
  "voila-ai-powered-assistant",
  "wikiwand-wikipedia-modernized",
  "wudooh"
]
```"ffx.cookies_to_keep": [```
  "https://context.reverso.net",
  "https://copilot.microsoft.com",
  "https://discord.com",
  "https://github.com",
  "https://quran.com",
  "https://web.telegram.org",
  "https://web.whatsapp.com",
  "https://wordcounter.net",
  "https://www.bing.com",
  "https://www.wikiwand.com"
]
```"ffx.set_privacy": "1"```
```"ffx.set_homepage": "1"```

#### Section `PACKAGES`

#### Section `MISCOPS`

This section specifies the miscellaneous operations. Currently, it covers only those that  and can be extended based on users' demand.



### 3. Run the script

Always run the script as **user**.

```console
  chmod +x after-effects
  sudo ./after-effects <path-to-your-config or url to config file>
```

## See in Action

![inaction](docs/assets/recordings/ubuntu-focal.gif)


## FAQ & Documentation

See /docs or visit [docs][docs]

## Features

- [Install packages](https://ae.prasadt.com/tasks/#install-apt-packages)
- [Add repositories](https://ae.prasadt.com/tasks/#add-repositories)
- [Remove pre installed](https://ae.prasadt.com/tasks/#purge-unwanted-packages)
- [Add PPAs](https://ae.prasadt.com/tasks/#add-personal-package-archives-ppa)
- [Install deb packages](https://ae.prasadt.com/tasks/#install-debian-package-archives-deb-files)
- [Install static binaries](https://ae.prasadt.com/tasks/#install-static-binaries)
- [Install snap packages](https://ae.prasadt.com/tasks/#installing-snap-packages)

Also handles adding several tweaks and fixes necessary to add repositories and PPAs, supports completely non-interactive mode, so that you can let it run while you have moaar ☕

## Default external repositories

| Name                    | Key               | Packages
| ----------------------- | ----------------- | ---
| [Brave Browser][]*      | brave_browser     | brave-browser
| Docker                  | docker            | docker-ce, docker-ce-rootless-extras, docker-ce-cli
| [Element.io][element]*  | element_io        | element-desktop
| [GitHub - CLI][]        | github            | gh
| [Google - Bazel][]*     | bazel             | bazel
| Google - Chrome*        | chrome            | google-chrome-stable, google-chrome-beta
| Google - Cloud SDK*     | googlecloud       | google-cloud-sdk, kubectl, google-cloud-sdk-minikube
| [Google - gVisor][]     | gvisor            | runsc
| Hashicorp*              | hashicorp         | terraform, consul, nomad, vault, boundary, waypoint
| Mendeley desktop*       | mendeley          | mendeleydesktop
| Microsoft - Azure CLI*  | azurecli          | azure-cli
| Microsoft - Edge*       | edge              | microsoft-edge-dev
| Microsoft - Skype*      | skype             | skypeforlinux
| Microsoft - VSCode      | vscode            | code, code-insiders, code-exploration
| [Miniconda][]*          | miniconda         | conda
| NeuroDebian*            | neurodebian       | https://neuro.debian.net/
| [Podman][] (via OBS)*   | podman            | podman, buildah
| ProtonVPN Client*       | protonvpn         | protonvpn
| ROS                     | ros               |
| ROS2                    | ros2              |
| Signal*                 | signal            | signal-desktop
| Slack Desktop*          | slack             | slack-desktop
| Spotify Client*         | spotify           | spotify-client
| Sublime Text Editor*    | sublimetext       | sublime-text
| Vivaldi*                | vivaldi           | vivaldi-stable
| Wine HQ*                | winehq            | winehq-stable, winehq-staging
| [Ubuntu - Universe][]   | ubuntu_universe   |
| [Ubuntu - Multiverse][] | ubuntu_multiverse |
| [Ubuntu - Restricted][] | ubuntu_restricted |
| [Debian - contrib][]    | debian_contrib    |
| [Debian - non-free][]** | debian_nonfree    |

> **Notes**

  - `*` Only amd64/x86_64 is supported. ARM CPUs like Raspberry Pi/Nvidia Tegra are not
  supported.
  - `**` Debain non free is not supported on Debian Bookworm due to DEB-822 and inclusion of
  non free drivers by default.

## Issues & Help

- Please check [FAQ][FAQ] & [known issues][known-issues].
- Please include the log file and terminal output while opening an issue.

## Contributing & Forks

See [Contributing and forks](/CONTRIBUTING.md)

[FAQ]: https://ae.prasadt.com/faq/dependencies/
[docs]: https://ae.prasadt.com/
[known-issues]: https://ae.prasadt.com/faq/errors/
[changelog]: https://ae.prasadt.com/changelog/

[build-badge]: https://github.com/tprasadtp/ubuntu-post-install/workflows/build/badge.svg
[build-link]: https://github.com/tprasadtp/ubuntu-post-install/actions?query=workflow%3Abuild
[release-ci-badge]: https://github.com/tprasadtp/ubuntu-post-install/workflows/release/badge.svg
[release-ci-link]: https://github.com/tprasadtp/ubuntu-post-install/actions?query=workflow%3Arelease

[docs-ci-badge]: https://github.com/tprasadtp/ubuntu-post-install/workflows/docs/badge.svg
[docs-ci-link]: https://github.com/tprasadtp/ubuntu-post-install/actions?query=workflow%3Adocs

[netlify-badge]: https://api.netlify.com/api/v1/badges/887c3d5c-5203-46b9-a31d-67cada282f36/deploy-status
[netlify]: https://app.netlify.com/sites/ubuntu-post-install/deploys

[website-deploy-badge]:https://img.shields.io/github/deployments/tprasadtp/ubuntu-post-install/production?label=docs&logo=vercel

[version]: https://img.shields.io/github/v/release/tprasadtp/ubuntu-post-install?label=version

[gpl-badge]: https://img.shields.io/badge/License-GPLv3-ff69b4
[license]: https://github.com/tprasadtp/ubuntu-post-install/blob/master/LICENSE

[Brave Browser]: https://brave.com/linux/
[element]: https://element.io
[GitHub - CLI]: https://cli.github.com
[Google - gVisor]: https://gvisor.dev
[Miniconda]: https://www.anaconda.com/blog/rpm-and-debian-repositories-for-miniconda
[Podman]: https://podman.io
[Google - Bazel]: https://bazel.build
[Ubuntu - Universe]: https://help.ubuntu.com/community/Repositories/Ubuntu
[Ubuntu - Restricted]: https://help.ubuntu.com/community/Repositories/Ubuntu
[Ubuntu - Multiverse]: https://help.ubuntu.com/community/Repositories/Ubuntu
[Debian - contrib]: https://www.debian.org/doc/debian-policy/ch-archive#s-contrib
[Debian - non-free]: https://www.debian.org/doc/debian-policy/ch-archive#s-non-free
