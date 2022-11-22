#!/usr/bin/env bash
 
# Description:          			Post-installation routine tested on Pop!_OS 22.04 LTS
# Github Repository:    			https://github.com/simurqq/poppi
# License:              			GPLv3
# Author:               			Victor Quebec
# Date:                 			Oct 21, 2022
# Requirements - Bash v4.2 and above
#              - coreutils

set -o pipefail

__init_logfile() {
    local bool_created_logfile

    # no file? create it
    if [[ ! -f ${_LOG_FILE} ]]; then
        if touch "${_LOG_FILE}"; then
            bool_created_logfile="true"
        else
            log_and_exit "Failed to create logfile!" 2
        fi
    fi

    # check if log file is writable
    if [[ -w ${_LOG_FILE} ]]; then
        if touch "${_LOG_FILE}"; then
            _FILELOGGER_ACTIVE="true"
            [[ $bool_created_logfile == "true" ]] && log_message "Created log file: ${_LOG_FILE}" 1
            log_message "Initialised logging" 1
        else
            _FILELOGGER_ACTIVE="false"
            log_message "Failed to write to log file ${_LOG_FILE}" 2
            exit 2
        fi
    else
        log_and_exit "Log file ${_LOG_FILE} is not writable!" 2
    fi
}

__init_vars() {
    # set initial variables  
    readonly _BASE_DIR=$(pwd -P)		                 # script directory
    readonly _EXEC_START=$(date +%s)		             # script launch time
    readonly _LOG_FILE="${_BASE_DIR}/poppi.log"          # log file
    readonly _OS="Pop!_OS"
    readonly _OS_RELEASE_FILE="/etc/os-release"
    readonly _SCRIPT=$(basename "$0")		             # this script
    readonly _USER_NAME=$(logname)                       # user name
    readonly _USER_HOME=$(echo "/home/${_USER_NAME}")    # user home directory
    readonly _USER_ID=$(id -u "${_USER_NAME}")           # user login id
    readonly _USER_SESSION="DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${_USER_ID}/bus"
    readonly _APPSDIR="${_USER_HOME}/Portables"
    readonly _BASHRC="${_USER_HOME}/.bashrc"
    readonly _PROFILE="${_USER_HOME}/.profile"
    readonly _BOOKMARKS="${_USER_HOME}/.config/gtk-3.0/bookmarks"
    readonly _USER_APPS="${_USER_HOME}/.local/share/applications"
    readonly _USER_ICONS="${_USER_HOME}/.local/share/icons/hicolor/scalable/apps"
    readonly _VERSION="1.0"					             # script version

    # display colours
    readonly _COLOR_GRAY=$'\e[38;5;245m'
    readonly _COLOR_GREEN=$'\e[32m'
    readonly _COLOR_RED=$'\e[31m'
    readonly _COLOR_YELLOW=$'\e[38;5;220m'
    readonly _COLOR_NC=$'\e[0m'

    # log file status
    _FILELOGGER_ACTIVE="false"

    # screen-lock status
    _IDLE_DELAY=0
}

__logger_core() {
    if [[ $# -ne 2 ]]; then
        return
    else
        declare -r lvl="${1}"
        declare -r lvl_msg="${2}"
        declare -r lvl_ts="$(LC_TIME=en_GB.UTF-8 date)"
        declare lvl_console="1"
        declare lvl_prefix="  "
        declare lvl_nc="${_COLOR_NC}"

        case ${lvl} in
        info)
            declare -r lvl_str="INFO"
            declare -r lvl_sym="•"
            declare -r lvl_color="${_COLOR_GRAY}"
            ;;
        success)
            declare -r lvl_str="SUCCESS"
            declare -r lvl_sym="✓"
            declare -r lvl_color="${_COLOR_GREEN}"
            ;;
        trace)
            declare -r lvl_str="VERBOSE"
            declare -r lvl_sym="»"
            declare -r lvl_color="${_COLOR_GRAY}"
            ;;
        warn | warning)
            declare -r lvl_str="WARNING"
            declare -r lvl_sym="!"
            declare -r lvl_color="${_COLOR_YELLOW}"
            ;;
        error)
            declare -r lvl_str="ERROR"
            declare -r lvl_sym="✗"
            declare -r lvl_color="${_COLOR_RED}"
            ;;
        progress)
            declare -r lvl_sym="»"
            declare -r lvl_color="${_COLOR_GRAY}"
            lvl_console="0"
            ;;
        esac
    fi

    if [[ $lvl_console -eq 1 ]]; then
        printf "%s%s%s %s %s\n" "${lvl_color}" "${lvl_prefix}" "${lvl_sym}" "${lvl_msg}" "${lvl_nc}"
    else
        # for progress reports on the same line ('\r'). strlen=100 to provide enough space to mask overwritten messages
        printf "%s%s%s %-100s %s\r" "${lvl_color}" "${lvl_prefix}" "${lvl_sym}" "${lvl_msg}" "${lvl_nc}"
    fi

    if [[ $_FILELOGGER_ACTIVE == "true" ]]; then
        printf "%s %-25s %-10s %s\n" "${lvl_ts}" "${FUNCNAME[2]}" "[${lvl_str}]" "$lvl_msg" >> "$_LOG_FILE"
    fi
}

check_internet() {
    log_message "Checking connectivity..."
    if ping -c 4 -i 0.2 google.com 2>&1 | log_trace "(WEB)"; then
        log_message "Connected to the Internet" 1
    else
        log_and_exit "You are not connected to the Internet.
    Please check your connection and try again" "14"
    fi
}

check_user() {
    if [[ $EUID -ne 0 ]]; then
        log_and_exit "Insufficient privileges! This script must be run as root. Please use sudo ./$_SCRIPT" "2"
    else
        log_message "Script running as root" 1
    fi
}

display_usage() {
    cat <<EOF
${_COLOR_GRAY}
A set of post-installation methods tested on Pop!_OS 22.04 LTS.

  ${_COLOR_NC}USAGE:${_COLOR_GRAY}
  [sudo] ./${_SCRIPT} [OPTION]

  ${_COLOR_NC}OPTIONS:${_COLOR_GRAY}
  -h, --help                Display this help message.
  -p, --install-portables   Install/update portable applications (AppImages, etc).
  -v, --version             Display version info.

  ${_COLOR_NC}LOGS:${_COLOR_GRAY}
  --debug                   Print debug level logs.
  --trace                   Print trace level logs.

  ${_COLOR_NC}DOCUMENTATION & BUGS:${_COLOR_GRAY}
  Report bugs to:           https://github.com/simurqq/poppi/issues
  Documentation:            https://github.com/simurqq/poppi
  License:                  GPLv3
${_COLOR_NC}
EOF
}

dotfiles() {
    # add directory 'Portables' to $PATH
    if [[ -d ${_APPSDIR} ]] && [[ -f ${_PROFILE} ]]; then
        str_prt1=$(grep "^export PATH=\$PATH:$_APPSDIR" "${_PROFILE}")
        str_prt2=$(grep "^export PATH=\$PATH:\$HOME\/Portables" "${_PROFILE}")
        [[ -z $str_prt1 ]] && [[ -z $str_prt2 ]] && printf "\n%s\n" "export PATH=\$PATH:\$HOME/Portables" >> ${_PROFILE} && \
        log_message "Added ${_APPSDIR} to \$PATH" 1 || log_message "Directory ${_APPSDIR} already in \$PATH"
    fi

    source ${_PROFILE}
}

fetch_portable_urls(){
    # https://v.gd/curl_progress_bash

    local attempt bool_nofile bool_update content_length filesize http_code percentage

    attempt=1             # max no. of tries to get HTTP response before breaking the loop == 5
    bool_nofile=0         # local file availablity status
    bool_update=0         # local file update status
    content_length=0      # reported total file size
    http_code=0           # 200 == file exists
    percentage=0          # percentage of completed download

    # check remote file status
    while [ "$http_code" == 0 ] && [ "$content_length" == 0 ]
    do
        http_code=$(curl -sIL -w '%{http_code}' "${1}" -o /dev/null)
        content_length=$(curl -sIL "${1}" | grep "[Cc]ontent-[Ll]ength: [^0]" | awk '{print $2}' 2>&1)
        content_length=$(tr -d '\r' <<< $content_length) # 'bc' and 'printf' expect '\n', not '\r' @ the end of line
        [ "$http_code" == 200 ] && break
        (( attempt++ )) && (( attempt == 5 )) && break
    done

    # check local file status
    if [ -f "${_APPSDIR}/${2}" ]; then
        filesize=$(wc -c "${_APPSDIR}/${2}" | cut -d " " -f 1)
        [[ $filesize != $content_length ]] && bool_update=1 && \
        log_message "Newer version of '${2}' is available. Downloading..."
    else
        bool_nofile=1
    fi

    # download file only if at least two of these conditions met:
    # http code == 200   -> file exists on remote server
    # bool_nofile == 1   -> file doesn't exist on local computer
    # bool_update == 1   -> newer version of file available
    if [ "$http_code" == 200 ] && ([[ $bool_nofile == 1 ]] || [[ $bool_update == 1 ]]); then
        curl -sfL --output-dir "${_APPSDIR}" "${1}" -o "${2}" |
        while [ "$filesize" != "$content_length" ]
        do
            # wait until some portion of file written onto disk
            if [ -f "${_APPSDIR}/${2}" ]; then
                filesize=$(stat -c "%s" ${_APPSDIR}/${2})
                percentage=$(printf "%d" "$((100*$filesize/$content_length))")
                log_message "Downloading ${2}... $percentage%" 4
            fi
            sleep 1
        done

        # temporary solution. Detailed info: https://unix.stackexchange.com/a/545191
        filesize=$(stat -c "%s" ${_APPSDIR}/${2})
        [ "$filesize" -eq "$content_length" ] && log_message "Download complete for ${2}" 1 || log_message "Download incomplete for ${2}" 3
    else
        log_message "Skipping download for '${2}'..."
    fi
}

headline(){
    local char columns dash_size min_cols msg1 msg2 msg_size

    columns=$(tput cols)
    msg_size=13           # "POPPI v1.0", incl. spaces on both sides of text and versions 10+
    min_cols=22
    dash_size=$(( (${columns}-${msg_size})/2 ))
    msg1="POPPI v${_VERSION}"
    msg2="----- ${msg1} -----\n\n"
    char=":"

    if [[ columns -le ${min_cols} ]]; then
        printf "${_COLOR_GRAY}${msg2}${_COLOR_NC}"
    else
        printf "${_COLOR_GRAY}%0${dash_size}s" | tr " " ${char}
        printf " ${msg1} "
        printf "%0${dash_size}s" | tr " " ${char}
        printf "\n\n${_COLOR_NC}"
    fi
}

install_dependencies() {
    # installs packages in the array
    local packages=(awk curl)
    log_message "Installing dependencies: ${packages[*]}..."
    
    for i in "${packages[@]}"
        do
            which "${i}" 2>&1 | log_trace "(PCK)"
            if [[ $? -eq 0 ]]; then
                log_message "Dependency package '${i}' found"
            else
                apt -q -y --no-install-recommends install "${i}" 2>&1 | log_trace "(PCK)"
                if [[ $? -eq 0 ]]; then
                    log_message "Dependency package '${i}' installed" 1
                else
                    log_and_exit "Failed to install dependency package '${i}'.
    Please see the log file for more details." "21"
                fi
            fi
        done
}

install_portables(){
    # Audacity | CPU-X | DeadBeef | HW-Probe | Inkscape | KeepassXC | Neofetch
    # QBittorrent | SMPlayer | SQLite Browser | Styli.sh | VSCodium | YT-DLP
    
    local counter filename name total url 

    # create directory for portables and bookmark it to Nautilus
    if [ ! -d ${_APPSDIR} ]; then 
        if ! mkdir -p "${_APPSDIR}"; then
            log_and_exit "Failed to create directory ${_APPSDIR}" "25"
        else
            log_message "Created directory ${_APPSDIR}" 1
            if [ -f $_BOOKMARKS ]; then
                grep -q "file://${_APPSDIR}" ${_BOOKMARKS}
                if [ $? -eq 1 ]; then
                    printf "%s" "file://${_APPSDIR}" >> $_BOOKMARKS
                    log_message "Bookmarked folder ${_APPSDIR}" 1
                else
                    log_message "Bookmark for directory ${_APPSDIR} exists"
                fi
            else
                log_message "Failed to bookmark directory ${_APPSDIR}" 3
            fi
        fi
    else
        log_message "Directory ${_APPSDIR} exists"
    fi

    log_message "Initialising download of portables. Please wait..." 4

# .:. AUDACITY .:.

    url="$(curl -sfL 'https://api.github.com/repos/audacity/audacity/releases/latest' | grep "browser_download_url.*AppImage" | cut -d \" -f 4)"
    filename="audacity"
    
    if [[ $url =~ https\:\/\/.*\.AppImage ]]; then
        fetch_portable_urls $url $filename
    else
        log_message "Failed to download Audacity. Skipping..." 3
    fi

# .:. CPU-X .:.

    url="$(curl -sfL 'https://api.github.com/repos/X0rg/CPU-X/releases/latest' | grep "browser_download_url.*AppImage\"" | cut -d \" -f 4)"
    filename="cpux"
    
    if [[ $url =~ https\:\/\/.*\.AppImage ]]; then
        fetch_portable_urls $url $filename
    else
        log_message "Failed to download CPU-X. Skipping..." 3
    fi

# .:. DEADBEEF .:.

    url="$(curl -sfL 'https://deadbeef.sourceforge.io/download.html' | grep "GNU.*sourceforge.*tar.bz2/download" | cut -d \" -f 2)"
    filename="deadbeef"
    
    if [[ $url =~ https\:\/\/.*\.tar.bz2 ]]; then
        fetch_portable_urls $url $filename
    else
        log_message "Failed to download Deadbeef. Skipping..." 3
    fi

    # extract the contents of the downloaded tar file
    if [[ -f "${_APPSDIR}/${filename}" ]]; then  
        xDir=$(tar -jtf "${_APPSDIR}/$filename" | head -1 | cut -d "/" -f 1)
        tar -jxf "${_APPSDIR}/$filename" -C "${_APPSDIR}"
        rm "${_APPSDIR}/$filename"
        mv "${_APPSDIR}/$xDir" "${_APPSDIR}/deadbeef"
    else
        log_message "File ${filename} does not exist" 3
    fi

# .:. HW-PROBE .:.

   url="$(curl -sfL 'https://api.github.com/repos/linuxhw/hw-probe/releases/latest' | grep "browser_download_url.*AppImage" | cut -d \" -f 4 | sort | tail -1)"
   filename="hwprobe"
    
   if [[ $url =~ https\:\/\/.*\.AppImage ]]; then
       fetch_portable_urls $url $filename
   else
       log_message "Failed to download HW-Probe. Skipping..." 3
   fi

# .:. INKSCAPE .:.

   url="$(curl -sfL 'https://inkscape.org/release/all/gnulinux/appimage' | grep ".*\AppImage<" | cut -d \" -f 2 | tail -1 | sed 's/^/https:\/\/inkscape\.org/')"
   filename="inkscape"
    
   if [[ $url =~ https\:\/\/.*\.AppImage ]]; then
       fetch_portable_urls $url $filename
   else
       log_message "Failed to download Inkscape. Skipping..." 3
   fi

# .:. KEEPASSXC .:.

   url="$(curl -sfL 'https://keepassxc.org/download/#linux' | grep "AppImage\"" | cut -d \" -f 2)"
   filename="keepassxc"
    
   if [[ $url =~ https\:\/\/.*\.AppImage ]]; then
       fetch_portable_urls $url $filename
   else
       log_message "Failed to download KeePass-XC. Skipping..." 3
   fi

# .:. NEOFETCH .:.

    url="https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch"
    filename="neofetch"

    if [[ $url =~ https\:\/\/.*\\/neofetch ]]; then
        fetch_portable_urls $url $filename
    else
        log_message "Failed to download Neofetch. Skipping..." 3
    fi

# .:. QBITTORRENT .:.

    url="$(curl -sfL 'https://www.qbittorrent.org/download.php' | grep -P ".*sourceforge.*\d_x86_64\.AppImage\/download" | cut -d \" -f 4 | head -1)"
    filename="qbittorrent"
    
  
     if [[ $url =~ https\:\/\/.*\.AppImage ]]; then
         fetch_portable_urls $url $filename
     else
         log_message "Failed to download SMPlayer. Skipping..." 3
     fi

# .:. SQLITE BROWSER .:.

     url="$(curl -sfL 'https://api.github.com/repos/sqlitebrowser/sqlitebrowser/releases/latest' | grep "browser_download_url.*AppImage" | cut -d \" -f 4)"
     filename="sqlitebrowser"
    
     if [[ $url =~ https\:\/\/.*\.AppImage ]]; then
         fetch_portable_urls $url $filename
     else
         log_message "Failed to download SQLite Browser. Skipping..." 3
     fi

# .:. STYLI.SH .:.

    url="https://raw.githubusercontent.com/thevinter/styli.sh/master/styli.sh"
    filename="styli.sh"

    if [[ $url =~ https\:\/\/.*\.sh ]]; then
        fetch_portable_urls $url $filename
    else
        log_message "Failed to download Styli.sh. Skipping..." 3
    fi

# .:. VSCODIUM .:.

    url="$(curl -sfL 'https://api.github.com/repos/VSCodium/vscodium/releases/latest' | grep "browser_download_url.*AppImage\"" | cut -d \" -f 4)"
    filename="vscodium"
    
    if [[ $url =~ https\:\/\/.*\.AppImage ]]; then
        fetch_portable_urls $url $filename
    else
        log_message "Failed to download VSCodium. Skipping..." 3
    fi

# .:. YT-DLP .:.

    url="$(curl -sfL 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest' | grep "browser_download_url.*\/yt-dlp\"" | cut -d \" -f 4)"
    filename="ytdlp"
    
    if [[ $url =~ https\:\/\/.*\/yt-dlp ]]; then
        fetch_portable_urls $url $filename
    else
        log_message "Failed to download YT-DLP. Skipping..." 3
    fi

    # copy .desktop files
    total=$(ls ${_BASE_DIR}/data/launchers/* | wc -l)
    counter=0

    for f in ${_BASE_DIR}/data/launchers/*
    do
        if [[ -f $f ]]; then
            name=$(basename $f)
            cp $f $_USER_APPS
            chown ${_USER_ID}:${_USER_NAME} ${_USER_APPS}/${name} && chmod 774 ${_USER_APPS}/${name}    # set ownership and X permission to copied files only
            [[ $?==0 ]] && [[ -f ${_USER_APPS}/${name} ]] && \
            ((counter++)) || ffailed=$(printf "%s," ${_USER_APPS}/${name} | sed 's/,$//')               # remove last comma in string
        fi
    done
    
    if [[ $counter == $total ]]; then
        log_message "All desktop entries copied to $_USER_APPS and set X permissions OK" 1
    else
        log_message "Failed to copy and set X permissions for: $ffailed" 3
    fi
    
    # copy icon files
    total=$(ls ${_BASE_DIR}/data/icons/* | wc -l)
    counter=0

    for f in ${_BASE_DIR}/data/icons/*
    do
        name=$(basename $f)
        cp $f $_USER_ICONS
        chown ${_USER_ID}:${_USER_NAME} ${_USER_ICONS}/${name} && chmod 664 ${_USER_ICONS}/${name}      # set ownership and RW permission to copied files only
        [[ $?==0 ]] && [[ -f ${_USER_ICONS}/${name} ]] && \
        ((counter++)) || ffailed=$(printf "%s," ${_USER_ICONS}/${name} | sed 's/,$//')                  # remove last comma in string
    done
    
    if [[ $counter == $total ]]; then
        log_message "All icon files copied to $_USER_ICONS OK" 1
    else
        log_message "Failed to copy files: $ffailed" 3
    fi

    # set user and group permissions to the portables directory 
    chown -R ${_USER_ID}:${_USER_NAME} ${_APPSDIR} && \
    chmod -R 774 ${_APPSDIR} && \
    log_message "User ${_USER_NAME} granted RWX permissions for ${_APPSDIR}" 1 || \
    log_message "Failed to set permissions for ${_APPSDIR}" 3

}

    # Brave pre-requisites: https://brave.com/linux/
    # apt install apt-transport-https curl
    # curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    # echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list

    # sudo apt install brave-browser ffmpeg lm-sensors

    #~~ Microsoft Fonts ~~#
    # if [ -d /usr/share/fonts/truetype/ms-ttf/ ]; then
    #     echo -e "Microsoft fonts exist on your computer, move operation skipped.\n"
    # else
    #     pkgl_url=https://dx37.gitlab.io/dx37essentials/pkglist-x86_64.html
    #     font_url=https://dx37.gitlab.io/dx37essentials/x86_64
    #     file_id=ttf-ms-win10-10.0.*.zst
        
    #     ms_fonts="$(wget --no-check-certificate ${pkgl_url} -qO - | grep -Po "${file_id}")" # grep the specific file quietly and output to stdout {-O -} instead of folder
	#if [ ! -f ${ms_fonts} ]; then
	#    wget "${font_url}/${ms_fonts}"
	#fi
	
    #     mkdir ms-ttf
    #     tar --use-compress-program=unzstd -xf ${ms_fonts}
    #     find usr -type f -exec mv -i {} ms-ttf \;   # move files from '/usr/share/fonts/TTF' folder to 'ms-ttf' folder
    #     mv -i ms-ttf /usr/share/fonts/truetype/
    #     rm -rf usr .* 2>/dev/null
    #     fc-cache -Evr
    # fi

    # VS Code
    # https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64

    # chmod the files

log_and_exit() {
    local msg="$1"
    local code="${2:-1}"
    __logger_core "error" "$msg"
    exit "${code}"
}

log_message() {
    # accepts three (3) arguments
    # arg 1 : message
    # arg 2 : log level can be 0-info (default)
    #                          1-success
    #                          2-error
    #                          3-warning
    #                          other defaults to info.
    # arg 3 : format string spacing (default=22)
    # TODO: fails to print properly strings formatted as "bla bla bla array[@] bla bla bla"

    local desc fmt lvl __msg_string
    desc="${1}"
    fmt="%-${3:-22}s"
    lvl="${2:-0}"
    __msg_string="$(printf "${fmt}" "${desc}")"

    case ${lvl} in
    0) __logger_core "info" "${__msg_string}" ;;
    1) __logger_core "success" "${__msg_string}" ;;
    2) __logger_core "error" "${__msg_string}" ;;
    3) __logger_core "warn" "${__msg_string}" ;;
    4) __logger_core "progress" "${__msg_string}" ;;
    *) __logger_core "info" "${__msg_string}" ;;
    esac
}

log_trace() {
    local line msg
    # Adds timestamp to logs without using external utilities
    # Output will be automatically written to $_LOG_FILE
    # Arguments: 1
    # ARG -1: printf variable for formatting the log
    # Usage command | _add_timestamp_to_logs "$1"
    while IFS= read -r line; do
        __logger_core "trace" "$(printf "%s %s" "${1:-UNKNOWN}" "$line")"
    done
}

set_gsettings(){
# Discussion: https://www.reddit.com/r/gnome/comments/vz37z2
    declare -a arr_GS=( "org.gnome.calculator button-mode 'advanced'" \
                        "org.gnome.calculator show-thousands true" \
                        "org.gnome.desktop.input-sources per-window true" \
                        "org.gnome.desktop.input-sources sources \"[('xkb', 'us'), ('xkb', 'az'), ('xkb', 'ru'), ('xkb', 'ara')]\"" \
                        "org.gnome.desktop.input-sources xkb-options \"['terminate:ctrl_alt_bksp', 'grp:alt_shift_toggle', 'compose:sclk']\"" \
                        "org.gnome.desktop.interface clock-format '24h'" \
                        "org.gnome.desktop.interface clock-show-seconds true" \
                        "org.gnome.desktop.interface clock-show-weekday true" \
                        "org.gnome.desktop.privacy old-files-age 'uint32 7'" \
                        "org.gnome.desktop.privacy recent-files-max-age 30" \
                        "org.gnome.desktop.privacy remove-old-temp-files true" \
                        "org.gnome.desktop.privacy remove-old-trash-files true" \
                        "org.gnome.desktop.screensaver lock-enabled false" \
                        "org.gnome.desktop.session idle-delay 'uint32 0'" \
                        "org.gnome.desktop.wm.keybindings minimize \"['<Super>z']\"" \
                        "org.gnome.desktop.wm.keybindings show-desktop \"['<Super>d']\"" \
                        "org.gnome.desktop.wm.preferences button-layout 'appmenu:close'" \
                        "org.gnome.gedit.preferences.editor insert-spaces true" \
                        "org.gnome.gedit.preferences.editor tabs-size 'uint32 4'" \
                        "org.gnome.GWeather4 temperature-unit 'centigrade'" \
                        "org.gnome.nautilus.preferences default-folder-viewer 'list-view'" \
                        "org.gnome.nautilus.list-view default-zoom-level 'small'" \
                        "org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 25" \
                        "org.gnome.shell.extensions.dash-to-dock dock-fixed false" \
                        "org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'" \
                        "org.gnome.shell.extensions.dash-to-dock extend-height false" \
                        "org.gnome.shell.extensions.dash-to-dock intellihide true" \
                        "org.gnome.shell.extensions.dash-to-dock show-mounts false" \
                        "org.gnome.shell.extensions.pop-cosmic clock-alignment 'CENTER'" \
                        "org.gnome.shell.extensions.pop-cosmic overlay-key-action 'LAUNCHER'" \
                        "org.gnome.shell.extensions.pop-cosmic show-applications-button false" \
                        "org.gnome.shell.extensions.pop-cosmic show-workspaces-button false"
                     )

    for i in "${arr_GS[@]}"
        do
            eval gsettings set "$i"
        done
}

system_check(){
    if [[ -r "${_OS_RELEASE_FILE}" ]]; then
        log_message "Found OS release file: ${_OS_RELEASE_FILE}"
        readonly DISTRO_PRETTY_NAME="$(awk '/PRETTY_NAME=/' "${_OS_RELEASE_FILE}" | sed 's/PRETTY_NAME=//' | tr -d '"')"
        readonly NAME="$(awk '/^NAME=/' "${_OS_RELEASE_FILE}" | sed 's/^NAME=//' | tr -d '"')"
        [[ ${NAME} != ${_OS} ]] && log_and_exit "Operating system mismatch: ${NAME}" "2"
        log_message "Operating system installed: ${DISTRO_PRETTY_NAME}"
    else
        log_and_exit "Failed to determine operating system!" "5"
    fi
}

screen_lock_status(){
    # disable screen lock during updates
    local isLocked=$(sudo -u $_USER_NAME gsettings get org.gnome.desktop.session idle-delay | awk '{print $2}')

    if [[ $isLocked -ne 0 ]]; then
        sudo -u $_USER_NAME $_USER_SESSION gsettings set org.gnome.desktop.session idle-delay 0
        [[ $? -eq 0 ]] && log_message "Screen-lock disabled temporarily" 1
    elif [[ $isLocked -eq 0 ]] && [[ $_IDLE_DELAY -eq 0 ]]; then
        log_message "Screen-lock disabled" 1
    fi
        
    # restore previous screen-lock value
    if [[ $_IDLE_DELAY -ne 0 ]]; then
        sudo -u $_USER_NAME $_USER_SESSION gsettings set org.gnome.desktop.session idle-delay $_IDLE_DELAY
        [[ $? -eq 0 ]] && log_message "Screen-lock enabled" 1
    fi

    _IDLE_DELAY=$isLocked
}

system_update(){
    # applies system-wide updates    
    screen_lock_status
    log_message "Performing system update..."
    pop-upgrade release upgrade | log_trace "(OS)"
    apt update && apt full-upgrade -y | log_trace "(APT)"

    if [[ $? -eq 0 ]]; then
        log_message "System update complete" 1
        screen_lock_status
    else
        log_message "System update failed and exited with error code: $?
        [1] This might be due to either missing keys or wrongly configured repositories, or
        [2] Repositories unavailable for your version of release.
        Script cannot proceed with this error." 2
        screen_lock_status
        exit 61
    fi

    # reboot required?
    if [[ -f /var/run/reboot-required ]]; then
        log_message "You must reboot to apply the updates. Exiting for now." 3
        exit
    fi
}

user_consent(){
    while true; do
    read -n 1 -p "${_COLOR_YELLOW}Running this script will make changes to your system. Continue? [Y|N] ${_COLOR_NC}" answer
        case $answer in
            [yY]) clear
            headline
            break ;;
            [nN]) clear
            exit ;;
            *) printf "\n\n${_COLOR_RED}Invalid response! Try again.\n\n"${_COLOR_NC};;
        esac
    done
}

main(){
    clear
    __init_vars
    headline
    user_consent
    log_message "Initialisation & checks"
    __init_logfile
    log_message "Permission checks"
    check_user
    check_internet
    system_check
    #system_update
    install_dependencies
    install_portables
    #install_repos
    #miscops
    #set_gsettings
    dotfiles
 }

# Launchpad
main "$@"
