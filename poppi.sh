#!/usr/bin/bash

#############################################################################################################
# Description:          	Post-installation routine tested on Pop!_OS 22.04 LTS                           #
# Github repository:    	https://github.com/simurqq/poppi                                                #
# License:              	GPLv3                                                                           #
# Author:               	Victor Quebec                                                                   #
# Date:                 	Feb 5, 2024                                                                    #
# Requirements:             Bash v4.2 and above                                                             #
#                           coreutils, jq, yasm                                                             #
# Notes:                    - commands marked with '#!#' (without single quotes) are customisable           #
#                           - check `main()` for the order of functions run upon script's Initialisation    #
#############################################################################################################

# shellcheck disable=SC2010

SECONDS=0

set -o pipefail # info: https://gist.github.com/simurq/38fadad2ce76ac6cdd62e38dec9e3da8

__init_logfile() {
    # Description:      creates a plain text file 'poppi.log' in the script location to record program and system reports,
    #                   backs up no more than five (5) such logs timestamped
    # Arguments:        none

    local bool_created_logfile

    if [ -f "$_LOGFILE"'.log' ]; then
        total_logs=$(ls -l "$_LOGFILE"_*.log 2>/dev/null | grep -c "^\-") # total log files

        if [[ $total_logs -ge 5 ]]; then                                                                                         # keep no more than 5 logs
            oldlog=$(find . -type f -name "$(basename "${_LOGFILE}")_*" -printf "%T@ %p\n" | sort -n | head -1 | cut -f2- -d" ") # locate the oldest log
            rm "$oldlog" 2>&1 | log_trace "(LGF)"                                                                                # FIFO rulez!
        fi

        mv "$_LOGFILE"'.log' "$_LOGFILE"'_'"$(date +'%d%m%Y_%H%M%S')"'.log' 2>&1 | log_trace "(LGF)" # back up the existing file
    fi

    # no log? create it
    if ! [[ -f "$_LOGFILE"'.log' ]]; then
        if touch "$_LOGFILE"'.log' 2>&1 | log_trace "(LGF)"; then
            bool_created_logfile="true"
        else
            log_and_exit "Failed to create logfile!" 2
        fi
    fi

    # check if the log file is writable and exit, if not
    if [[ -w "$_LOGFILE"'.log' ]]; then
        if touch "$_LOGFILE"'.log' 2>&1 | log_trace "(LGF)"; then
            _FILELOGGER_ACTIVE="true"
            [[ $bool_created_logfile == "true" ]] && log_message "Created log file: $_LOGFILE.log" 1
            log_message "Logging initialised" 1
        else
            _FILELOGGER_ACTIVE="false"
            log_and_exit "Failed to write to log file $_LOGFILE.log" 3
        fi
    else
        log_and_exit "Log file $_LOGFILE.log is not writable!" 4
    fi
}

__init_vars() {
    # Description:      sets initial global variables
    # Caution:          avoid changing the order of initialisation due to variable dependencies

    # global constants
    _BASEDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)                             # script directory
    _BFILE="$_BASEDIR/data/misc/bookmarks.txt"                                         # favourite user paths
    _DFTRMPRFL=$(gsettings get org.gnome.Terminal.ProfilesList default | sed "s/'//g") # default terminal profile
    _DISPLAY="DISPLAY=${DISPLAY}"                                                      # by default = :1
    _DRIVES=('Seagate' 'BackupDrive')                                                  # USB drives to mount from /etc/fstab #!#
    _EXEC_START=$(date +%s)                                                            # script launch time
    _LOGFILE="$_BASEDIR/poppi"                                                         # log file
    _OS="Pop!_OS"                                                                      # operating system
    _OS_RELEASE_FILE="/etc/os-release"                                                 # file with OS info
    _PERMS="$_BASEDIR/data/firefox/permissions.txt"                                    # Firefox cookies to keep
    _SCRIPT=$(basename "$0")                                                           # this script
    _USERNAME=$(whoami)                                                                # user name
    _USERHOME="/home/$_USERNAME"                                                       # user home directory
    _USERID=$(id -u "$_USERNAME")                                                      # user login id
    _USERSESSION="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${_USERID}/bus"
    _APPSDIR="$_USERHOME/Portables" # location of portable programs
    _BASHRC="$_USERHOME"/.bashrc
    _GTKBKMRK="$_USERHOME"/.config/gtk-3.0/bookmarks
    _FFXADDONSURL="https://addons.mozilla.org/addon" # main website to download Firefox addons
    _FFXAPPINI="/usr/lib/firefox/application.ini"
    _FFXCHANNEL="/usr/lib/firefox/defaults/pref/channel-prefs.js"
    _FFXDIR="$_USERHOME/.mozilla/firefox"
    _PROFILE="$_USERHOME"/.profile
    _USERAPPS="$_USERHOME"/.local/share/applications                 # .desktop launchers for portable programs
    _USERICONS="$_USERHOME"/.local/share/icons/hicolor/scalable/apps # icons for portable programs
    _GTKEXTS="$_USERHOME"/.local/share/gnome-shell/extensions        # default location for GNOME extensions
    _VERSION="0.9"                                                   # script version
    _WALLPPR="$_USERHOME"/Pictures/Wallpapers                        # user's wallpaper directory

    # display colours
    _CGRAY=$'\e[38;5;245m'
    _CPOPGRN=$'\e[38;2;78;154;10m'
    _CRED=$'\e[31m'
    _CYELLOW=$'\e[0;49;33m'
    _CPOPBLU=$'\e[38;2;72;185;199m'
    _CNONE=$'\e[0m'

    # miscellaneous
    bool_drv_bookmarked='false'   # mounted drive status in /etc/fstab
    _FILELOGGER_ACTIVE="false"    # log file status
    _FFXPRF=""                    # Firefox default profile directory
    _isLOCKED=0                   # screenlock status
    _SCREENLOCK=0                 # screenlock period of inactivity
    _POWERMODE='off'              # auto-suspend on/off
    _STRLEN=$(($(tput cols) - 5)) # width of field to print the log message; slightly less than terminal width to avoid string duplication
    _XID=""                       # Firefox extension ID

    readonly _APPSDIR _BASEDIR _BASHRC _BFILE _GTKBKMRK _CGRAY _CPOPGRN _CRED _CYELLOW _EXEC_START _FFXADDONSURL \
        _FFXAPPINI _FFXCHANNEL _FFXDIR _LOGFILE _CNONE _OS _OS_RELEASE_FILE _PROFILE _SCRIPT _USERAPPS \
        _USERHOME _USERICONS _USERID _USERNAME _USERSESSION _VERSION
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
        declare lvl_nc="${_CNONE}"

        case ${lvl} in
        info)
            declare -r lvl_str="INFO"
            declare -r lvl_sym="•"
            declare -r lvl_color="${_CGRAY}"
            ;;
        success)
            declare -r lvl_str="SUCCESS"
            declare -r lvl_sym="✓"
            declare -r lvl_color="${_CPOPGRN}"
            ;;
        trace)
            declare -r lvl_str="TRACE"
            declare -r lvl_sym="~"
            declare -r lvl_color="${_CGRAY}"
            ;;
        warn | warning)
            declare -r lvl_str="WARNING"
            declare -r lvl_sym="!"
            declare -r lvl_color="${_CYELLOW}"
            ;;
        error)
            declare -r lvl_str="ERROR"
            declare -r lvl_sym="✗"
            declare -r lvl_color="${_CRED}"
            ;;
        progress)
            declare -r lvl_str="PROGRESS"
            declare -r lvl_sym="»"
            declare -r lvl_color="${_CGRAY}"
            lvl_console="0"
            ;;
        prompt)
            declare -r lvl_str="PROMPT"
            declare -r lvl_sym="⸮"
            declare -r lvl_color="${_CYELLOW}"
            lvl_console="2"
            ;;
        stage)
            declare -r lvl_str="STAGE"
            declare -r lvl_sym="—"
            declare -r lvl_color="${_CPOPBLU}"
            ;;
        esac
    fi

    if [[ $lvl_console -eq 1 ]]; then
        printf "\r%s%s%s %s %s\n" "${lvl_color}" "${lvl_prefix}" "${lvl_sym}" "${lvl_msg}" "${lvl_nc}"
    elif [[ $lvl_console -eq 2 ]]; then
        printf "%s%s%s %s %s" "${lvl_color}" "${lvl_prefix}" "${lvl_sym}" "${lvl_msg}" "${lvl_nc}"
    else
        printf "\r%s%s%s %s %s\r" "${lvl_color}" "${lvl_prefix}" "${lvl_sym}" "${lvl_msg}" "${lvl_nc}" # progress reports on the same line ('\r')
    fi

    if [[ $_FILELOGGER_ACTIVE == "true" ]]; then
        printf "%s %-25s %-10s %s\n" "${lvl_ts}" "${FUNCNAME[2]}" "[${lvl_str}]" "$lvl_msg" >>"$_LOGFILE"'.log'
    fi
}

bytes_to_human() {
    # Description:      converts bytes to human-readable format. Used in `fetch_file()`.

    local bytes=$1
    local size=('B' 'KB' 'MB' 'GB' 'TB')
    local factor=1024
    local count=0

    while [[ $bytes -gt $factor ]]; do
        bytes=$((bytes / factor))
        count=$((count + 1))
    done

    echo "${bytes}${size[$count]}"
}

check_internet() {
    if misc_connect_wifi; then
        log_message "Checking connectivity ..." 5
        if ping -c 4 -i 0.2 duckduckgo.com >/dev/null 2>&1 | log_trace "(WEB)"; then
            log_message "Connected to the Internet" 1
        else
            log_and_exit "You are not connected to the Internet,
    please check your network connection and try again." 5
        fi
    fi
}

check_user() {
    if [[ $EUID -eq 0 ]] || [[ $EUID -ne $_USERID ]]; then
        log_and_exit "This script must be run by '$_USERNAME'.
    Otherwise it can result in irreversible system-wide changes" 6
    else
        log_message "Script run by '$_USERNAME'" 1
    fi
}

display_usage() {
    cat <<EOF
${_CGRAY}
A set of post-installation methods tested on Pop!_OS 22.04 LTS.

  ${_CNONE}USAGE:${_CGRAY}
  [sudo] ./${_SCRIPT} [OPTIONS: -[acfghprvx]]

  ${_CNONE}OPTIONS:${_CGRAY}
  -a, --all                 Download, install and set everything
  -b, --bookmark            Bookmark select directories to GNOME Files aka Nautilus
  -c, --connect             Check and configure Wi-Fi connection
  -d, --dock                Set your favourite programs on the dock
  -f, --set-firefox         Configure options for Firefox
  -g, --set-gsettings       Set GNOME GSettings
  -h, --help                Display this help message
  -p, --set-portables       Install/update portable programs
  -r, --set-repos           Install/update non-portable programs
  -u, --update              Update the system
  -v, --version             Display version info
  -x, --gnome-extensions    Get and enable GNOME extensions

  ${_CNONE}LOGS:${_CGRAY}
  --trace                   Print trace level logs.

  ${_CNONE}DOCUMENTATION & BUGS:${_CGRAY}
  Report bugs to:           https://github.com/simurqq/poppi/issues
  Documentation:            https://github.com/simurqq/poppi
  License:                  GPLv3
${_CNONE}
EOF
}

display_version() {
    cat <<EOF
${_CGRAY}Pop!_OS Post-Installation (POPPI) version $_VERSION
Copyright (C) 2024 Victor Quebec
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Vüqar Quliyev aka Victor Quebec in the sunny city of Baku, Azerbaijan.${_CNONE}
EOF
}

# shellcheck disable=SC2128
fetch_file() {
    # https://v.gd/curl_progress_bash
    # Accepts 3 arguments:
    # - URL of file to download         $1 'required'
    # - Name of file to download        $2 'optional'
    # - Location of downloaded file     $3 'optional'
    #
    # Downloads files only if the following conditions are true:
    # - file does not exist locally
    # - no reported file size ($content-length)
    # - actual file size does not match the reported file size (update)

    local content_length curl_output fetch filesize http_code loc percentage

    if [ $# -lt 1 ] && [ $# -gt 3 ]; then
        log_and_exit "Check arguments for $FUNCNAME()" 7
    fi

    if ! curl -sfIL "${1}" >/dev/null; then
        log_and_exit "ERR: $FUNCNAME() argument 1 not a valid URL" 15
    fi

    url=${1}
    filename=${2:-$(basename "${1}")}
    loc=${3:-$_BASEDIR} # default download location, if ${3} missing

    if [ $# -eq 1 ]; then
        fetch="curl -sfLC - --output-dir $loc $url -O"
    else
        fetch="curl -sfLC - --output-dir $loc $url -o $filename"
    fi

    curl_output=$(curl -sIL "$url" 2>&1)                                                               # contents of cURL
    content_length=$(grep -i "content-length: [^0]" <<<"$curl_output" | awk '{print $2}' | tr -d '\r') # reported total file size + 'bc' and 'printf' expect '\n', not '\r' @ the end of line
    http_code=$(grep -i "http.*200" <<<"$curl_output" | cut -d' ' -f2)                                 # 200 == file exists on server

    if [ -z "$content_length" ]; then # content size reported empty
        content_length=0
    fi

    #-- check local file status --#
    if [ -f "$loc/$filename" ]; then
        filesize=$(stat -c '%s' "$loc/$filename")
        [[ $filesize != "${content_length}" ]] && log_message "Updating download for '$filename'..." 4 "$_STRLEN"
    fi

    #-- actual download --#
    if [ "$http_code" == 200 ]; then # file exists on server
        filesize=1                   # to start the download; otherwise both filesize and content_length equal to zero
        prevsize=0
        eval "$fetch" | while [ "$filesize" != "$content_length" ]; do # for explanation: https://pastebin.com/tW5MnQgx
            if [ -f "$loc/$filename" ]; then                           # wait until file portion written onto disk
                filesize=$(stat -c '%s' "$loc/$filename")
                filesizeh=$(bytes_to_human "$filesize")
                if [ "$content_length" -gt 0 ]; then
                    percentage=$(printf "%d" "$((100 * filesize / content_length))")
                    log_message "Downloading '$filename' ... $filesizeh ($percentage%)" 4 "$_STRLEN"
                else
                    log_message "Downloading '$filename' ... $filesizeh" 4 "$_STRLEN"

                    # remember what's been downloaded so far to compare and break the loop after 5 checks of `filesize` size
                    if (("$prevsize" == "$filesize")); then
                        ((k++))
                        if (("$k" == 5)); then
                            break
                        fi
                    fi
                    prevsize="$filesize"
                fi
            fi
            sleep 1
        done
    else
        log_message "No file on server? Skipping download for '$filename'..."
    fi
}

ff_permissions() {
    if [ -f "$_PERMS" ]; then
        dbfile="permissions.sqlite"
        # Use a Python script to interact with the SQLite database
        python3 <<EOF
import sqlite3

conn = sqlite3.connect('$dbfile')   # connect to the SQLite database
c = conn.cursor()                   # create a cursor object

# Required by Firefox
c.execute("PRAGMA user_version = 12;")
c.execute("PRAGMA page_size = 32768;")
c.execute("VACUUM;")

# Create table moz_hosts
c.execute('''CREATE TABLE IF NOT EXISTS moz_hosts
             (id INTEGER PRIMARY KEY,
              host TEXT,
              type TEXT,
              permission INTEGER,
              expireType INTEGER,
              expireTime INTEGER,
              modificationTime INTEGER,
              isInBrowserElement INTEGER)''')

# Create table moz_perms
c.execute('''CREATE TABLE IF NOT EXISTS moz_perms
             (id INTEGER PRIMARY KEY,
              origin TEXT UNIQUE,
              type TEXT,
              permission INTEGER,
              expireType INTEGER,
              expireTime INTEGER,
              modificationTime INTEGER)''')

# Insert a row of data
$(while read -r url; do
            [ -n "$url" ] && echo "if not c.execute(\"SELECT 1 FROM moz_perms WHERE origin = ?\", (\"$url\",)).fetchone():
    c.execute(\"INSERT INTO moz_perms (origin, type, permission, expireType, expireTime, modificationTime) VALUES (?, 'cookie', 1, 0, 0, $_EXEC_START)\", (\"$url\",))"
        done <"$_PERMS")

conn.commit()   # save (commit) the changes
conn.close()    # close the connection
EOF
    fi

    if [ -f ./permissions.sqlite ]; then
        mv ./permissions.sqlite "$_FFXDIR/$_FFXPRF" # move the newly created file to Firefox profile
    fi
}

get_gnome_extensions() {
    log_message "Initialising the installation of GNOME extensions ..."
    check_internet

    if which gnome-extensions >/dev/null 2>&1 | log_trace "(GNM)"; then
        declare -a extensions=("GSConnect|https://extensions.gnome.org/extension-data/gsconnectandyholmes.github.io.v50.shell-extension.zip"
            "Transparent Top Bar|https://extensions.gnome.org/extension-data/transparent-top-barftpix.com.v16.shell-extension.zip"
            "OpenWeather|https://extensions.gnome.org/extension-data/openweather-extensionjenslody.de.v118.shell-extension.zip")
        temp_dir=$(mktemp -d)

        for item in "${extensions[@]}"; do
            title=$(echo "$item" | cut -d'|' -f1)
            url=$(echo "$item" | cut -d'|' -f2)
            filename=$(basename "$url")

            fetch_file "$url" "$filename" "$temp_dir"

            if gnome-extensions install --force "$temp_dir/$filename" 2>&1 | log_trace "(GNM)"; then
                log_message "GNOME extension '$title' installed" 1 "$_STRLEN"
            else
                log_message "Failed to install GNOME extension '$title'" 3 "$_STRLEN"
            fi
        done

        rm -rf "$temp_dir" 2>&1 | log_trace "(GNM)"
    else
        log_message "Failed to locate GNOME Extensions Manager. Skipping ..."
        return
    fi
}

headline() {
    local char columns dash_size min_cols msg1 msg2 msg_size

    columns=$(tput cols)
    min_cols=22
    msg1="POPPI v${_VERSION}"
    msg2="::::: ${msg1} :::::\n\n"
    msg_size=$((${#msg1} + 3)) # incl. spaces on both sides of text and versions 10+, i.e., extra 3 chars
    dif=$((columns - msg_size))
    dash_size=$((dif / 2))
    [ $(("$dif" % 2)) -gt 0 ] && dash_size=$((dash_size + 1)) # normalise dash size when 'dif' is an odd number
    char=":"

    if [[ columns -le ${min_cols} ]]; then
        printf '%s' "${_CGRAY}${msg2}${_CNONE}"
    else
        printf "${_CGRAY}%0${dash_size}s" | tr " " ${char}
        printf '%s' " ${msg1} "
        printf "%0${dash_size}s" | tr " " ${char}
        printf '\n\n%s' "${_CNONE}"
    fi
}

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

    local desc lvl __msg_string
    desc="${1}"
    lvl="${2:-0}"
    __msg_string=$(printf "%-${3:-22}s" "$desc")

    case ${lvl} in
    0) __logger_core "info" "${__msg_string}" ;;
    1) __logger_core "success" "${__msg_string}" ;;
    2) __logger_core "error" "${__msg_string}" ;;
    3) __logger_core "warn" "${__msg_string}" ;;
    4) __logger_core "progress" "${__msg_string}" ;;
    5) __logger_core "stage" "${__msg_string}" ;;
    6) __logger_core "prompt" "${__msg_string}" ;;
    *) __logger_core "info" "${__msg_string}" ;;
    esac
}

log_trace() {
    local line
    # Adds timestamp to logs without using external utilities
    # Output will be automatically written to $_LOGFILE
    # Arguments: 1
    # ARG -1: printf variable for formatting the log
    # Usage command | _add_timestamp_to_logs "$1"

    while IFS= read -r line; do
        if ! pgrep "apt-get" >/dev/null && grep -Eq '[0-9]*\.?[0-9]+%' <<<"$line"; then # supress progress reports from 'calibre', 'flatpak', etc.
            pr=$(grep -Eo '[0-9]*\.?[0-9]+%' <<<"$line" | cut -d\. -f1)                 # by converting floating point numbers to whole ones concatenated with a percentage sign
            log_message "Processing, please wait ... $pr" 4 "$_STRLEN"
        elif [[ "$line" =~ [WE]: ]]; then # check for warnings [W] and errors [E] in apt
            log_and_exit "Try re-running the script in a few minutes" 8
        else
            __logger_core "trace" "$(printf "%s %s" "${1:-UNKNOWN}" "$line")"
        fi
    done
}

misc__do_bookmarks() {
    # Attention: must be executed after misc_automount_drives()!
    paths="${1}"
    declare -A bookmarks

    while IFS= read -r line; do
        bookmarks["$line"]=1
    done <"${_GTKBKMRK}"

    process_path() {
        local path="$1"

        #if [ -d "$path" ]; then
        if [ $bool_drv_bookmarked = 'true' ]; then
            if [[ -z ${bookmarks["file://${path}"]} ]]; then # the same path is not bookmarked already
                printf "%s\n" "file://${path}" >>"${_GTKBKMRK}"
                log_message "Bookmarked directory '$path'" 1
            else
                log_message "Directory '$path' already bookmarked"
            fi
        else
            log_message "Directory '$path' does not exist. Skipping ..."
        fi
    }

    if [ -f "$paths" ]; then # read contents of ./data/misc/bookmarks.txt
        while IFS= read -r line; do
            process_path "$line"
        done <"$paths"
    else
        echo "$paths" | tr ';' '\n' | while IFS= read -r path; do # read user input
            process_path "$path"
        done
    fi
}

misc__do_wallpapers() {
    wppaths=()

    if mkdir -p "$_WALLPPR" 2>&1 | log_trace "(MSC)"; then
        log_message "POPPI will copy your wallpapers from one of these sources to '$_WALLPPR':"

        # pack the output of the `find` command into an array
        while IFS= read -r line; do
            ((i++))
            wppaths+=("$line")
            log_message "$i) $line"
        done < <(sudo find / -iname 'wallpapers' -type d 2>/dev/null) # for differences between piping and command expansion, see: https://sl.bing.net/cAvuQ96tlK0

        if [[ ${#wppaths[@]} -gt 0 ]]; then
            echo
            while true; do
                if ((i > 1)); then # more than one 'Wallpapers' directory found
                    log_message "Please select one [1-$i]:" 6
                    read -r -p "" num

                    if [[ $num =~ ^[0-9]+$ ]] && ((num > 0)) && ((num <= i)); then
                        src="${wppaths[$((num - 1))]}"
                        break
                    else
                        log_message "Invalid response! Try again." 2
                    fi
                else
                    log_message "Wallpapers will be copied to '${wppaths[0]}'."
                    src="${wppaths[0]}"
                    break
                fi
            done

            total=$(find "$src" -maxdepth 1 -type f -not -name '.*' -printf '.' | wc -c) # number of files in directory

            if ((total > 0)); then
                files=()

                for f in "$src"/*; do
                    if [ -f "$f" ]; then # pack array with files only
                        files+=("$f")
                    fi
                done

                for f in "${files[@]}"; do
                    if cp "$f" "$_WALLPPR" 2>&1 | log_trace "(MSC)"; then
                        ((count++))
                        log_message "Copied $count of $total files, please wait ..." 4
                    else
                        ((count = 0))
                    fi
                done

                log_message "Copied $count of $total wallpaper files" 1 "$_STRLEN"
            else
                [ -d "$_WALLPPR" ] && rm -r "$_WALLPPR" 2>&1 >/dev/null | log_trace "(MSC)"
                log_message "Nothing to copy. Skipping ..."
            fi
        else
            [ -d "$_WALLPPR" ] && rm -r "$_WALLPPR" 2>&1 >/dev/null | log_trace "(MSC)"
            log_message "Nothing to copy. Skipping ..."
        fi
    else
        log_message "Failed to create directory '$_WALLPPR'. Skipping ..." 3
    fi
}

misc_automount_drives() {
    # Description: adds the mounted external drives to /etc/fstab
    log_message "[+] Auto-mounting external drives ..." 5
    if sudo test -w /etc/fstab; then
        if sudo cp /etc/fstab /etc/fstab.bak 2>&1 | log_trace "(MSC)"; then # backup the file
            log_message "File '/etc/fstab' backed up" 1

            for drv in "${_DRIVES[@]}"; do
                if mount | grep -q "$drv"; then # check mount status
                    line=$(mount | grep "$drv")
                    drvcode=$(echo "$line" | grep -oP '/dev/\K\w+') # sdX#
                    mountpnt=$(grep -o "/mnt/$drv" /etc/fstab)      # drive location in /etc/fstab
                    uuid=$(sudo blkid -s UUID -o value "/dev/$drvcode")

                    if [ "$mountpnt" != "/mnt/$drv" ] && [ -d /mnt ]; then # because I like them mounted on /mnt; Attention: drive path also referenced in other functions!
                        { echo "UUID=$uuid /mnt/$drv auto nosuid,nodev,nofail,x-gvfs-show 0 0" | sudo tee -a /etc/fstab; } >/dev/null 2>&1 | log_trace "(MSC)" &&
                            # echo "/dev/disk/by-uuid/$uuid /mnt/$device_name auto nosuid,nodev,nofail,x-gvfs-show 0 0" | sudo tee -a /etc/fstab
                            echo "file:///mnt/$drv $drv" >>"$_GTKBKMRK" &&
                            bool_drv_bookmarked='true' && # TODO: adjust the logic to retain the variable's value for multiple drives
                            log_message "External drive '$drv' mounted and bookmarked"
                    else
                        log_message "External drive '$drv' auto-mounts anyway. Skipping ..."
                    fi
                else
                    log_message "External drive '$drv' not mounted. Skipping ..." 3
                fi
            done
        else
            log_message "Failed to back up '/etc/fstab'. Skipping ..." 3
        fi
    else
        log_message "File '/etc/fstab' is not writable. Skipping ..." 3
    fi
}

misc_bookmark_dirs() {
    log_message "[+] Bookmarking select directories ..." 5

    if [ -f "$_GTKBKMRK" ]; then
        while true; do
            log_message "Would you like to bookmark your favourite directories to GNOME Files (Nautilus)? [Y|N]" 6
            read -r -n 1 -p "" answer
            echo
            case $answer in
            [yY])
                if [ -f "$_BFILE" ]; then
                    log_message "Bookmarks file found: $_BFILE" 1
                    misc__do_bookmarks "$_BFILE"
                else
                    log_message "Please enter the paths separated by a semi-colon [;]:" 6
                    read -r -p "" paths
                    misc__do_bookmarks "$paths"
                fi
                break
                ;;
            [nN])
                printf "\n"
                break
                ;;
            *) log_message "Invalid response! Try again." 2 ;;
            esac
        done
    else
        log_message "Failed to bookmark directory(-ies)" 3
    fi
}

misc_change_user_avatar() {
    log_message "[+] Changing user avatar on login page ..." 5
    if sudo test -r /var/lib/AccountsService/users/"$_USERNAME" && test -f /usr/share/pixmaps/faces/plane.jpg; then #! custom avatar image
        user_file='/var/lib/AccountsService/users/'"$_USERNAME"
        avatar='/usr/share/pixmaps/faces/plane.jpg' #! custom avatar image
        sudo sed -i "/Icon/c\Icon=$avatar" "$user_file" 2>&1 | log_trace "(MSC)"
        log_message "Avatar for user '$_USERNAME' changed" 1
    else
        log_message "Cannot change avatar for user '$_USERNAME'. Skipping ..." 3
    fi
}

misc_connect_wifi() {
    local bool_connected_wifi
    bool_connected_wifi=$(nmcli -t -f NAME connection show --active)

    if [ -z "$bool_connected_wifi" ]; then # no active wi-fi connection
        log_message "[+] Scanning for available Wi-Fi networks ..." 5
        IFS=$'\n'
        mapfile -t SSIDS < <(nmcli -t -f SSID dev wifi) # append network names to an array

        # list available Wi-Fi networks
        for i in "${!SSIDS[@]}"; do
            log_message "$((i + 1)).${SSIDS[$i]}"
        done

        log_message "Please select the Wi-Fi network you want to connect to [1-$i]: " 6
        read -r -p "" nomre
        SSID=${SSIDS[$((nomre - 1))]}
        log_message "Please enter your Wi-Fi password: " 6
        read -r -s wifi_pass
        nmcli dev wifi connect "$SSID" password "$wifi_pass" 2>&1 | log_trace "(MSC)"
    fi
}

misc_gnome_calc_custom_functions() {
    gcalc="$_USERHOME/.local/share/gnome-calculator"

    if [ -f "$_BASEDIR"/data/misc/custom-functions ] && mkdir "$gcalc"; then
        log_message "[+] Copying user-defined functions for GNOME Calculator ..." 5
        cp "$_BASEDIR"/data/misc/custom-functions "$gcalc" 2>&1 | log_trace "(MSC)"
        log_message "User-defined functions for GNOME Calculator copied." 1
    else
        log_message "Cannot copy user-defined functions for GNOME Calculator. Skipping ..." 3
    fi
}

misc_set_crontab() {
    # TODO: ask user to enter locations to rsync instead of hardcoded personal locations
    # https://www.reddit.com/comments/131s1bb//ji1xucu/
    log_message "[+] Setting up crontab for user '$_USERNAME' ..." 5
    declare -a cronline

    if [ -d "$_WALLPPR" ] && [ -f "$_APPSDIR/styli.sh" ]; then
        cronline+=("0 23 * * * $_DISPLAY $_USERSESSION $_APPSDIR/styli.sh -g -d $_WALLPPR")
    fi

    if which fsearch 2>&1 >/dev/null | log_trace "(MSC)"; then
        cronline+=("1 23 * * * fsearch -u >> $_APPSDIR/cron-jobs.log 2>&1")
    fi

    if touch "$_BASEDIR"/data/misc/rsync-script.sh 2>&1 | log_trace "(MSC)"; then
        cd "$_BASEDIR"/data/misc || return
        # shellcheck disable=SC2016
        {
            printf '%s\n\n' '#!/usr/bin/env bash'
            printf '%s\n' 'printf "\n%s\n" "$(date)" >> '"$_APPSDIR"'/sync-script.log'
            printf '%s\n' 'rsync -acuv --delete /mnt/'"${_DRIVES[0]}"'/ /mnt/'"${_DRIVES[1]}"'/Seagate/ >>'"$_APPSDIR"'/sync-script.log'
        } >>"./rsync-script.sh"
        mv "./rsync-script.sh" "$_APPSDIR/rsync-script.sh" 2>&1 | log_trace "(MSC)"
        cronline+=("3 23 * * * /bin/sh $_APPSDIR/rsync-script.sh >> $_APPSDIR/cron-jobs.log 2>&1")
    fi

    for i in "${cronline[@]}"; do
        printf "%s\n" "$i" >>"$_BASEDIR/temp_crontab"
    done

    sudo -u "$_USERNAME" crontab "$_BASEDIR"/temp_crontab 2>&1 | log_trace "(MSC)" && log_message "Crontab tasks set up for user '$_USERNAME'"
    rm "$_BASEDIR"/temp_crontab 2>&1 | log_trace "(MSC)"
}

misc_set_geary() {
    log_message "[+] Setting up Geary email client ..." 5
    while true; do
        log_message "Do you want to set your e-mail account(s) with Geary now? [Y|N]" 6
        read -r -n 1 -p "" answer
        echo
        case $answer in
        [yY])
            if ! which geary 2>&1 | log_trace "(MSC)"; then
                log_message "Failed to locate Geary on this computer. Skipping ..." 3
            fi

            geary 2>&1 | log_trace "(MSC)"
            printf "\n"
            break
            ;;
        [nN])
            printf "\n"
            break
            ;;
        *) log_message "Invalid response! Try again." 2 ;;
        esac
    done
}

misc_set_gnome_themes() {
    # Nordic theme by Eliver Lara
    # TODO: rework similar to set_portables()

    log_message "[+] Setting up GNOME themes ..." 5
    url='https://api.github.com/repos/EliverLara/Nordic/releases/latest'
    full_url=$(curl -sfL "$url" | jq -r ".assets[].browser_download_url" | grep -i "nordic\-bluish.*accent.tar.xz$")
    filename=$(basename "$full_url")
    theme='Nordic'
    cd "$_APPSDIR" || return

    [ -d "./$filename" ] && rm -r "./$filename" # to avoid error when dir and file with the same name exist

    if [ -n "$full_url" ]; then
        log_message "Downloading GNOME theme $theme ..."
        fetch_file "$full_url" "$filename" "$_APPSDIR"
    else
        log_message "Cannot download '$filename'. Skipping ..." 3
        return
    fi

    if mkdir -p "$_USERHOME/.themes"; then
        tar_extractor "$filename" "$theme" "$_USERHOME/.themes"
    else
        log_message "Cannot create directory for GNOME Themes" 3
        return
    fi

    gsettings set org.gnome.desktop.interface gtk-theme 'Nordic' &&
        gsettings set org.gnome.desktop.wm.preferences theme 'Nordic' &&
        gsettings set org.gnome.desktop.interface icon-theme 'Nordic' &&
        dconf write /org/gnome/terminal/legacy/profiles:/:"$_DFTRMPRFL"/use-theme-colors true && # terminal uses theme colours
        log_message "GNOME theme $theme set up" 1 "$_STRLEN"
}

misc_set_lo_themes() {
    #-- Sifr theme --#
    #-- original script: https://raw.githubusercontent.com/rizmut/libreoffice-style-sifr/master/install-sifr.sh
    log_message "[+] Setting up Sifr theme for LibreOffice ..." 5
    if which libreoffice >/dev/null 2>&1; then
        gh_repo="libreoffice-style-sifr"
        gh_desc="Sifr LibreOffice icon themes"
        temp_dir="$(mktemp -d)"
        log_message "Getting the latest version of ${gh_desc}..."
        sfrurl="https://github.com/rizmut/$gh_repo/archive/master.tar.gz"
        fetch_file $sfrurl "$gh_repo.tar.gz" /tmp && log_message "$gh_desc downloaded" 1

        #-- check file integrity --#
        if tar -tf "/tmp/$gh_repo.tar.gz" &>/dev/null; then
            log_message "Unpacking archive ..."
            tar -xzf "/tmp/$gh_repo.tar.gz" -C "$temp_dir" 2>&1 | log_trace "(MSC)"
            log_message "Deleting old $gh_desc ..."
            sudo rm -f "/usr/share/libreoffice/share/config/images_sifr.zip" 2>&1 | log_trace "(MSC)"
            sudo rm -f "/usr/share/libreoffice/share/config/images_sifr_dark.zip" 2>&1 | log_trace "(MSC)"
            sudo rm -f "/usr/share/libreoffice/share/config/images_sifr_dark_svg.zip" 2>&1 | log_trace "(MSC)"
            sudo rm -f "/usr/share/libreoffice/share/config/images_sifr_svg.zip" 2>&1 | log_trace "(MSC)"
            log_message "Installing $gh_desc ..."
            sudo mkdir -p "/usr/share/libreoffice/share/config" 2>&1 | log_trace "(MSC)"
            sudo cp -R "$temp_dir/$gh_repo-master/build/images_sifr.zip" \
                "/usr/share/libreoffice/share/config" 2>&1 | log_trace "(MSC)"
            sudo cp -R "$temp_dir/$gh_repo-master/build/images_sifr_dark.zip" \
                "/usr/share/libreoffice/share/config" 2>&1 | log_trace "(MSC)"
            sudo cp -R "$temp_dir/$gh_repo-master/build/images_sifr_dark_svg.zip" \
                "/usr/share/libreoffice/share/config" 2>&1 | log_trace "(MSC)"
            sudo cp -R "$temp_dir/$gh_repo-master/build/images_sifr_svg.zip" \
                "/usr/share/libreoffice/share/config" 2>&1 | log_trace "(MSC)"

            for dir in \
                /usr/lib64/libreoffice/share/config \
                /usr/lib/libreoffice/share/config \
                /usr/local/lib/libreoffice/share/config \
                /opt/libreoffice*/share/config; do
                [ -d "$dir" ] || continue
                sudo ln -sf "/usr/share/libreoffice/share/config/images_sifr.zip" "$dir" 2>&1 | log_trace "(MSC)"
                sudo ln -sf "/usr/share/libreoffice/share/config/images_sifr_dark.zip" "$dir" 2>&1 | log_trace "(MSC)"
                sudo ln -sf "/usr/share/libreoffice/share/config/images_sifr_svg.zip" "$dir" 2>&1 | log_trace "(MSC)"
                sudo ln -sf "/usr/share/libreoffice/share/config/images_sifr_dark_svg.zip" "$dir" 2>&1 | log_trace "(MSC)"
            done

            log_message "Clearing cache ..."
            rm -rf "/tmp/$gh_repo.tar.gz" "$temp_dir" 2>&1 | log_trace "(MSC)"
            log_message "Sifr theme for LibreOffice set" 1
        else
            log_message "File '$gh_repo.tar.gz' not found or damaged.
    Please download again" 3
        fi
    else
        log_message "Failed to locate LibreOffice on this computer" 3
    fi
}

misc_set_msfonts() {
    local fontdir pkglist

    log_message "[+] Setting up Microsoft fonts ..." 5
    fontdir="/usr/share/fonts/truetype/ms-fonts"

    if sudo mkdir -p $fontdir 2>&1 | log_trace "(MSC)"; then
        pkglist='https://dx37.gitlab.io/dx37essentials/pkglist-x86_64.html'
        dl_url='https://dx37.gitlab.io/dx37essentials/x86_64'
        fileid='ttf-ms-win10-10.0.*.zst'

        # set downloadable url
        fileid=$(curl -sL $pkglist | grep -oP "$fileid")
        tmpurl="$dl_url/$fileid"
        fetch_file "$tmpurl" "$fileid"

        if [ -f "$_BASEDIR/$fileid" ]; then
            sudo tar --strip-components=4 --directory="$fontdir" --use-compress-program=unzstd -xf "$_BASEDIR/$fileid" 2>&1 | log_trace "(FNT)"
            rm "$_BASEDIR/$fileid"
            fc-cache -Evr 2>&1 | log_trace "(FNT)"
        fi
    else
        log_message "Failed to create directory $fontdir" 3
    fi
}

misc_set_ninja_meson() {
    if which pip3 >/dev/null 2>&1 | log_trace "(MSC)"; then
        log_message "[+] Installing Ninja with Meson ..." 5
        pip3 install --user ninja meson | log_trace "(MSC)"

        # if [ -f "$_PROFILE" ]; then
        #     if ! grep -iq "home\/\.local/bin" <"$_PROFILE"; then # otherwise the apps throw a warning message
        #         printf "\n%s\n" "export PATH=\"\$HOME/.local/bin:\$PATH\"" >>"$_PROFILE"
        #         # shellcheck source=/dev/null
        #         source "$_PROFILE"
        #         log_message "Directory '$_USERHOME/.local/bin' added to \$PATH" 1
        #     else
        #         log_message "Directory '$_USERHOME/.local/bin' already set to \$PATH. Skipping ..."
        #     fi
        # else
        #     log_message "Failed to export '$_APPSDIR' to '$_PROFILE'" 3
        # fi

        log_message "Ninja and Meson installation complete" 1
    else
        log_message "Failed to install Ninja with Meson. Skipping ..." 3
    fi
}

misc_set_templates() {
    log_message "[+] Setting up template files ..." 5
    tmpl="$_BASEDIR/data/misc/template-files.tar.gz"
    if [ -f "$tmpl" ] && mkdir -p "$_USERHOME/Templates"; then
        log_message "Unpacking template files ..."
        tar -xzf "$tmpl" -C "$_USERHOME/Templates" 2>&1 | log_trace "(TPL)" 2>&1 | log_trace "(TPL)"
    else
        log_message "Failed to unpack template files" 3
    fi

    [ "${PIPESTATUS[0]}" -eq 0 ] && log_message "Template files unpacked to $_USERHOME/Templates" 1
}

misc_set_volume() {
    log_message "[+] Setting volume to max with over-amplification on ..." 5
    if gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true; then
        pactl set-sink-volume @DEFAULT_SINK@ 153% 2>&1 | log_trace "(MSC)" # max value 'amixer' shows when volume control set with mouse
        log_message "Volume set to max" 1
    else
        log_message "Failed to set volume to max" 3
    fi
}

misc_set_wallpapers() {
    log_message "[+] Setting up wallpapers ..." 5

    if [ -d "$_WALLPPR" ]; then
        log_message "Directory '$_WALLPPR' exists. Overwrite? [Y/N]:" 6
        read -r -n 1 -p "" answer

        case "$answer" in
        [Yy]) misc__do_wallpapers ;;
        [Nn])
            log_message "Nothing to do. Skipping ..." "" "$_STRLEN"
            return
            ;;
        *) ;;
        esac
    else
        misc__do_wallpapers
    fi
}

misc_set_weekday() {
    # alternative option might be `sudo sed -i -e 's:first_weekday\ 3:first_weekday\ 2:g' /usr/share/i18n/locales/en_US`,
    # but less preferred, as it assumes reverse engineering the en_US locale
    if [ "$LC_TIME" != 'en_GB.UTF-8' ] || ! grep -iq "export LC_TIME=.*en_gb\.utf\-8" <"$_PROFILE"; then
        log_message "[+] Setting the first day of the week to Monday ..." 5

        if ! locale -a | grep -iq "en_gb\.utf8"; then # generate a new locale
            sudo locale-gen en_GB.UTF-8 2>&1 | log_trace "(MSC)"
        fi

        printf '\n%s\n' 'export LC_TIME=en_GB.UTF-8' >>"$_PROFILE" 2>&1 | log_trace "(MSC)" &&
            log_message "First day of the week set to Monday." 1
    fi
}

miscops() {
    log_message "Initialising miscellaneous operations ..." 5
    local cronline

    misc_connect_wifi
    misc_set_volume
    misc_automount_drives
    misc_gnome_calc_custom_functions
    misc_set_weekday
    misc_bookmark_dirs
    misc_set_geary
    misc_set_wallpapers
    misc_set_msfonts
    misc_set_lo_themes
    misc_set_gnome_themes
    misc_set_templates
    misc_set_crontab
    misc_set_ninja_meson
}

screenlock() {
    # Description: Disables screen-lock and power suspend mode during system updates and re-enables them to previous (user) values when done.

    if [[ $_isLOCKED -eq 0 ]]; then
        # backup user values
        _SCREENLOCK=$(gsettings get org.gnome.desktop.session idle-delay | awk '{print $2}')
        _POWERMODE=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)

        gsettings set org.gnome.desktop.session idle-delay 'uint32 0' && # lock the screen and disable auto-suspend
            gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' &&
            _isLOCKED=1 &&
            log_message "Screen-lock and Auto-Suspend disabled" 1
    else
        gsettings set org.gnome.desktop.session idle-delay "uint32 $_SCREENLOCK" && # restore previous values
            gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "$_POWERMODE" &&
            _isLOCKED=0 &&
            log_message "Screen-lock and Auto-Suspend re-enabled" 1
    fi
}

set_configs() {
    if [ -d "$_BASEDIR"/data/configs ]; then
        cd "$_BASEDIR"/data/configs || return
        objs=$(ls -d .[a-zA-Z]*) # create a string containing dotfiles and dirs

        # shellcheck disable=SC2068
        for obj in ${objs[@]}; do
            cp -r "./$obj" "$_USERHOME" 2>&1 | log_trace "(CFG)" && log_message "Copied $obj to $HOME" 1
        done
    else
        log_message "Failed to locate directory '$_BASEDIR/data/configs'" 3
    fi

    # set and copy dotfiles
    if [ -d "$_BASEDIR"/data/dotfiles ]; then
        for obj in "$_BASEDIR"/data/dotfiles/.*; do
            [ -f "$obj" ] && cp "$obj" "$_USERHOME" 2>&1 | log_trace "(CFG)" && log_message "Copied $(basename "$obj") to $_USERHOME" 1
        done

        # shellcheck disable=SC1090
        source "$_PROFILE" "$_BASHRC"
    else
        log_message "Failed to locate directory '$_BASEDIR/data/dotfiles'" 3
    fi

    # configuration files for VSCodium Portable
    cd "$_BASEDIR"/data/configs_portables/vscodium || return
    if [ -d "$_APPSDIR"/vscodium ]; then
        cp -r "./data" "$_APPSDIR"/vscodium 2>&1 | log_trace "(CFG)" &&
            while read -r extension || [[ -n $extension ]]; do
                "$_APPSDIR"/vscodium/bin/codium --install-extension "$extension" --force 2>&1 | log_trace "(CFG)"
            done <"./extensions.txt" &&
            log_message "VSCodium set up" 1
    fi
}

set_dependencies() {
    # Description: Installs packages required to run POPPI properly
    local packages=(awk checkinstall curl flatpak jq libxcb-cursor0 python3 python3-pip yasm) # libxcb-cursor0 => lib for Calibre
    log_message "Installing dependencies ..." 5                                               # python3-pip => ninja & meson
    stop_packagekitd                                                                          # yasm => FFMPEG

    for i in "${packages[@]}"; do
        if ! which "${i}" >/dev/null; then
            if [[ ! $(dpkg -l | grep "${i}") =~ ^ii.*${i} ]]; then                                                          # check for binary or package installation report;
                if sudo apt-get -o=Dpkg::Use-Pty=0 -y --no-install-recommends install "${i}" 2>&1 | log_trace "(DEP)"; then # useful to prevent recurrant apt` reports
                    log_message "Dependency package '${i}' installed" 1
                else
                    log_and_exit "Failed to install dependency package '${i}'" 9
                fi
            fi
        fi
    done
}

set_favourites() {
    #-- add program icons to Favourites if assoc. programs available on the system --#
    # TODO: change logic [restart to enable ~/.profile entries?] to make deadbeef and vscode (extracted from zipped files) visible on the dock
    declare -a favourites=("firefox|firefox.desktop"
        "nautilus|org.gnome.Nautilus.desktop"
        "gnome-terminal|org.gnome.Terminal.desktop"
        "repoman|io.elementary.appcenter.desktop"
        "gnome-control-center|gnome-control-center.desktop"
        "deadbeef|deadbeef.desktop"
        "libreoffice|libreoffice-writer.desktop"
        "codium|codium.desktop"
        "audacity|audacity.desktop")

    for fav in "${favourites[@]}"; do
        fav1=${fav%|*} # 1st part of the array element
        fav2=${fav#*|} # 2nd part of the array element

        if which "$fav1" >/dev/null 2>&1 | log_trace "(FAV)" && [ -f "$_USERAPPS/$fav2" ] || [ -f /usr/share/applications/"$fav2" ]; then
            settings+="'$fav2', " # create a comma-separated string as a key-value pair for gsettings
        fi
    done

    settings='['${settings%,*}']' # remove last comma & append brackets
    gsettings set org.gnome.shell favorite-apps "$settings" 2>&1 | log_trace "FAV"
}

set_firefox() {
    # TODO:
    # make bookmarks with search engines ready (manually)
    # make extension settings ready (manually)

    # HOME=/tmp XAUTHORITY=/tmp firefox --version
    # or, /usr/lib/firefox/application.ini
    # or, apt-cache policy firefox
    # check release channel: /usr/lib/firefox/defaults/pref/channel-prefs.js:pref("app.update.channel", "release");
    log_message "Setting up Firefox ..." 5
    local channel counter ext_title ext_total ffv logstr url xid xpi_pathname xpi_list xpiURL

    # Firefox exists?
    if which firefox >/dev/null 2>&1 | log_trace "(FFX)"; then
        if [[ -f $_FFXAPPINI ]]; then
            ffv=$(grep "^Version" <"${_FFXAPPINI}" | cut -d= -f2 | cut -d\. -f1)

            # compatibility check
            if [[ $ffv -le 67 ]]; then
                log_message "Your version of Firefox is not compatible with this script.
    Please upgrade and re-run the script as './${_SCRIPT} -f' to apply Firefox settings." 3
                return 1
            fi

            if [[ -f "$_FFXCHANNEL" ]]; then
                channel=$(grep "channel" <"$_FFXCHANNEL" | cut -d \" -f4)
            else
                channel="undefined"
            fi

            log_message "Mozilla Firefox version: ${ffv}-${channel}"
        else
            log_message "Failed to determine Firefox version" 3
        fi
    else
        log_message "Mozilla Firefox not found" 3
        return 1
    fi

    # Firefox running?
    if pgrep "firefox" >/dev/null 2>&1; then
        log_message "Cannot proceed while Firefox is running.
    Please quit Firefox and re-run this script as './${_SCRIPT} -f' to apply Firefox settings." 3
        return 1
    fi

    # identify profile directory, method #1
    if [ -f "$_FFXDIR/profiles.ini" ]; then
        _FFXPRF=$(grep "[Default|Path]=.*\.default\-${channel}$" <"$_FFXDIR/profiles.ini" | cut -d= -f2 2>&1)
    elif [ -d "$_FFXDIR" ]; then
        # identify profile directory, method #2
        # useful when script re-launched after first run in the background
        # when Firefox doesn't append 'Default=1' to the [Profile0] section of 'profiles.ini' (method #1)
        log_message "Firefox profile not available. Retrying ..."
        _FFXPRF=$(basename "$(find "$_FFXDIR" -maxdepth 1 -name '*default*' 2>&1)")
    fi

    # all attempts failed, create a new profile
    if [ -z "$_FFXPRF" ]; then
        log_message "Firefox profile not available. Creating a new one ..."
        firefox -CreateProfile "default-$channel" 2>&1 | log_trace "(FFX)" && sleep 3
        _FFXPRF=$(basename "$(find "$_FFXDIR" -maxdepth 1 -name '*default*' 2>&1)")

        if [ -n "$_FFXPRF" ]; then
            log_message "Created Firefox profile: $_FFXPRF" 1

            # run in the background
            firefox --headless -P "default-$channel" 2>&1 | log_trace "(FFX)" &
            sleep 3
            log_trace "(FFX)" <<<"$(kill -9 "$(pidof firefox)" 2>&1 >/dev/null)"
        else
            log_message "Failed to create profile directory for unknown reason(s)" 3
            return 1
        fi
    else
        log_message "Firefox profile exists: $_FFXPRF" 1
    fi

    ff_permissions # create a custom file permissions.sqlite

    #-- download and install extensions --#
    if [ -d "$_FFXDIR/$_FFXPRF" ] && [ -f "${_BASEDIR}/data/firefox/xpi.lst" ]; then
        if mkdir -p "$_FFXDIR/$_FFXPRF/extensions"; then # create extensions directory
            xpi_list="${_BASEDIR}/data/firefox/xpi.lst"  # download extensions
            if [ -f "$xpi_list" ]; then
                ext_total=$(wc -l <"$xpi_list")

                # download extensions from the extension list
                while read -r xpi_filename; do
                    ((counter++))
                    ext_title=$(curl -sfL "${_FFXADDONSURL}"/"${xpi_filename}" | grep -oP '<h1 class=\"AddonTitle\"(?:\s[^>]*)?>\K.*?(?=<)')
                    logstr="Downloading Firefox extension '$ext_title' ($counter/$ext_total) ..."
                    log_message "$logstr" 4 "$_STRLEN"
                    xpiURL=$(curl -sfL "${_FFXADDONSURL}"/"${xpi_filename}" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*.xpi")
                    xpi_pathname="$_BASEDIR/data/firefox/$(basename "$xpiURL")"
                    xpi_filename=$(basename "$xpi_pathname")

                    # TODO: compare downloaded files' names with those in xpi-list to prevent web checks with curl
                    if [ -z "$xpiURL" ]; then
                        log_message "Extension '${ext_title}' not found" 3
                        continue
                    else
                        # https://addons.mozilla.org/firefox/downloads/file/763598/diigo_web_collector-6.0.0.4.xpi
                        fetch_file "$xpiURL" "$xpi_filename" "${_BASEDIR}/data/firefox"
                    fi
                done <"$xpi_list"
            else
                log_message "List of extensions unavailable. Skipping ..." 3
                return 1
            fi

            # rename extensions by ID
            for xpi in "${_BASEDIR}"/data/firefox/*.xpi; do
                log_message "Trying to determine extension ID for $xpi ..."
                xid=$(unzip -p "${xpi}" manifest.json | jq -r '.applications.gecko.id' 2>&1) # 1st attempt using a regular Mozilla manifest

                if [ "${xid}" == 'null' ] && unzip -l "${xpi}" | grep -q "cose.sig"; then # 2nd attempt using file cose.sig
                    log_message "Still trying to determine extension ID ..."
                    xid=$(unzip -p "${xpi}" META-INF/cose.sig | strings | grep "0Y0")
                fi

                if [ "${xid}" == 'null' ] && unzip -l "${xpi}" | grep -q "mozilla.rsa"; then # 3rd attempt using file mozilla.rsa
                    log_message "Final attempt to determine extension ID ..."
                    xid=$(unzip -p "${xpi}" META-INF/mozilla.rsa | openssl asn1parse -inform DER | grep -A 1 commonName | grep -o '{.*}')
                fi

                if [ "${xid}" == 'null' ]; then
                    log_message "Failed to determine ID for extension $xpi. 
    Please try to add the extension to Firefox manually from '${_BASEDIR}/data/firefox'..." 3
                    continue
                else
                    _XID=$(trimex "$xid")
                    log_message "Extension ID for $xpi: $_XID"
                fi

                mv "${_BASEDIR}/data/firefox/$(basename "$xpi")" "${_BASEDIR}/data/firefox/${_XID}.xpi" 2>&1 | log_trace "(FFX)"                                            # rename extension
                mv "${_BASEDIR}/data/firefox/${_XID}.xpi" "$_FFXDIR/$_FFXPRF/extensions" >/dev/null 2>&1 && log_message "Extension '$_XID.xpi' moved to profile $_FFXPRF" 1 # move extension to user profile
            done
        else
            log_message "Failed to create extensions directory for user profile $_FFXPRF"
        fi

        # copy custom files to the user profile
        declare -a ff_files=("search.json.mozlz4" "user-overrides.js")

        for f in "${ff_files[@]}"; do
            file_path="$_BASEDIR/data/firefox/$f"
            if cp "$file_path" "$_FFXDIR/$_FFXPRF" >/dev/null 2>&1; then
                log_message "Copied file '$file_path' to the Firefox user profile" 1
            else
                log_message "Failed to copy '$file_path' to the Firefox user profile" 3
            fi
        done

        # set Arkenfox stuff
        if [ -f "$_FFXDIR/$_FFXPRF/user-overrides.js" ]; then
            declare -a arkenfox_files=(updater.sh prefsCleaner.sh user.js)

            for file in "${arkenfox_files[@]}"; do
                url="https://raw.githubusercontent.com/arkenfox/user.js/master/$file"
                fetch_file "$url" "" "$_FFXDIR/$_FFXPRF" && log_message "Downloaded '$file' to '$_FFXDIR/$_FFXPRF'" 1
            done

            # set_permission "$_FFXDIR/$_FFXPRF"
            cd "$_FFXDIR/$_FFXPRF" || return
            if [ -f "./updater.sh" ]; then
                chmod +x "./updater.sh"
                bash "./updater.sh" 2>&1 | log_trace "(FFX)"
            else
                log_message "File ./updater.sh cannot be executed" 3
            fi

            if [ -f "./prefsCleaner.sh" ]; then
                chmod +x "./prefsCleaner.sh"
                bash "./prefsCleaner.sh" 2>&1 | log_trace "(FFX)"
            else
                log_message "File ./prefsCleaner.sh cannot be executed" 3
            fi
        fi
    else
        log_message "Failed to identify Firefox user profile.
    Also, please check if the list of Firefox extensions is available in '$xpi_list'." 3
    fi
}

set_gnome_extensions() {
    log_message "Setting up GNOME extensions ..." 5

    pgrep "gnome-shell" >/dev/null && killall -3 gnome-shell # restart the shell; otherwise extensions cannot be enabled
    sleep 3

    if [ -d "$_GTKEXTS" ]; then
        for i in "$_GTKEXTS"/*; do
            ext="$(basename "$i")"

            if gnome-extensions enable "$ext" 2>&1 | log_trace "(GNM)"; then
                log_message "GNOME extension '$ext' enabled" 1
            else
                log_message "Failed to enable GNOME extension '$ext'" 3
            fi
        done
    else
        log_message "Failed to locate the GNOME extensions directory" 3
    fi

    # settings for OpenWeather
    dconf write /org/gnome/shell/extensions/openweather/city "'40.16399915,50.2777093>Bakı, Azərbaycan>0 && 41.006381,28.9758715>İstanbul, Türkiyə>0 && 40.1067099,46.0371728>Kəlbəcər, Azərbaycan>0 && 40.594202,49.668448>Sumqayıt, Azərbaycan>0'"
    dconf write /org/gnome/shell/extensions/openweather/decimal-places 0
    dconf write /org/gnome/shell/extensions/openweather/disable-forecast false
    dconf write /org/gnome/shell/extensions/openweather/expand-forecast true
    dconf write /org/gnome/shell/extensions/openweather/pressure-unit "'mmHg'"
    dconf write /org/gnome/shell/extensions/openweather/refresh-interval-current 3600
    dconf write /org/gnome/shell/extensions/openweather/show-comment-in-panel true
    dconf write /org/gnome/shell/extensions/openweather/wind-direction true
    dconf write /org/gnome/shell/extensions/openweather/wind-speed-unit "'m/s'"

    # settings for Transparent Top Bar
    dconf write /com/ftpix/transparentbar/transparency 0
}

set_gsettings() {
    # Discussion: https://www.reddit.com/r/gnome/comments/vz37z2
    # Custom keybindings: https://www.suse.com/support/kb/doc/?id=000019319
    # TODO: https://askubuntu.com/a/733202

    log_message "Setting GNOME settings ..." 5

    declare -a arr_GS=("org.gnome.calculator button-mode 'advanced'"
        "org.gnome.calculator show-thousands true"
        "org.gnome.desktop.input-sources per-window true"
        "org.gnome.desktop.input-sources sources [('xkb', 'us'), ('xkb', 'az'), ('xkb', 'ru'), ('xkb', 'ara')]"
        "org.gnome.desktop.input-sources xkb-options ['terminate:ctrl_alt_bksp', 'grp:alt_shift_toggle', 'compose:sclk']"
        "org.gnome.desktop.interface clock-format '24h'"
        "org.gnome.desktop.interface clock-show-seconds true"
        "org.gnome.desktop.interface clock-show-weekday true"
        "org.gnome.desktop.interface font-antialiasing 'rgba'"
        "org.gnome.desktop.privacy old-files-age uint32 7"
        "org.gnome.desktop.privacy recent-files-max-age 30"
        "org.gnome.desktop.privacy remove-old-temp-files true"
        "org.gnome.desktop.privacy remove-old-trash-files true"
        "org.gnome.desktop.screensaver lock-enabled false"
        "org.gnome.desktop.session idle-delay uint32 0"
        "org.gnome.desktop.sound allow-volume-above-100-percent false"
        "org.gnome.desktop.wm.keybindings minimize ['<Super>z']"
        "org.gnome.desktop.wm.keybindings show-desktop ['<Super>d']"
        "org.gnome.desktop.wm.preferences button-layout 'appmenu:close'"
        "org.gnome.gedit.plugins active-plugins ['modelines', 'openlinks', 'filebrowser', 'docinfo', 'spell', 'sort']"
        "org.gnome.gedit.preferences.editor insert-spaces true"
        "org.gnome.gedit.preferences.editor tabs-size uint32 4"
        "org.gnome.GWeather temperature-unit 'centigrade'"
        "org.gnome.mutter center-new-windows 'true'"
        "org.gnome.nautilus.preferences default-folder-viewer 'list-view'"
        "org.gnome.nautilus.list-view default-zoom-level 'small'"
        "org.gnome.settings-daemon.plugins.color night-light-enabled true"
        "org.gnome.settings-daemon.plugins.color night-light-last-coordinates (40.4012, 49.8526)"
        "org.gnome.settings-daemon.plugins.color night-light-schedule-automatic true"
        "org.gnome.settings-daemon.plugins.color night-light-temperature uint32 2700"
        "org.gnome.settings-daemon.plugins.media-keys custom-keybindings ['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
        "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'File Browser'"
        "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'nautilus $_USERHOME/Downloads'"
        "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>f'"
        "org.gnome.settings-daemon.plugins.media-keys home @as []"
        "org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 25"
        "org.gnome.shell.extensions.dash-to-dock dock-fixed false"
        "org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'"
        "org.gnome.shell.extensions.dash-to-dock extend-height false"
        "org.gnome.shell.extensions.dash-to-dock intellihide true"
        "org.gnome.shell.extensions.dash-to-dock show-mounts false"
        "org.gnome.shell.extensions.pop-cosmic clock-alignment 'CENTER'"
        "org.gnome.shell.extensions.pop-cosmic overlay-key-action 'LAUNCHER'"
        "org.gnome.shell.extensions.pop-cosmic show-applications-button false"
        "org.gnome.shell.extensions.pop-cosmic show-workspaces-button false"
        "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$_DFTRMPRFL/ default-size-columns 90"
    )

    for i in "${arr_GS[@]}"; do
        # alternative option to assign array elements: ` read -r schema key value <<<"$i" `
        schema=$(echo "$i" | cut -d ' ' -f1)
        key=$(echo "$i" | cut -d ' ' -f2)
        value=$(echo "$i" | cut -d ' ' -f3-)
        gsettings set "$schema" "$key" "$value" 2>&1 | log_trace "(GST)"
    done

    log_message "GNOME settings set" 1
}

set_permission() {
    if [ $# -ne 1 ]; then
        log_and_exit "Wrong number of arguments for ${FUNCNAME[2]}" 10
    fi

    if chown -R "${_USERID}":"${_USERNAME}" "${1}" && chmod -R 774 "${1}"; then
        log_message "User '${_USERNAME}' set RWX permissions for ${1}" 1
    else
        log_and_exit "Failed to set permissions for ${1}" 11
    fi
}

set_portables() {
    local apps counter filename name archives total url
    # TODO: for i in $(jq -r '.recommendations[]' .vscodium/extensions.json); do codium --install-extension $i --force; done

    declare -a portables=('Audacity;audacity;https://api.github.com/repos/audacity/audacity/releases/latest;grep "browser_download_url.*AppImage" | cut -d\" -f4'
        'Bleachbit;bleachbit;https://api.github.com/repos/bleachbit/bleachbit/releases/latest;grep "tarball_url" | cut -d\" -f4'
        'CPU-X;cpux;https://api.github.com/repos/X0rg/CPU-X/releases/latest;grep "browser_download_url.*AppImage\"" | cut -d\" -f4'
        'DeadBeef;deadbeef;https://sourceforge.net/projects/deadbeef/files/travis/linux/master/;grep -o "href=\"https://sourceforge.net/projects/deadbeef/files/travis/linux/master/deadbeef-static.*tar.bz2/download" | cut -d\" -f2'
        'HW-Probe;hwprobe;https://api.github.com/repos/linuxhw/hw-probe/releases/latest;grep "browser_download_url.*AppImage" | cut -d\" -f4 | sort | tail -1'
        'ImageMagick;imagemagick;https://imagemagick.org/archive/binaries/magick;n/a'
        'Inkscape;inkscape;https://inkscape.org/release/all/gnulinux/appimage;grep ".*\AppImage<" | cut -d\" -f2 | tail -1 | sed "s/^/https:\/\/inkscape\.org/"'
        'KeePassXC;keepassxc;https://keepassxc.org/download/#linux;grep "AppImage\"" | cut -d\" -f2'
        'Neofetch;neofetch;https://raw.githubusercontent.com/hykilpikonna/hyfetch/master/neofetch;n/a'
        'QBittorrent;qbittorrent;https://www.qbittorrent.org/download.php;grep -P ".*sourceforge.*\d_x86_64\.AppImage\/download" | cut -d\" -f4 | head -1'
        'SMPlayer;smplayer;https://api.github.com/repos/smplayer-dev/smplayer/releases/latest;jq -r ".assets[].browser_download_url" | grep -i "appimage"'
        'SQLite Browser;sqlitebrowser;https://api.github.com/repos/sqlitebrowser/sqlitebrowser/releases/latest;grep "browser_download_url.*AppImage" | cut -d\" -f4'
        'Styli.sh;styli.sh;https://raw.githubusercontent.com/thevinter/styli.sh/master/styli.sh;n/a'
        'VSCodium;vscodium;https://api.github.com/repos/VSCodium/vscodium/releases/latest;jq -r ".assets[].browser_download_url" | grep -i "vscodium\-linux\-x64.*tar.gz$"'
        'YT-DLP;yt-dlp;https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest;grep "browser_download_url.*\/yt-dlp\"" | cut -d\" -f4'
    )

    # create directory for portable programs and bookmark it to Nautilus
    if ! mkdir -p "${_APPSDIR}"; then
        log_and_exit "Failed to create directory ${_APPSDIR}" 12
    fi

    # bookmark the Portables directory
    if [ -w "$_GTKBKMRK" ]; then
        if ! grep -q "file://${_APPSDIR}$" "${_GTKBKMRK}"; then
            printf "%s\n" "file://${_APPSDIR}" >>"$_GTKBKMRK" 2>&1 | log_trace "(PRT)"
            log_message "Bookmarked directory ${_APPSDIR}" 1
        else
            log_message "Directory ${_APPSDIR} already bookmarked"
        fi
    else
        log_message "Failed to bookmark directory ${_APPSDIR}" 3
    fi

    log_message "Initialising download of portable programs ..." 5
    check_internet
    cd "$_APPSDIR" || return

    for portable in "${portables[@]}"; do
        name="${portable%%;*}"
        filename="${portable#*;}" && filename="${filename%%;*}"
        tmp_url="${portable%;*}" && tmp_url="${tmp_url##*;}"
        cmd="${portable##*;}"

        if [ "$cmd" != 'n/a' ]; then
            full_url=$(curl -sfL "$tmp_url" | bash -c "$cmd")
        else
            full_url="$tmp_url" # imagemagick, neofetch, styli.sh ...
        fi

        [ -d "./$filename" ] && rm -r "./$filename" # to avoid error when dir and file with the same name exist

        if [ -n "$full_url" ]; then
            fetch_file "$full_url" "$filename" "$_APPSDIR"
        else
            log_message "Cannot download $name. Skipping ..." 3
        fi

        if file "./$(basename "$full_url")" | grep -q 'compressed'; then # create an array of compressed archived files
            archives+="$filename"
        fi
    done

    # extract archived portables
    # for Bleachbit, see: https://clck.ru/37ke9M)
    # curl -sfL 'https://github.com/bleachbit/bleachbit/releases/latest' | grep -o "https.*expanded_assets.*\"" | cut -d\" -f1
    apps=''

    for f in *; do
        if [ -f "$f" ] && file "$f" | grep -q 'compressed'; then # is file a tarball or bzip2 archive?
            apps+="$f "                                          # make a list of such zipped archives
        fi
    done

    apps=$(echo "$apps" | sed 's/^ *//;s/ $//') # trim ending space chars in the array

    if [ -n "$apps" ]; then
        log_message "Some portables are archived. Extracting ..."

        for app in $apps; do # see: https://www.shellcheck.net/wiki/SC2066
            if [ -f "./$app" ]; then
                tar_extractor "$app" "${archives[$k]}" "$_APPSDIR"
            else
                log_message "Archive '$app' doesn't exist. Skipping ..."
            fi
            ((k++))
        done
    fi

    # copy launcher (.desktop) files
    launcher_files=("$_BASEDIR"/data/launchers/*)
    total=${#launcher_files[@]}
    counter=0

    for f in "$_BASEDIR"/data/launchers/*; do
        name=$(basename "$f")
        if mkdir -p "$_USERAPPS"; then
            cp "$f" "$_USERAPPS"
            chown "${_USERID}":"${_USERNAME}" "${_USERAPPS}"/"${name}" && chmod 774 "${_USERAPPS}"/"${name}"                  # set ownership and X permission to copied files only
            [[ -f ${_USERAPPS}/${name} ]] && ((counter++)) || ffailed=$(printf "%s," "${_USERAPPS}"/"${name}" | sed 's/,$//') # remove last comma in string
        else
            log_message "Failed to copy files to ${_USERAPPS}" 2
        fi
    done

    # exception for KeePassXC to make it autostart after user login
    if mkdir -p "$_USERHOME/.config/autostart" 2>&1 | log_trace "(PRT)" && [ -f "$_USERAPPS/keepassxc.desktop" ]; then
        cp "$_USERAPPS/keepassxc.desktop" "$_USERHOME/.config/autostart/" 2>&1 | log_trace "(PRT)" &&
            log_message "KeePassXC will autostart after user logs in" 1
    fi

    # exception for Nautilus to open to the ~/Downloads directory when clicking on the dock icon
    launcher="$_USERAPPS/org.gnome.Nautilus.desktop"
    if [ -f "$launcher" ]; then
        sed -i "/Exec=/c\Exec=nautilus --new-window $_USERHOME/Downloads" "$launcher"
    fi

    if [[ $counter == "$total" ]]; then
        log_message "All launchers copied to $_USERAPPS and set X permissions" 1
    else
        log_message "Failed to copy and set X permissions for: $ffailed" 3
    fi

    # copy icon files
    # shellcheck disable=SC2012
    total=$(ls "${_BASEDIR}"/data/icons/* | wc -l)
    counter=0

    for f in "${_BASEDIR}"/data/icons/*; do
        name=$(basename "$f")
        if mkdir -p "${_USERICONS}"; then
            cp "$f" "${_USERICONS}"
            chown "${_USERID}":"${_USERNAME}" "${_USERICONS}"/"${name}" && chmod 774 "${_USERICONS}"/"${name}"                  # set ownership and X permission to copied files only
            [[ -f ${_USERICONS}/${name} ]] && ((counter++)) || ffailed=$(printf "%s," "${_USERICONS}"/"${name}" | sed 's/,$//') # remove last comma in string
        else
            log_message "Failed to copy files to ${_USERICONS}" 2
        fi
    done

    if [[ $counter == "$total" ]]; then
        log_message "All icon files copied to $_USERICONS" 1
    else
        log_message "Failed to copy files: $ffailed" 3
    fi

    # set user and group permissions
    dirs="$_APPSDIR $_USERAPPS $_USERICONS"
    for d in $dirs; do
        set_permission "$d"
    done

    if touch "$_PROFILE"; then
        if ! grep -q "Portables\:" <"$_PROFILE"; then
            printf "\n%s\n" "export PATH=\$PATH:$_APPSDIR" >>"$_PROFILE"
            # shellcheck source=/dev/null
            source "$_PROFILE"
            log_message "$_APPSDIR added to \$PATH" 1
        else
            log_message "$_APPSDIR already set to \$PATH. Skipping ..."
        fi
    else
        log_message "Failed to export '$_APPSDIR' to '$_PROFILE'" 3
    fi
}

set_repos() {
    log_message "Initialising installation of additional programs ..." 5
    stop_packagekitd

    # .:. CALIBRE .:.
    log_message "Installing Calibre ..."
    if ! which calibre 2>&1 | log_trace "(PPA)"; then
        url='https://download.calibre-ebook.com/linux-installer.sh'
        filename=$(basename "$url")
        temp_dir=$(mktemp -d)
        cd "$temp_dir" || return
        fetch_file "$url" "$filename" "."
        chmod +x linux-installer.sh
        echo
        sudo sh linux-installer.sh 2>&1 | log_trace "(PPA)"
        rm linux-installer.sh
        log_message "Calibre installation complete" 1
    else
        log_message "Calibre already installed. Skipping ..."
    fi

    # .:. DCONF EDITOR .:.
    log_message "Installing DConf Editor ..."
    if ! which dconf-editor 2>&1 | log_trace "(PPA)"; then
        sudo apt-get -o=Dpkg::Use-Pty=0 install dconf-editor 2>&1 | log_trace "(PPA)"
        log_message "DConf Editor installation complete" 1
    else
        log_message "DConf Editor already installed. Skipping ..."
    fi

    # .:. EASYEFFECTS .:.
    log_message "Installing EasyEffects ..."
    if ! flatpak list | grep -iq "easyeffects" 2>&1 | log_trace "(PPA)"; then
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install --user -y flathub com.github.wwmm.easyeffects 2>&1 | log_trace "(PPA)"
        log_message "EasyEffects installation complete" 1
    else
        log_message "EasyEffects already installed. Skipping ..."
    fi

    # .:. FFMPEG .:.
    log_message "Installing FFMPEG ..."
    url=$(curl -sfL 'https://ffmpeg.org/download.html' | grep -o "http.*.tar.xz")
    filename=$(basename "$url")
    temp_dir=$(mktemp -d)
    cd "$temp_dir" || return
    fetch_file "$url" "$filename" "."

    if which yasm >/dev/null && tar -xf "$temp_dir/$filename" --strip-components=1 -C . 2>&1 | log_trace "(PPA)"; then
        sh ./configure --enable-shared 2>&1 | log_trace "(PPA)"
        make -j"$(nproc)" 2>&1 | log_trace "(PPA)"
        sudo make install 2>&1 | log_trace "(PPA)"
        cd ..
        rm -r "$temp_dir"
        log_message "FFMPEG installation complete" 1
    else
        log_message "Failed to install FFMPEG.
       Please check if yasm is installed and/or '$url' is a valid URL." 3
    fi

    # .:. FSEARCH .:.
    log_message "Installing FSearch ..."
    if ! which fsearch 2>&1 | log_trace "(PPA)"; then
        sudo add-apt-repository --yes ppa:christian-boxdoerfer/fsearch-daily 2>&1 | log_trace "(PPA)"
        sudo apt-get -o=Dpkg::Use-Pty=0 update 2>&1 | log_trace "(PPA)"
        sudo apt-get -o=Dpkg::Use-Pty=0 install fsearch 2>&1 | log_trace "(PPA)"
        log_message "FSearch installation complete" 1
    else
        log_message "FSearch already installed. Skipping ..."
    fi

    # .:. LIBREOFFICE .:.
    if ! find /etc/apt/ -name "libreoffice*.list" -print0 | xargs cat | grep -q "^deb https.*ubuntu" 2>&1 | log_trace "(PPA)"; then
        log_message "Updating LibreOffice repository ..."
        sudo add-apt-repository --yes ppa:libreoffice/ppa 2>&1 | log_trace "(PPA)" &&
            log_message "LibreOffice repository updated" 1
    else
        log_message "LibreOffice repository is up-to-date. Skipping ..."
    fi

    # .:. LM-SENSORS .:.
    log_message "Installing lm-sensors ..."
    if ! which sensors >/dev/null 2>&1 | log_trace "(PPA)"; then
        sudo apt-get -o=Dpkg::Use-Pty=0 install lm-sensors 2>&1 | log_trace "(PPA)"
        log_message "lm-sensors installation complete" 1
    else
        log_message "lm-sensors already installed. Skipping ..."
    fi

    # .:. TEAMVIEWER .:.
    log_message "Installing TeamViewer ..."
    if ! which teamviewer >/dev/null 2>&1 | log_trace "(PPA)"; then
        url='https://download.teamviewer.com/download/linux/teamviewer_amd64.deb'
        filename=$(basename "$url")

        fetch_file "$url" "$filename" "$_BASEDIR"
        sudo apt-get -o=Dpkg::Use-Pty=0 install "$_BASEDIR/$filename" | log_trace "(PPA)" &&
            rm "$_BASEDIR/$filename" 2>&1 | log_trace "(PPA)" &&
            log_message "Teamviewer installation complete" 1
    else
        log_message "TeamViewer already installed. Skipping ..."
    fi
}

system_check() {
    if [[ -r "${_OS_RELEASE_FILE}" ]]; then
        log_message "Found OS release file: ${_OS_RELEASE_FILE}"
        _DISTRO_PRETTY_NAME="$(awk '/PRETTY_NAME=/' "${_OS_RELEASE_FILE}" | sed 's/PRETTY_NAME=//' | tr -d '"')"
        _NAME="$(awk '/^NAME=/' "${_OS_RELEASE_FILE}" | sed 's/^NAME=//' | tr -d '"')"
        _VERSION_CODENAME="$(awk '/VERSION_CODENAME=/' "${_OS_RELEASE_FILE}" | sed 's/VERSION_CODENAME=//')"
        [[ ${_NAME} != "${_OS}" ]] && log_and_exit "Operating system mismatch: ${_NAME}" 13
        log_message "Operating system: ${_DISTRO_PRETTY_NAME}"
    else
        log_and_exit "Failed to determine operating system!" 14
    fi

    readonly _DISTRO_PRETTY_NAME _NAME _VERSION_CODENAME
}

stop_packagekitd() {
    # Description:  Attempts to temporarily suspend daemon packagekitd, which locks `apt`
    #               and returns error 'E: Could not get lock /var/lib/apt/lists/lock. It is held by process {PROCID} (packagekitd)'.
    #               Restarting the daemon is unnecessary, as this will be done by `apt` anyway.
    # References:   https://unix.stackexchange.com/a/522362
    #               https://askubuntu.com/questions/15433

    # Check if PackageKit service is running
    if systemctl is-active --quiet packagekit.service; then
        log_message "Stopping PackageKit service ..."
        sudo systemctl stop packagekit.service 2>&1 | log_trace "(APT)"
        log_message "PackageKit service stopped." 1
    else
        log_message "PackageKit service not active."
    fi
}

system_update() {
    # Description: applies system-wide updates and removes redundant packages

    log_message "Performing system update ..." 5
    stop_packagekitd                                                      # unlock apt
    pop-upgrade release upgrade 2>&1 | log_trace "(POP)"                  # any system upgrade from System76?
    log_trace "(APT)" <<<"$(sudo apt-get -o=Dpkg::Use-Pty=0 update 2>&1)" # no prompts with 'apt update'; redirect all msgs to log_trace()
    sudo DEBIAN_FRONTEND=noninteractive apt-get -o=Dpkg::Use-Pty=0 full-upgrade -y 2>&1 | log_trace "(APT)"

    #-- reboot? --#
    if [ -e /var/run/reboot-required ]; then
        local sec=5
        local msg="POPPI will reboot to apply system updates in"

        if [ -e "$_BASEDIR"/data/misc/poppi.desktop ]; then
            if ! ls "$_USERHOME"/.config/autostart >/dev/null 2>&1; then
                mkdir -p "$_USERHOME"/.config/autostart 2>&1 | log_trace "(APT)"
            fi

            cp "$_BASEDIR"/data/misc/poppi.desktop "$_USERHOME"/.config/autostart 2>&1 | log_trace "(APT)" # enable POPPI's autostart on system reboot
            printf "%s\n" "Exec=gnome-terminal -e \"bash -c '$_BASEDIR/$_SCRIPT; exec bash'\"" >>"$_USERHOME"/.config/autostart/poppi.desktop
            chmod +x "$_USERHOME"/.config/autostart/poppi.desktop

            while [ $sec != 0 ]; do
                log_message "${_CYELLOW}$msg $sec seconds${_CNONE}" 4 "$_STRLEN"
                sleep 1
                ((sec--))
            done

            log_message "" 4 "$_STRLEN"
            reboot
        else
            log_message "Cannot proceed with scheduling the task for user $_USERNAME" 3
        fi
    fi

    # remove the autostart file after system reboot
    if [ -f "$_USERHOME"/.config/autostart/poppi.desktop ]; then
        rm "$_USERHOME"/.config/autostart/poppi.desktop
    fi

    #-- remove unnecessary packages --#
    sudo DEBIAN_FRONTEND=noninteractive apt-get -o=Dpkg::Use-Pty=0 autoremove 2>&1 | log_trace "(APT)"

    # disable Ubuntu advantage tools
    # source: https://askubuntu.com/a/1452520
    if sudo test -f /etc/apt/apt.conf.d/20apt-esm-hook.conf; then
        sudo mv /etc/apt/apt.conf.d/20apt-esm-hook.conf /etc/apt/apt.conf.d/20apt-esm-hook.conf.disabled &&
            sudo touch /etc/apt/apt.conf.d/20apt-esm-hook.conf && log_message "Ubuntu Advantage Tools disabled" 1
    elif sudo test -f /etc/apt/apt.conf.d/20apt-esm-hook.conf.dpkg-dist; then
        sudo mv /etc/apt/apt.conf.d/20apt-esm-hook.conf.dpkg-dist /etc/apt/apt.conf.d/20apt-esm-hook.conf.disabled &&
            sudo touch /etc/apt/apt.conf.d/20apt-esm-hook.conf && log_message "Ubuntu Advantage Tools disabled" 1
    fi
}

# shellcheck disable=SC2128
tar_extractor() {
    [ $# -eq 0 ] && log_message "ERR: $FUNCNAME() requires at least 1 argument" 2 && return
    [ $# -gt 0 ] && [ $# -lt 3 ] && log_message "ERR: Insufficient arguments for $FUNCNAME()" 3
    [ ! -f "${1}" ] || ! file "${1}" | grep -q 'compressed' && log_message "ERR: Argument 1 for $FUNCNAME() not a valid file" 2 && return
    [ -f "${2}" ] || [ -d "${2}" ] && log_message "ERR: Argument 2 for $FUNCNAME() not a valid string" 3
    [ ! -d "${3}" ] && log_message "ERR: Argument 3 for $FUNCNAME() not a valid directory" 3

    appfile=${1}
    appname=${2:-$(basename "$appfile")}
    loc=${3:-$_BASEDIR}
    fmt=$(file "$appfile" | awk '{print $2}') # format of archive

    declare -a tars=('gzip;tzf;xzf' 'XZ;tf;xf' 'bzip2;tjf;xjf')

    for tar in "${tars[@]}"; do
        zip="${tar%%;*}"                    # compression format
        lst="${tar#*;}" && lst="${lst%%;*}" # listing method
        ext="${tar##*;}"                    # extraction method

        if [ "$fmt" == "$zip" ]; then
            xdir=$(tar "$lst" "$appfile" | head -1 | cut -d'/' -f1) # list the contents of archive
            if [ "$xdir" = '.' ]; then                              # flat archive with no root directory
                newdir="$appname"'_'                                # append '_' to the directory name
                mkdir "$loc/$newdir"
                tar "$ext" "$appfile" -C "$loc/$newdir"
                rm "$appfile"                                              # useless archive; must precede the rename operation below
                [ -d "$loc/$newdir" ] && mv "$loc/$newdir" "$loc/$appname" # rename the archive
            else
                tar "$ext" "$appfile" -C "$loc"
                rm "$appfile"                                          # useless archive; must precede the rename operation below
                [ -d "$loc/$xdir" ] && mv "$loc/$xdir" "$loc/$appname" # rename the archive
            fi
            break
        fi
    done
}

# shellcheck disable=SC2001
trimex() {
    # clean the string with extension name as much as possible
    # TODO: consider occasions when extension's ID indeed starts with '@' or similar'. Such extensions usually have IDs in manifest.json

    [ $# -ne 1 ] && log_message "Wrong number of arguments" 3
    local val
    val="${1}"

    if [[ "$val" =~ ^[@#\&$]* ]]; then
        val=$(sed 's/^[@#&$]//' <<<"$val")
    fi

    if grep -o "\{.*\}" <<<"${val}" >/dev/null; then
        val=$(sed 's/{}//g' <<<"$val")
    fi

    if grep -o "0Y0" <<<"${val}" >/dev/null; then
        val=$(sed 's/0Y0//' <<<"$val")
    fi

    echo "$val"
}

user_consent() {
    while true; do
        read -r -n 1 -p "${_CYELLOW}Running this script will make changes to your system. Continue? [Y|N] ${_CNONE}" answer
        case $answer in
        [yY])
            clear
            headline
            break
            ;;
        [nN])
            clear
            exit
            ;;
        *) printf '%s' "\n\n${_CRED}Invalid response! Try again.\n\n""${_CNONE}" ;;
        esac
    done
}

all() {
    # The order of functions does matter!

    clear
    xdotool windowsize "$(xdotool getactivewindow)" 110% 110% && sleep 1
    headline
    user_consent
    screenlock
    log_message "Initialisation and checks" 5
    __init_logfile
    log_message "Permission checks" 5
    check_user
    check_internet
    system_check
    system_update
    set_dependencies
    set_portables
    set_repos
    set_firefox
    miscops
    set_configs
    get_gnome_extensions
    set_gsettings
    set_gnome_extensions
    misc_change_user_avatar
    set_favourites
    system_update
    screenlock

    [ -f "$_APPSDIR"/styli.sh ] && [ -d "$_WALLPPR" ] && "$_APPSDIR/styli.sh -g -d $_WALLPPR" # set a random wallpaper
    echo
    log_message "POPPI took $SECONDS seconds to complete all the assignments. See you next time!" 1 "$_STRLEN"
    sleep 5
    # clear
}

# The magic starts here ...
main() {
    option=${1}
    __init_vars

    # determine when to start logging the script
    declare -a fargs
    fargs=('' '-a' '--all' '-h' '--help' '-v' '--version')
    bool_initlog=0

    for arg in "${fargs[@]}"; do
        [[ "$1" != "$arg" ]] && ((bool_initlog++))
    done

    [ "$bool_initlog" -eq ${#fargs[@]} ] && __init_logfile # start logging, if values match

    case $option in
    -a | --all) all ;;
    -b | --bookmark) misc_bookmark_dirs ;;
    -c | --connect) check_internet ;;
    -d | --dock) set_favourites ;;
    -f | --firefox) set_firefox ;;
    -g | --set-gsettings) set_gsettings ;;
    -h | --help) display_usage ;;
    -p | --set-portables) set_portables ;;
    -r | --set-repos) set_repos ;;
    -u | --update) system_update ;;
    -v | --version) display_version ;;
    -x | --gnome-extensions)
        get_gnome_extensions
        set_gnome_extensions
        ;;
    *) display_usage ;;
    esac
}

main "$@"
