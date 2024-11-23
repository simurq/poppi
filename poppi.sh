#!/usr/bin/env bash

#############################################################################################################
# Description:          	Pop!_OS post-installation methods tested on version 22.04 LTS                   #
# Github repository:    	https://github.com/simurqq/poppi                                                #
# License:              	GPLv3                                                                           #
# Author:               	Victor Quebec                                                                   #
# Date:                 	Nov 5, 2024                                                                     #
# Requirements:             Bash v4.2 and above,                                                            #
#                           coreutils, curl, jq, pip, python                                                #
#############################################################################################################

# shellcheck disable=SC2010 source=/dev/null

set -o pipefail # details: https://t.ly/U7D1K
_START_TIME=$SECONDS

__init_logfile() {
    # Description:  Creates a log file for this script and manages its backups.
    # Arguments:    None.
    # Output:       File(s) 'poppi[_ddmmYYYY|YYYYmmdd]_HHmmss.log' in the script directory.
    local fmt log_files oldlog total_logs

    [ "$_LOGFILEON" -ne 1 ] && return 2
    # Back up the logs, as specified by user
    if [ "$_LFBKPNO" -ne 0 ]; then
        shopt -s nullglob
        log_files=("${_LOGFILE}"_*.log)
        total_logs=${#log_files[@]}
        if [[ $total_logs -ge "$_LFBKPNO" ]]; then
            oldlog=$(find "$_BASEDIR" -type f -name "$(basename "${_LOGFILE}")_*" -printf "%T@ %p\n" | sort -n | head -1 | cut -d' ' -f2-) # locate the oldest log
            [ -n "$oldlog" ] && rm "$oldlog" 2>&1 | log_trace "[LOG]"                                                                      # FIFO rulez!
        fi

        # Format the output
        if [ "$_LOGFILEFMT" == 'US' ]; then
            fmt='%Y%m%d_%H%M%S'
        else
            fmt='%d%m%Y_%H%M%S'
        fi

        if [ -f "${_LOGFILE}"'.log' ]; then
            mv "${_LOGFILE}"'.log' "${_LOGFILE}"'_'"$(date +$fmt)"'.log' 2>&1 | log_trace "[LOG]" # back up the existing file
        fi
    fi

    # Create a log file
    if [ ! -f "${_LOGFILE}"'.log' ]; then
        if touch "${_LOGFILE}"'.log' 2>&1 | log_trace "[LOG]" && [ -w "${_LOGFILE}"'.log' ]; then
            log_message "Created log file: ${_LOGFILE}.log" 1
            log_message "Logging initialised" 1
        else
            log_and_exit "${FUNCNAME[0]}: Failed to create a logfile." 6
        fi
    fi
}

__init_vars() {
    # Description:  First function to load and set initial global variables.
    # Arguments:    None.
    # Note:         Avoid changing the order of initialisation due to variable dependencies!

    # Global variables and constants with default values
    _USERNAME=$(whoami)                                                                # user name; must be the first constant initialised
    _APPSDIR="$HOME"/Portables                                                         # path to portable programs
    _AUTODRIVES=()                                                                     # USB drives to mount on each system boot
    _AUTOSTART=()                                                                      # packages to autostart on system reboot
    _AVATARDSTDIR='/usr/share/pixmaps/faces'                                           # source/destination directory for user avatar images
    _AVATARIMG='popos.png'                                                             # avatar image file
    _AVATARON=1                                                                        # enable/disable user avatar
    _AVATARTXT=/var/lib/AccountsService/users/"$_USERNAME"                             # a text file with paths to user avatars
    _BASEDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)                             # script directory
    _BASHRC="$HOME"/.bashrc                                                            # user settings updated with every new shell session
    _BINPATH="$HOME"/.local/bin                                                        # directory for prerequisite binaries
    _BOOKDIRS=()                                                                       # directories to bookmark to GNOME Files/Nautilus
    _CONFIG_FILE=''                                                                    # user configuration file
    _CONFIGS_DIR="$_BASEDIR"/data/configs                                              # source directory for user configuration files
    _CONFIGSP_DIR="$_BASEDIR"/data/configsp                                            # source directory for user configuration files for portable programs
    _CRONLINE=()                                                                       # crontab commands
    _DFTRMPRFL=$(gsettings get org.gnome.Terminal.ProfilesList default | sed "s/'//g") # default terminal profile
    _DISPLAY="DISPLAY=${DISPLAY}"                                                      # by default = :1
    _DOTFILES="$_BASEDIR"/data/dotfiles                                                # source directory for dotfiles
    _ENDMSG='false'                                                                    # final message toggle
    _EXEC_START=$(date +%s)                                                            # script launch time
    _FFXADDONSURL='https://addons.mozilla.org/addon'                                   # main server to download Firefox addons
    _FFXAPPINI='/usr/lib/firefox/application.ini'                                      # required Firefox settings
    _FFXCHANNEL=''                                                                     # Firefox channel info
    _FFXCHANNELFILE='/usr/lib/firefox/defaults/pref/channel-prefs.js'                  # File with Firefox channel info
    _FFXCONFIG=0                                                                       # configure Firefox?
    _FFXCOOKIES=()                                                                     # Firefox cookies to keep
    _FFXDIR="$HOME"/.mozilla/firefox                                                   # Firefox profile directory
    _FFXEXTSLST=()                                                                     # list of installed Firefox extensions
    _FFXEXTS=()                                                                        # list of Firefox extensions
    _FFXHOMEPAGE=0                                                                     # set/unset custom homepage for Firefox
    _FFXPREFS='prefs.js'                                                               # Firefox preferences
    _FFXPRF=''                                                                         # Firefox default profile directory
    _FFXUSEROVERRIDES='user-overrides.js'                                              # Firefox user settings to override default ones (if _FFXPRIVACY enabled)
    _FFXPRIVACY=0                                                                      # enable/disable Firefox privacy settings
    _FILELOGGER_ACTIVE=false                                                           # log file status
    _GCALC=()                                                                          # custom functions for GNOME Calc
    _GFAVOURITES=()                                                                    # favourite programs to dock
    _GNOMEXTS=()                                                                       # GNOME extensions
    _GNOMEXTSET=()                                                                     # GNOME extension settings
    _GSETTINGS=()                                                                      # GNOME pre-configured GSettings
    _GCSETTINGS=()                                                                     # GNOME custom GSettings (schema, key, and value)
    _GTKBKMRK="$HOME"/.config/gtk-3.0/bookmarks                                        # directory bookmarks on Files/Nautilus
    _GTKEXTS="$HOME"/.local/share/gnome-shell/extensions                               # default location for GNOME extensions
    _INSTALLERS=()                                                                     # .deb and other installer packages to install
    _isLOCKED=0                                                                        # screenlock status
    _JSON_DATA=''                                                                      # contents of the user configuration file
    _LFBKPNO=3                                                                         # number of log files to back up
    _LODIR="$_BASEDIR"/data/libreoffice                                                # directory for LibreOffice extensions
    _LOEXTS=()                                                                         # array for LibreOffice extensions
    _LOEXTSURL='https://extensions.libreoffice.org/en/extensions/show'                 # main server to download LibreOffice extensions
    _LOGFILE="$_BASEDIR"/poppi                                                         # log file
    _LOGFILEFMT='Metric'                                                               # formatting of date and time: US or Metric
    _LOGFILEON=1                                                                       # enable/disable log file
    _MAXWIN=1                                                                          # maximise window
    _MISC="$_BASEDIR"/data/misc                                                        # directory for miscellaneous files
    _MSFONTS=0                                                                         # install Microsoft fonts
    _OPTION=''                                                                         # any of the valid POPPI options: -[abcdfghprvx]
    _OS_RELEASE="/etc/os-release"                                                      # file with OS info
    _OS="Pop!_OS"                                                                      # operating system
    _OVERAMPLIFY=0                                                                     # overamplify the system volume
    _PORTABLES=()                                                                      # an array of AppImages and other portable packages to install
    _POWERMODE='off'                                                                   # auto-suspend on/off
    _SCHEMA="$_MISC"/schema.json                                                       # JSON schema for validation
    _SCREENLOCK=0                                                                      # screenlock period of inactivity
    _SCRIPT=$(basename "$0")                                                           # this script
    _SETGEARY=0                                                                        # set email client Geary
    _SETMONDAY=0                                                                       # set start of the week to Monday
    _STRLEN=$(($(tput cols) - 5))                                                      # width of field to print the log message; slightly less than terminal width to avoid string duplication
    _TESTSERVER='duckduckgo.com'                                                       # test server's URL
    _TIMER=1                                                                           # enable/disable timer
    _USERAPPS="$HOME"/.local/share/applications                                        # .desktop launchers for portable programs
    _USERICONS="$HOME"/.local/share/icons                                              # icons for portable programs
    _USERID=$(id -u "$_USERNAME")                                                      # user login id
    _USERPROFILE="$HOME"/.profile                                                      # user profile directory (requires system reboot)
    _USERSESSION="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$_USERID/bus"           # user session, useful for crontab operations
    _VERSION="0.9.5"                                                                   # script version
    _VSIX=()                                                                           # extensions for VS Codium
    _WPEXTDIR=''                                                                       # external directory to source wallpapers
    _WPON=0                                                                            # enable custom wallpapers
    _WPSRCDIR="$HOME"/Pictures/Wallpapers                                              # local directory to source wallpapers
    _XID=""                                                                            # Firefox extension ID

    # List of common compressed archive MIME types
    _COMPRESSED_TYPES=(
        "application/gzip"
        "application/x-bzip2"
        "application/x-xz"
        "application/x-tar"
        "application/zip"
        "application/x-7z-compressed"
        "application/x-rar-compressed"
        "application/x-lzip"
        "application/x-lzma"
        "application/x-lzop"
        "application/zstd"
    )

    # Display colours in ANSI format '\e[38;2;R;G;Bm'
    _CHEAD=$'\e[38;2;72;185;199m'
    _CINFO=$'\e[38;2;148;148;148m'
    _COKAY=$'\e[38;2;78;154;10m'
    _CSTOP=$'\e[38;2;255;50;50m'
    _CWARN=$'\e[38;2;240;230;115m'
    _CNONE=$'\e[0m'

    # set readonly status 'after' variable initialisation
    readonly _AVATARDSTDIR _BASEDIR _BASHRC _COMPRESSED_TYPES \
        _CONFIGS_DIR _CONFIGSP_DIR _DFTRMPRFL _DISPLAY _DOTFILES \
        _FFXADDONSURL _FFXAPPINI _FFXCHANNELFILE _FFXDIR _FFXPREFS \
        _FFXUSEROVERRIDES _GTKBKMRK _GTKEXTS _LODIR _LOEXTSURL \
        _LOGFILE _MISC _OS_RELEASE _OS _SCRIPT _STRLEN _USERAPPS \
        _USERICONS _USERID _USERNAME _USERPROFILE _USERSESSION
}

__load_configs() {
    # Description:  Loads user configuration settings from a JSON file.
    # Arguments:    None.
    _JSON_DATA=$(jq '.' "$_CONFIG_FILE") # Load the contents of the user configuration file to memory

    # Define an associative array to map JSON keys to Bash variables
    declare -A json_keys=(
        ["FIREFOX.\"ffx.cookies_to_keep\""]="_FFXCOOKIES"
        ["FIREFOX.\"ffx.extensions\""]="_FFXEXTS"
        ["MISCOPS.\"msc.automount_drives\""]="_AUTODRIVES"
        ["MISCOPS.\"msc.bookmarked_dirs\""]="_BOOKDIRS"
        ["MISCOPS.\"msc.crontab_cmds\""]="_CRONLINE"
        ["MISCOPS.\"msc.gnome_favourites\""]="_GFAVOURITES"
        ["MISCOPS.\"msc.gnome_calc_functions\""]="_GCALC"
        ["MISCOPS.\"msc.gnome_extensions\""]="_GNOMEXTS"
        ["MISCOPS.\"msc.gnome_extension_settings\""]="_GNOMEXTSET"
        ["MISCOPS.\"msc.gnome_settings\""]="_GSETTINGS"
        ["MISCOPS.\"msc.gnome_custom_settings\""]="_GCSETTINGS"
        ["PACKAGES.\"pkg.autostart\""]="_AUTOSTART"
        ["PACKAGES.\"pkg.portables\""]="_PORTABLES"
        ["PACKAGES.\"pkg.portables\".codium.extensions"]="_VSIX"
        ["PACKAGES.\"pkg.installers\""]="_INSTALLERS"
        ["PACKAGES.\"pkg.installers\".LibreOffice.extensions"]="_LOEXTS"
    )

    # Loop through each key in the associative array
    for key in "${!json_keys[@]}"; do
        var_name="${json_keys[$key]}"
        if jq -e ".${key} | length > 0" <<<"$_JSON_DATA" >/dev/null; then
            if [[ "$key" == "PACKAGES.\"pkg.portables\"" ]]; then
                # Extract keys of portables where 'required' is 1
                mapfile -t "$var_name" < <(echo "$_JSON_DATA" | jq -r '.PACKAGES."pkg.portables" | to_entries | map(select(.value.required == 1) | .key) | .[]')
            elif [[ "$key" == "PACKAGES.\"pkg.installers\"" ]]; then
                # Extract keys of installers where 'required' is 1
                mapfile -t "$var_name" < <(echo "$_JSON_DATA" | jq -r '.PACKAGES."pkg.installers" | to_entries | map(select(.value.required == 1) | .key) | .[]')
            # Extract subkeys and values for Gnome Settings
            elif [[ "$key" == "MISCOPS.\"msc.gnome_settings\"" ]]; then
                mapfile -t "$var_name" < <(echo "$_JSON_DATA" | jq -r '.MISCOPS."msc.gnome_settings" | to_entries | map(select(.value != null and .value != "")) | map(.key + ":" + (.value | tostring)) | .[]')

            else
                mapfile -t "$var_name" < <(echo "$_JSON_DATA" | jq -r ".${key}[]")
            fi
        fi
    done

    # Extract and assign values to global colour variables
    usrVal=$(echo "$_JSON_DATA" | jq -r --arg default "$_CHEAD" '.GENERAL."gen.colour_head" // $default | select(. != "") // $default') && _CHEAD=$(set_colour "$usrVal" "$_CHEAD")
    usrVal=$(echo "$_JSON_DATA" | jq -r --arg default "$_CINFO" '.GENERAL."gen.colour_info" // $default | select(. != "") // $default') && _CINFO=$(set_colour "$usrVal" "$_CINFO")
    usrVal=$(echo "$_JSON_DATA" | jq -r --arg default "$_COKAY" '.GENERAL."gen.colour_okay" // $default | select(. != "") // $default') && _COKAY=$(set_colour "$usrVal" "$_COKAY")
    usrVal=$(echo "$_JSON_DATA" | jq -r --arg default "$_CSTOP" '.GENERAL."gen.colour_stop" // $default | select(. != "") // $default') && _CSTOP=$(set_colour "$usrVal" "$_CSTOP")
    usrVal=$(echo "$_JSON_DATA" | jq -r --arg default "$_CWARN" '.GENERAL."gen.colour_warn" // $default | select(. != "") // $default') && _CWARN=$(set_colour "$usrVal" "$_CWARN")

    # Extract and assign other values to global variables
    _LFBKPNO=$(echo "$_JSON_DATA" | jq -r --arg default "$_LFBKPNO" '.GENERAL."gen.logfile_backup_no" // $default | select(. != "") // $default')
    _LOGFILEFMT=$(echo "$_JSON_DATA" | jq -r --arg default "$_LOGFILEFMT" '.GENERAL."gen.logfile_format" // $default | select(. != "") // $default')
    _LOGFILEON=$(echo "$_JSON_DATA" | jq -r --arg default "$_LOGFILEON" '.GENERAL."gen.logfile_on" // $default | select(. != "") // $default')
    _MAXWIN=$(echo "$_JSON_DATA" | jq -r --arg default "$_MAXWIN" '.GENERAL."gen.maximise_window" // $default | select(. != "") // $default')
    _TIMER=$(echo "$_JSON_DATA" | jq -r --arg default "$_TIMER" '.GENERAL."gen.set_timer" // $default | select(. != "") // $default')
    _TESTSERVER=$(echo "$_JSON_DATA" | jq -r --arg default "$_TESTSERVER" '.GENERAL."gen.test_server" // $default | select(. != "") // $default')
    _AVATARON=$(echo "$_JSON_DATA" | jq -r --arg default "$_AVATARON" '.MISCOPS."msc.avatar_enable" // $default | select(. != "") // $default')
    usrVal=$(echo "$_JSON_DATA" | jq -r --arg default "$_AVATARIMG" '.MISCOPS."msc.avatar_image" // $default | select(. != "") // $default')
    [ -f "$_MISC/$usrVal" ] && _AVATARIMG="$usrVal"
    _MSFONTS=$(echo "$_JSON_DATA" | jq -r --arg default "$_MSFONTS" '.MISCOPS."msc.ms_fonts" // $default | select(. != "") // $default')
    _SETGEARY=$(echo "$_JSON_DATA" | jq -r --arg default "$_SETGEARY" '.MISCOPS."msc.set_geary" // $default | select(. != "") // $default')
    _SETMONDAY=$(echo "$_JSON_DATA" | jq -r --arg default "$_SETMONDAY" '.MISCOPS."msc.week_starts_on_monday" // $default | select(. != "") // $default')
    _OVERAMPLIFY=$(echo "$_JSON_DATA" | jq -r --arg default "$_OVERAMPLIFY" '.MISCOPS."msc.volume_overamplify" // $default | select(. != "") // $default')
    _WPON=$(echo "$_JSON_DATA" | jq -r --arg default "$_WPON" '.MISCOPS."msc.wallpaper_on" // $default | select(. != "") // $default')
    usrVal=$(echo "$_JSON_DATA" | jq -r --arg default "$_WPSRCDIR" '.MISCOPS."msc.wallpaper_src_dir" // $default | select(. != "") // $default')
    [[ -d "$usrVal" ]] && _WPSRCDIR="$usrVal"
    _WPEXTDIR=$(echo "$_JSON_DATA" | jq -r --arg default "$_WPEXTDIR" '.MISCOPS."msc.wallpaper_ext_dir" // $default | select(. != "") // $default')
    _FFXCONFIG=$(echo "$_JSON_DATA" | jq -r --arg default "$_FFXCONFIG" '.FIREFOX."ffx.configure" // $default | select(. != "") // $default')
    _FFXHOMEPAGE=$(echo "$_JSON_DATA" | jq -r --arg default "$_FFXHOMEPAGE" '.FIREFOX."ffx.set_homepage" // $default | select(. != "") // $default')
    _FFXPRIVACY=$(echo "$_JSON_DATA" | jq -r --arg default "$_FFXPRIVACY" '.FIREFOX."ffx.set_privacy" // $default | select(. != "") // $default')
    usrVal=$(echo "$_JSON_DATA" | jq -r --arg default "$_APPSDIR" '.PACKAGES."pkg.portables_dir" // $default | select(. != "") // $default')
    [[ -d "$usrVal" ]] && _APPSDIR="$usrVal"
}

__logger_core() {
    # Description:  Main function for logging all processes executing in the shell both in the log file and on the terminal.
    # Arguments:    Two (2) - the level of log and the message to log.
    if [[ $# -ne 2 ]]; then
        return 3
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
            declare -r lvl_color="${_CINFO}"
            _FILELOGGER_ACTIVE='true'
            ;;
        success)
            declare -r lvl_str="SUCCESS"
            declare -r lvl_sym="✓"
            declare -r lvl_color="${_COKAY}"
            _FILELOGGER_ACTIVE='true'
            ;;
        trace)
            declare -r lvl_str="TRACE"
            declare -r lvl_sym="~"
            declare -r lvl_color="${_CINFO}"
            _FILELOGGER_ACTIVE='true'
            ;;
        warn | warning)
            declare -r lvl_str="WARNING"
            declare -r lvl_sym="!"
            declare -r lvl_color="${_CWARN}"
            _FILELOGGER_ACTIVE='true'
            ;;
        error)
            declare -r lvl_str="ERROR"
            declare -r lvl_sym="✗"
            declare -r lvl_color="${_CSTOP}"
            _FILELOGGER_ACTIVE='true'
            ;;
        progress)
            declare -r lvl_str="PROGRESS"
            declare -r lvl_sym="»"
            declare -r lvl_color="${_CINFO}"
            _FILELOGGER_ACTIVE='false'
            lvl_console="0"
            ;;
        prompt)
            declare -r lvl_str="PROMPT"
            declare -r lvl_sym="⸮"
            declare -r lvl_color="${_CWARN}"
            _FILELOGGER_ACTIVE='false'
            lvl_console="2"
            ;;
        stage)
            declare -r lvl_str="STAGE"
            declare -r lvl_sym="—"
            declare -r lvl_color="${_CHEAD}"
            _FILELOGGER_ACTIVE='true'
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

    if [[ $_FILELOGGER_ACTIVE == 'true' && -f "$_LOGFILE"'.log' ]]; then
        printf "%s %-25s %-10s %s\n" "${lvl_ts}" "${FUNCNAME[2]}" "[${lvl_str}]" "$lvl_msg" >>"$_LOGFILE"'.log'
    fi
}

__make_configs() {
    # Description:  Writes default configuration parameters for this script to a compacted JSON file.
    # Arguments:    None.
    # Rationale:    As the core element of POPPI, user configuration file is a convenient playground for experimenting with different program settings.

    # Change to base directory or return error code if it fails
    cd "$_BASEDIR" || {
        log_and_exit "${FUNCNAME[0]}: Failed to access '$_BASEDIR'." 4
    }

    # Make a new configuration file
    if ! cat <<EOF >"$_BASEDIR"/configure.pop 2>&1 | log_trace "[MKC]"; then
{"GENERAL":{"gen.colour_head":"#48b9c7","gen.colour_info":"#949494","gen.colour_okay":"#4e9a0a","gen.colour_stop":"#ff3232","gen.colour_warn":"#f0e673","gen.logfile_backup_no":1,"gen.logfile_format":"Metric","gen.logfile_on":1,"gen.maximise_window":1,"gen.set_timer":1,"gen.test_server":"duckduckgo.com"},"FIREFOX":{"ffx.configure":0,"ffx.cookies_to_keep":[],"ffx.extensions":[],"ffx.set_homepage":0,"ffx.set_privacy":0},"PACKAGES":{"pkg.autostart":[],"pkg.installers":{"Calibre":{"required":0},"DConf-Editor":{"required":0},"FFMPEG_s":{"required":0},"FSearch":{"required":0},"LibreOffice":{"required":0,"extensions":[]},"lmsensors":{"required":0},"pdf.tocgen":{"required":0},"TeamViewer":{"required":0},"Virt-Manager":{"required":0}},"pkg.portables":{"audacity":{"required":0},"bleachbit":{"required":0},"cpux":{"required":0},"curl":{"required":0},"deadbeef":{"required":0},"hwprobe":{"required":0},"imagemagick":{"required":0},"inkscape":{"required":0},"jq":{"required":0},"keepassxc":{"required":0},"krita":{"required":0},"musescore":{"required":0},"neofetch":{"required":0},"qbittorrent":{"required":0},"smplayer":{"required":0},"sqlitebrowser":{"required":0},"styli.sh":{"required":0},"codium":{"required":0,"extensions":[]},"xnview":{"required":0},"xournalpp":{"required":0},"ytdlp":{"required":0}},"pkg.portables_dir":""},"MISCOPS":{"msc.automount_drives":[],"msc.avatar_enable":1,"msc.avatar_image":"popos.png","msc.bookmarked_dirs":[],"msc.crontab_cmds":[],"msc.gnome_calc_functions":[],"msc.gnome_custom_settings":[],"msc.gnome_extensions":[],"msc.gnome_extension_settings":[],"msc.gnome_favourites":[],"msc.gnome_settings":{"button_layout":"","button_position":"","capslock_as_extra_escape":0,"centre_windows_on_open":0,"check_alive_timeout":5000,"compose_key":"","font_scaling_factor":"1.0","font_terminal":"Fira Mono 12","font_ui":"Fira Sans Semi-Light 10","keyboard_languages":[],"launch_browser":"","launch_files":"","launch_settings":"","launch_terminal":"","set_wallpaper":"","show_seconds":0,"show_weekdays":0,"switch_workspace_down":"","switch_workspace_up":"","windows_close":"","windows_maximise":"","windows_minimise":""},"msc.ms_fonts":0,"msc.set_geary":0,"msc.volume_overamplify":0,"msc.wallpaper_on":0,"msc.wallpaper_src_dir":"","msc.wallpaper_ext_dir":"","msc.week_starts_on_monday":0}}
EOF
        log_message "Creating user configuration file failed. Skipping ..." 3
    fi

    # Return to the previous directory
    cd - >/dev/null || log_message "Could not return to previous directory." 4
}

__make_dirs() {
    # Description:  Creates the default script directories, if abscent.
    # Arguments:    None.
    local dir Dirs

    declare -a Dirs=('configs' 'configsp' 'dotfiles' 'firefox' 'icons' 'launchers' 'misc')
    for dir in "${Dirs[@]}"; do
        if [ ! -d "$_BASEDIR/data/$dir" ]; then
            if ! mkdir -p "$_BASEDIR/data/$dir"; then
                log_and_exit "${FUNCNAME[0]}: Failed to create directory '$_BASEDIR/data/$dir'." 5
            else
                log_message "Created directory '$_BASEDIR/data/$dir'" 1
            fi
        fi
    done
}

all() {
    # Description:  Executes all operations in sequence.
    # Arguments:    None.
    # Note:         The order of functions may affect the performance of the script!
    set_portables
    set_installers
    set_firefox
    miscops
    set_configs
    set_gsettings
    set_gnome_extensions
    misc_set_avatar
    set_favourites
}

bytes_to_human() {
    # Description:      Converts bytes to human-readable format. Used in `fetch_file()`.
    # Arguments:        One (1) - size of the downloaded file in bytes.
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
        if ping -c 4 -i 0.2 "$_TESTSERVER" >/dev/null 2>&1 | log_trace "[WEB]"; then
            log_message "Connected to the Internet" 1
        else
            log_and_exit "${FUNCNAME[0]}: You are not connected to the Internet,
    please check your network connection and try again." 8
        fi
    fi
}

check_user() {
    if [[ $EUID -eq 0 ]] || [[ $EUID -ne $_USERID ]]; then
        log_and_exit "${FUNCNAME[0]}: This script must be run by '$_USERNAME'." 9
    else
        log_message "Script run by '$_USERNAME'" 1
    fi
}

display_usage() {
    cat <<EOF
${_CINFO}
A set of post-installation methods developed for and tested on Pop!_OS 22.04 LTS.

  ${_CNONE}USAGE:${_CINFO}
  ./${_SCRIPT} -[abcdfghipvx] [CONFIGURATION_FILE]

  ${_CNONE}OPTIONS:${_CINFO}
  -a, --all                 Download, install and set everything
  -b, --bookmark            Bookmark select directories to GNOME Files/Nautilus
  -c, --connect             Check and configure Wi-Fi connection
  -d, --dock                Set your favourite programs on the dock
  -f, --set-firefox         Configure options for Firefox
  -g, --set-gsettings       Set GNOME GSettings
  -h, --help                Display this help message
  -i, --set-installers      Install/update non-portable programs
  -p, --set-portables       Install/update portable programs
  -v, --version             Display version info
  -x, --gnome-extensions    Get and enable GNOME extensions

  ${_CNONE}DOCUMENTATION & BUGS:${_CINFO}
  Report bugs to:           https://github.com/simurqq/poppi/issues
  Documentation:            https://github.com/simurqq/poppi/README.MD
  License:                  GPLv3
${_CNONE}
EOF
}

display_version() {
    cat <<EOF
${_CINFO}Pop!_OS Post-Installation (POPPI) version $_VERSION
Copyright (C) 2024 Victor Quebec
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Victor Quebec for the benefit of the Pop!_OS community.${_CNONE}

EOF
}

fetch_file() {
    # Description:  The main function powered by cURL to download files.
    # Arguments:    Three (3)
    #   -- URL of the file to download [required]
    #   -- Name of the file to download [optional]
    #   -- Location of the file to download [optional]
    local content_length curl_output fetch filename filesize http_code loc percentage prevsize url

    # Check the number of arguments
    if [ $# -eq 0 ] || [ $# -gt 3 ]; then
        log_and_exit "${FUNCNAME[0]}: Wrong number of arguments: $#" 3
    fi

    # Check if ${1} is a valid URL
    if ! curl -sfIL "${1}" >/dev/null; then
        log_and_exit "${FUNCNAME[0]}: Not a valid URL: ${1}" 10
    fi

    # Assign arguments to variables
    url=${1}
    filename=${2:-$(basename "${1}")}
    loc=${3:-$_BASEDIR}

    # Options to download the file with custom or remote server name
    if [ $# -eq 1 ]; then
        fetch="curl -sfLC - --output-dir $loc '$url' -O"
    else
        fetch="curl -sfLC - --output-dir $loc '$url' -o $filename"
    fi

    curl_output=$(curl -sIL "$url" 2>&1)
    content_length=$(grep -i "content-length: [^0]" <<<"$curl_output" | tail -1 | awk '{print $2}' | tr -d '\r')
    content_length=${content_length:-0}
    http_code=$(grep -i "http.*200" <<<"$curl_output" | cut -d' ' -f2)

    # Update the download instead of re-downloading the file
    if [ -f "$loc/$filename" ]; then
        filesize=$(stat -c '%s' "$loc/$filename")
        if [ "$filesize" -lt "$content_length" ]; then
            log_message "Updating download for '$filename'..." 4 "$_STRLEN"
        else
            return 11
        fi
    fi

    # Download the file, if it is on the remote server
    if [ "$http_code" == 200 ]; then
        filesize=1
        prevsize=0
        eval "$fetch" | while [ "$filesize" != "$content_length" ]; do
            if [ -f "$loc/$filename" ]; then
                filesize=$(stat -c '%s' "$loc/$filename")
                if [ "$content_length" -gt 0 ]; then
                    percentage=$(printf "%d" "$((100 * filesize / content_length))")
                    log_message "Downloading '$filename' ... $(bytes_to_human "$filesize") ($percentage%)" 4 "$_STRLEN"
                else
                    log_message "Downloading '$filename' ... $(bytes_to_human "$filesize")" 4 "$_STRLEN"
                    if [ "$prevsize" -eq "$filesize" ]; then
                        ((k++))
                        if [ "$k" -eq 3 ]; then break; fi
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

ffx_extensions() {
    # Description:  Downloads and installs Firefox extensions.
    # Arguments:    None.
    local counter ext_filename ext_title ext_total ext_URL extension tmpdir

    if [ "${#_FFXEXTS[@]}" -eq 0 ]; then
        log_message "No Firefox extensions to install. Skipping ..." 3
        return 1
    fi

    ext_total="${#_FFXEXTS[@]}" # Total number of extensions to install

    # Process the extensions
    if mkdir -p "$_FFXDIR/$_FFXPRF"/extensions; then
        tmpdir=$(mktemp -d)

        # Read the list of installed extensions, if any.
        if ! touch "$_FFXDIR/$_FFXPRF"/extensions/xpi_list.txt; then
            log_message "Failed to create a list of extensions. Skipping ..." 3
        else
            IFS=$'\n' read -d '' -r -a _FFXEXTSLST <"$_FFXDIR/$_FFXPRF/extensions/xpi_list.txt"
        fi

        # Download extensions
        for extension in "${_FFXEXTS[@]}"; do
            ((counter++))
            # Check if extension is installed
            if isInstalled "$extension"; then
                log_message "Extension '$extension' is already installed. Skipping ..."
                continue
            fi

            # Fetch extension's title from Mozilla Addons
            ext_title=$(curl -sfL "$_FFXADDONSURL/$extension" | grep -oP '<h1 class=\"AddonTitle\"(?:\s[^>]*)?>\K.*?(?=<)')
            if [ -z "$ext_title" ]; then
                ext_title="$extension" # Get extension's title from the array, if fetch fails
            fi

            log_message "Downloading Firefox extension '$ext_title' ($counter/$ext_total) ..." 4 "$_STRLEN"

            # Fetch extension's URL from Mozilla Addons
            ext_URL=$(curl -sfL "$_FFXADDONSURL/$extension" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*.xpi")
            if [ -z "$ext_URL" ]; then
                log_message "Failed to fetch Firefox extension URL. Skipping ..." 3
                continue
            fi

            ext_filename=$(basename "$ext_URL")
            fetch_file "$ext_URL" "$ext_filename" "$tmpdir"

            # Rename extensions by ID
            log_message "Trying to determine ID for Firefox extension '$ext_title' ..."

            _XID=$(ffx_xID "$tmpdir/$ext_filename")
            #echo "$_XID"
            if [ -z "$_XID" ]; then
                cp "$tmpdir/$ext_filename" "$_BASEDIR"/data/firefox
                log_message "Failed to determine ID for extension '$xpi'. 
    Please try to add the extension manually from '$_BASEDIR/data/firefox'..." 3
            fi

            # Move extension to user profile
            if mv "$tmpdir/$ext_filename" "$_FFXDIR/$_FFXPRF/extensions/$_XID".xpi >/dev/null 2>&1; then
                log_message "Extension '$_XID.xpi' moved to profile $_FFXPRF" 1
            fi

            printf "%s:%s\n" "$extension" "$_FFXDIR/$_FFXPRF/extensions/$_XID.xpi" >>"$_FFXDIR/$_FFXPRF"/extensions/xpi_list.txt
        done
    else
        log_message "Failed to create extensions directory for '$_FFXPRF'"
    fi
}

ffx_permissions() {
    # Description:  Uses a Python script to interact with the SQLite database
    # Arguments:    None.
    local dbfile url

    if ! set_dependency python3; then
        log_message "Failed to locate Python on this system. Skipping ..." 3
        return 15
    fi

    if [ ${#_FFXCOOKIES[@]} -ne 0 ]; then
        dbfile="permissions.sqlite"
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
$(for url in "${_FFXCOOKIES[@]}"; do
            [ -n "$url" ] && echo "if not c.execute(\"SELECT 1 FROM moz_perms WHERE origin = ?\", (\"$url\",)).fetchone():
    c.execute(\"INSERT INTO moz_perms (origin, type, permission, expireType, expireTime, modificationTime) VALUES (?, 'cookie', 1, 0, 0, $_EXEC_START)\", (\"$url\",))"
        done)

conn.commit()   # save (commit) the changes
conn.close()    # close the connection
EOF
    fi

    if [ -f ./permissions.sqlite ]; then
        if [ -d "$_FFXDIR/$_FFXPRF" ]; then
            mv ./permissions.sqlite "$_FFXDIR/$_FFXPRF" # move the newly created file to Firefox profile.
        else
            log_message "Failed to set cookies: directory '$_FFXDIR/$_FFXPRF' unavailable" 3
            return 12
        fi
    else
        log_message "Failed to set cookies: file 'permissions.sqlite' unavailable" 3
    fi
}

ffx_profile() {
    # Description:  Identifies Firefox default profile.
    # Arguments:    None.
    local profile

    profile="$_FFXDIR"/profiles.ini
    log_message "[+] Identifying Firefox profile ..." 5
    if [ -f "$profile" ]; then # method #1
        _FFXPRF=$(grep -oE "^(Default|Path)=.*\-$_FFXCHANNEL$" "$profile" | cut -d= -f2 | head -1)
        [ -n "$_FFXPRF" ] && log_message "Firefox default profile: $_FFXPRF" 1
    elif [ -d "$_FFXDIR" ]; then
        # Identify profile directory, method #2.
        # useful when script re-launched after first run in the background,
        # when Firefox doesn't append 'Default=1' to the [Profile0] section of 'profiles.ini' (as in method #1).
        _FFXPRF=$(basename "$(find "$_FFXDIR" -maxdepth 1 -type d -name "*default*")")
        [ -n "$_FFXPRF" ] && log_message "Firefox default profile for user '$_USERNAME': $_FFXPRF" 1
    elif command -v firefox >/dev/null; then # both attempts failed, create a new profile
        firefox -CreateProfile "default-$_FFXCHANNEL" 2>&1 | log_trace "[FFX]" && sleep 3
        _FFXPRF=$(basename "$(find "$_FFXDIR" -maxdepth 1 -type d -name "*default*")")
        [ -n "$_FFXPRF" ] && log_message "Firefox default profile for user '$_USERNAME' created: $_FFXPRF" 1
    else
        log_message "Failed to identify default Firefox profile. Skipping ..." 3
        return 5
    fi

    # Run Firefox in the background to populate the profile directory with necessary files.
    firefox --headless -P "default-$_FFXCHANNEL" 2>&1 | log_trace "[FFX]" &
    sleep 3
    killproc firefox Firefox
}

ffx_xID() {
    # Description:  Determines Firefox extension ID.
    # Arguments:    One (1) - extension file (*.xpi).
    # alternative option to retrieve ID:
    # xid=$(unzip -p "$xpi" META-INF/mozilla.rsa | openssl pkcs7 -print -inform der | grep "subject.*CN\=" | head -1) && xid=${xid##*\=}
    local xid xpi

    if [ $# -ne 1 ]; then
        log_message "${FUNCTION[0]}: Wrong number of arguments: $#" 3
        return 3
    fi

    xpi="${1}"

    # Fetch the ID from extension's manifest
    keys=('applications' 'browser_specific_settings')
    for key in "${keys[@]}"; do
        xid=$(unzip -p "$xpi" manifest.json | jq -r '.'"$key"'.gecko.id' 2>&1)
        if [ "$xid" != 'null' ]; then
            echo "$xid"
            return 0
        fi
    done

    # Still trying ...
    if unzip -l "$xpi" | grep -q "mozilla.rsa"; then
        xid=$(unzip -p "$xpi" META-INF/mozilla.rsa | openssl asn1parse -inform DER | grep -A 1 commonName | grep -o '{.*}')
        if [ "$xid" != 'null' ]; then
            xid=$(trimex "$xid")
            echo "$xid"
            return 0
        fi
    fi

    # Final attempt
    if unzip -l "$xpi" | grep -q "cose.sig"; then
        xid=$(unzip -p "$xpi" META-INF/cose.sig | strings | grep '0Y0')
        if [ "$xid" != 'null' ]; then
            xid=$(trimex "$xid")
            echo "$xid"
            return 0
        fi
    fi

    return 13
}

finale() {
    # Description:  Prints out a message upon the completition of all the operations
    # Arguments:    None.
    local time

    if [[ "$_TIMER" = 1 ]]; then
        time=$(timer)
        log_message "POPPI took $time to complete all the assignments. See you next time!" 1 "$_STRLEN"
    else
        log_message "All assignments complete. See you next time!" 1 "$_STRLEN"
    fi
}

headline() {
    # Description:  Calculates the terminal workspace and prints out the headline with script's version number
    # Arguments:    None.
    local char columns dash_size min_cols msg1 msg2 msg_size

    columns=$(tput cols)
    min_cols=22
    msg1="POPPI v${_VERSION}"
    msg2="::::: $msg1 :::::"
    msg_size=$((${#msg1} + 3)) # incl. spaces on both sides of text and versions 10+, i.e., extra 3 chars
    dif=$((columns - msg_size))
    dash_size=$((dif / 2))
    [ $(("$dif" % 2)) -gt 0 ] && dash_size=$((dash_size + 1)) # normalise dash size when 'dif' is an odd number
    char=":"

    if [[ columns -le ${min_cols} ]]; then
        printf '%s\n\n' "${_CINFO}${msg2}${_CNONE}"
    else
        printf "${_CINFO}%0${dash_size}s" | tr " " ${char}
        printf '%s' " ${msg1} "
        printf "%0${dash_size}s" | tr " " ${char}
        printf '\n\n%s' "${_CNONE}"
    fi
}

isExternalDir() {
    # Description:  Checks if the directory is on external drive.
    # Argument:     One (1) - path to the directory represented as string.
    # Rationale:    If the directory to be bookmarked is on the external drive
    #               (see: _AUTODRIVES and "msc.automount_drives" in the user configuration file),
    #               which has not been mounted, [ -d "$path" ] will simply fail.
    #               Therefore, it is necessary to do this check before the directory is passed to `process_path()`.
    #               It's also imperative that bookmarking of directories takes place after (!) mounting external drives.
    local dir drive fstab

    [ $# != 1 ] && return 3
    dir="${1}"
    fstab=$(</etc/fstab)

    for drive in "${_AUTODRIVES[@]}"; do
        if grep -iq "$drive" <<<"$dir" >/dev/null 2>&1 &&
            grep -iq "$drive" <<<"$fstab" >/dev/null 2>&1; then
            return 0
        fi
    done

    return 13
}

isInstalled() {
    # Description:  Checks if Firefox exetnsion is installed.
    # Arguments:    One (1) - exetnsion (XPI) file's name.
    local arg xTitle xFile

    arg="${1}"
    for ext in "${_FFXEXTSLST[@]}"; do
        xTitle="${ext%%\:*}"
        xFile="${ext##*\:}"
        if [ "$xTitle" == "$arg" ] && [ -f "$xFile" ]; then
            return 0
        fi
    done

    return 13
}

killproc() {
    # Description:  Kills running processes when necessary for certain operations; used in `set_firefox()` and `set_installers()`.
    # Arguments:    Two (2)
    #   -- executable to kill
    #   -- executable title
    local prc title

    [ $# -eq 0 ] || [ $# -gt 2 ] && return 3
    prc="${1}"
    title="${2:-1}"
    while
        prc=$(pidof "$prc")
        [ -n "$prc" ]
    do
        if kill -9 "$prc" >/dev/null; then
            sleep 3
            log_message "Process $prc suspended ($title)" 1
            return 0
        fi
    done

    return 13
}

libreoffice_extensions() {
    # Description:  Downloads and installs LibreOffice extensions using LO's native facilities.
    # Arguments:    None.
    local counter dir extension ext_total gh_desc gh_repo loextension logstr oxtURL sfrurl tmpdir

    if [ "${#_LOEXTS[@]}" -eq 0 ]; then
        return 1
    fi

    if ! mkdir -p "$_LODIR"; then
        log_message "Failed to create directory '$_LODIR'. Skipping ..." 3
        return 5
    fi

    log_message "[+] Setting up LibreOffice extensions ..." 5
    # Check and install extensions from the local LibreOffice directory, if available
    if find "$_LODIR" -maxdepth 1 -type f -name '*.oxt' >/dev/null 2>&1; then
        for loextension in "$_LODIR"/*.oxt; do
            extension=$(basename "$loextension")
            # Check if extension is already installed
            if unopkg list | grep -q "$extension"; then
                log_message "Extension '$extension' already installed and activated. Skipping ..."
                continue
            fi

            log_message "[+] Installing '$loextension' ..." 5
            unopkg add -s -f "$loextension" 2>&1 | log_trace "[LOX]"
            # Unlock LO extension installer
            if ! killproc unopkg; then
                lockfile="$HOME"/.config/libreoffice/4/.lock
                [ -f "$lockfile" ] && rm "$lockfile" && log_message "Lock file (unopkg) removed"
            fi
        done
    fi

    for loextension in "${_LOEXTS[@]}"; do
        log_message "[+] Installing '$loextension' ..." 5
        ((counter++))
        ext_total="${#_LOEXTS[@]}"

        case "$loextension" in
        theme-sifr)
            # Declare local variables
            local dir gh_desc gh_repo sfrurl tmpdir

            if which libreoffice >/dev/null 2>&1; then
                gh_repo="libreoffice-style-sifr"
                gh_desc="Icon Theme Sifr"
                log_message "Getting the latest version of ${gh_desc}..."
                sfrurl="https://github.com/rizmut/$gh_repo/archive/master.tar.gz"
                # Check if archive file available locally
                if [ ! -f "$_LODIR/$gh_repo.tar.gz" ]; then
                    fetch_file $sfrurl "$gh_repo.tar.gz" "$_LODIR" && log_message "$gh_desc downloaded" 1
                fi

                # Check the file's integrity
                if tar -tf "$_LODIR/$gh_repo.tar.gz" &>/dev/null; then
                    log_message "Unpacking archive ..."
                    tar -xzf "$_LODIR/$gh_repo.tar.gz" -C "$_LODIR" 2>&1 | log_trace "[MSC]"
                    log_message "Deleting old $gh_desc ..."
                    sudo rm -f "/usr/share/libreoffice/share/config/images_sifr.zip" 2>&1 | log_trace "[MSC]"
                    sudo rm -f "/usr/share/libreoffice/share/config/images_sifr_dark.zip" 2>&1 | log_trace "[MSC]"
                    sudo rm -f "/usr/share/libreoffice/share/config/images_sifr_dark_svg.zip" 2>&1 | log_trace "[MSC]"
                    sudo rm -f "/usr/share/libreoffice/share/config/images_sifr_svg.zip" 2>&1 | log_trace "[MSC]"
                    log_message "Installing $gh_desc ..."
                    sudo mkdir -p "/usr/share/libreoffice/share/config" 2>&1 | log_trace "[MSC]"
                    sudo cp -R "$_LODIR/$gh_repo-master/build/images_sifr.zip" \
                        "/usr/share/libreoffice/share/config" 2>&1 | log_trace "[MSC]"
                    sudo cp -R "$_LODIR/$gh_repo-master/build/images_sifr_dark.zip" \
                        "/usr/share/libreoffice/share/config" 2>&1 | log_trace "[MSC]"
                    sudo cp -R "$_LODIR/$gh_repo-master/build/images_sifr_dark_svg.zip" \
                        "/usr/share/libreoffice/share/config" 2>&1 | log_trace "[MSC]"
                    sudo cp -R "$_LODIR/$gh_repo-master/build/images_sifr_svg.zip" \
                        "/usr/share/libreoffice/share/config" 2>&1 | log_trace "[MSC]"

                    for dir in \
                        /usr/lib64/libreoffice/share/config \
                        /usr/lib/libreoffice/share/config \
                        /usr/local/lib/libreoffice/share/config \
                        /opt/libreoffice*/share/config; do
                        [ -d "$dir" ] || continue
                        sudo ln -sf "/usr/share/libreoffice/share/config/images_sifr.zip" "$dir" 2>&1 | log_trace "[MSC]"
                        sudo ln -sf "/usr/share/libreoffice/share/config/images_sifr_dark.zip" "$dir" 2>&1 | log_trace "[MSC]"
                        sudo ln -sf "/usr/share/libreoffice/share/config/images_sifr_svg.zip" "$dir" 2>&1 | log_trace "[MSC]"
                        sudo ln -sf "/usr/share/libreoffice/share/config/images_sifr_dark_svg.zip" "$dir" 2>&1 | log_trace "[MSC]"
                    done

                    log_message "Clearing cache ..."
                    rm -rf "$_LODIR/$gh_repo-master" 2>&1 | log_trace "[MSC]"
                    log_message "Sifr theme for LibreOffice set" 1
                else
                    log_message "File '$gh_repo.tar.gz' not found or damaged.
    Please download again" 3
                fi
            else
                log_message "Failed to locate LibreOffice on this computer. Skipping ..." 3
            fi
            ;;
        *)
            # Download and install other extensions
            ext_title=$(curl -sfL "$_LOEXTSURL/$loextension" | awk -v RS='</h1>' '{gsub(/.*>/, ""); print $1}' | head -1)
            logstr="Downloading LibreOffice extension '$ext_title' ($counter/$ext_total) ..."
            log_message "$logstr" 4 "$_STRLEN"
            oxtURL=$(curl -sfL "$_LOEXTSURL/$loextension" | grep -o "assets.*oxt" | head -1)
            oxtURL=https://extensions.libreoffice.org/"$oxtURL"
            extension=$(basename "$oxtURL")

            # Check if extension is already installed
            if unopkg list | grep -q "$extension"; then
                log_message "Extension '$ext_title' already installed and activated. Skipping ..."
                continue
            fi

            if [ -z "$oxtURL" ]; then
                log_message "Extension '$ext_title' not found on remote server. Skipping ..." 3
                continue
            fi

            if fetch_file "$oxtURL" "$extension" "$_LODIR"; then
                log_message "Extension $ext_title downloaded" 1 "$_STRLEN"
            else
                log_message "Failed to download extension $ext_title. Skipping ..." 3 "$_STRLEN"
                continue
            fi

            # Unlock LO extension installer
            if ! killproc unopkg; then
                lockfile="$HOME"/.config/libreoffice/4/.lock
                [ -f "$lockfile" ] && rm "$lockfile" && log_message "Lock file (unopkg) removed"
            fi

            unopkg add -s -f "$_LODIR/$extension" 2>&1 | log_trace "[LOX]"
            if [ "${PIPESTATUS[0]}" -eq 0 ]; then
                log_message "Extension $ext_title installed" 1 "$_STRLEN"
            else
                log_message "Failed to install extension $ext_title" 3 "$_STRLEN"
                continue
            fi
            ;;
        esac
    done
}

log_and_exit() {
    # Description:  Logs the exit message and exits upon operation failure(s) .
    # Arguments:    Two (2)
    #   -- Message to be printed on the terminal and into the logfile.
    #   -- Custom exit code.
    local code msg

    msg="$1"
    code="${2:-1}"
    __logger_core "error" "$msg"
    exit "${code}"
}

log_message() {
    # Description:  Sends the log messages to the main logging function `__logger_core()` with corresponding message type.
    # Arguments:    Three (3)
    # -- Message to be logged.
    # -- Log level can be 0-info (default)
    #                     1-success
    #                     2-error
    #                     3-warning
    #                     other defaults to info.
    # -- Format of string spacing (default=22)
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
    # Description:  Adds timestamp to logs without using external utilities.
    # Arguments:    One (1).
    local errcode line prompt_active user_input

    prompt_active=false
    while true; do
        if [[ "$prompt_active" == 'false' ]]; then
            IFS= read -r -t1 line
            errcode=$?
        else
            # When prompt is active, read user input without timeout
            read -r user_input
            errcode=$?
            prompt_active=false
            __logger_core "prompt" "$(printf "%s %s" "${1:-NUL}" "$user_input")"
            printf "\033[2K\r"
            continue
        fi

        if ((errcode == 0)); then
            if ! pgrep "apt-get" >/dev/null && grep -Eq '[0-9]*\.?[0-9]+%' <<<"$line"; then
                perc=$(grep -Eo '[0-9]*\.?[0-9]+%' <<<"$line" | cut -d\. -f1)
                __logger_core "progress" "$(printf "%s %s" "${1:-NUL}" "Processing, please wait ... $perc%")"
            elif [[ "$line" =~ [WE]: ]]; then
                log_and_exit "${FUNCNAME[0]}: Try re-running the script in a few minutes." 14
            else
                __logger_core "trace" "$(printf "%s %s" "${1:-NUL}" "$line")"
            fi
        elif ((errcode > 128)) && [[ $line ]]; then
            printf "\033[2K\r"
            __logger_core "prompt" "$(printf "%s %s" "${1:-NUL}" "$line")"
            prompt_active=true
        elif ((errcode > 128)) && [[ -z $line ]]; then
            printf "\033[2K\r"
        else
            break
        fi
    done
}

misc_automount_drives() {
    # Description:  Adds the mounted external drives to /etc/fstab for automatic mounting on system reboot.
    # Arguments:    None.
    local drive drv label loc uuid

    [[ ${#_AUTODRIVES[@]} -eq 0 ]] && return 1

    # Check if /etc/fstab is writable
    if ! sudo test -w /etc/fstab 2>&1 | log_trace "[MSC]"; then
        log_message "File '/etc/fstab' is not writable. Skipping ..." 3
        return 7
    fi

    # Back up /etc/fstab
    if ! sudo cp /etc/fstab /etc/fstab.bak 2>&1 | log_trace "[MSC]"; then
        log_message "Failed to back up '/etc/fstab'. Skipping ..." 3
        return 6
    fi

    log_message "[+] Auto-mounting external drives ..." 5
    log_message "File '/etc/fstab' has been backed up" 1

    for label in "${_AUTODRIVES[@]}"; do
        drive=$(mount | grep "$label" | awk '{print $3}')
        if mountpoint -q "$drive"; then
            drv=$(mount | grep "$drive" | awk '{print $1}')
            uuid=$(sudo blkid -s UUID -o value "$drv") || continue

            # Make sure that the entry does not already exist in /etc/fstab.
            if ! grep -q "UUID=$uuid" /etc/fstab; then
                printf '%s\n' "UUID=$uuid /mnt/$label auto nosuid,nodev,nofail,x-gvfs-show 0 0" | sudo tee -a /etc/fstab >/dev/null &&
                    printf '%s\n' "file:///mnt/$label" >>"$_GTKBKMRK" &&
                    log_message "External drive '$label' mounted and bookmarked" 1
            else
                log_message "External drive '$label' already auto-mounted. Skipping ..." 3
            fi
        else
            log_message "Drive '$label' cannot be automounted. Skipping ..." 3
        fi
    done
}

misc_autostart() {
    # Description:  Sets package(s) to autostart on system reboot.
    # Arguments:    None.
    local package

    [[ ${#_AUTOSTART[@]} -eq 0 ]] && return 1
    log_message "[+] Enabling autostart for select packages ..."

    if mkdir -p "$HOME/.config/autostart" 2>&1 | log_trace "[AST]"; then
        for package in "${_AUTOSTART[@]}"; do
            if [ -f "$_USERAPPS/$package.desktop" ]; then
                cp "$_USERAPPS/$package.desktop" "$HOME/.config/autostart/" 2>&1 | log_trace "[AST]"
                [ "${PIPESTATUS[0]}" -eq 0 ] && log_message "'$package' will autostart on system reboot" 1
            else
                log_message "Desktop file for '$package' missing. Skipping ..." 3
            fi
        done
    else
        log_message "Failed to create directory '$HOME/.config/autostart'" 3
    fi
}

misc_bookmark_dirs() {
    # Description:  Bookmarks select directories to GNOME Files/Nautilus.
    # Arguments:    None.
    # Note:         Must be executed after `misc_automount_drives()`!
    local bdir

    [[ ${#_BOOKDIRS[@]} -eq 0 ]] && return 1
    log_message "[+] Bookmarking select directories ..." 5

    if [ -f "$_GTKBKMRK" ]; then
        declare -A bookmarks

        while IFS= read -r line; do
            bookmarks["$line"]=1
        done <"$_GTKBKMRK"

        for bdir in "${_BOOKDIRS[@]}"; do
            process_path "$bdir"
        done
    else
        log_message "Failed to bookmark directory(-ies)" 3
    fi
}

misc_connect_wifi() {
    # Description:  Checks Wi-Fi connection and re-connects the user, if necessary.
    # Arguments:    None.
    local i isConnected nomre SSID SSIDs wifi_pass

    isConnected=$(nmcli -t -f NAME connection show --active)
    if [ -z "$isConnected" ]; then # no active wi-fi connection
        log_message "[+] Scanning for available Wi-Fi networks ..." 5
        IFS=$'\n'
        mapfile -t SSIDs < <(nmcli -t -f SSID dev wifi) # append network names to an array

        # List available Wi-Fi networks
        for i in "${!SSIDs[@]}"; do
            log_message "$((i + 1)).${SSIDs[$i]}"
        done

        log_message "Please select the Wi-Fi network to connect to [1-$i]: " 6
        read -r -p "" nomre
        SSID=${SSIDs[$((nomre - 1))]}
        log_message "Please enter your Wi-Fi password: " 6
        read -r -s wifi_pass
        nmcli dev wifi connect "$SSID" password "$wifi_pass" 2>&1 | log_trace "[MSC]"
    fi
}

misc_gnome_calc_custom_functions() {
    # Description:  Adds custom functions to GNOME Calculator.
    # Arguments:    None.
    [[ ${#_GCALC[@]} -eq 0 ]] && return 3
    local func func_dir func_file

    func_dir="$HOME/.local/share/gnome-calculator"
    func_file='custom-functions'
    if mkdir -p "$func_dir" && touch "$func_dir"/"$func_file"; then
        log_message "[+] Setting user-defined functions for GNOME Calculator ..." 5
        for func in "${_GCALC[@]}"; do
            if ! printf '%s\n' "$func" >>"$func_dir"/"$func_file" 2>&1 | log_trace "[MSC]"; then
                log_message "Error appending to $func_dir/$func_file"
                return 7
            fi
        done

        log_message "User-defined functions added to GNOME Calculator." 1
    else
        log_message "Failed to add user-defined functions to GNOME Calculator. Skipping ..." 3
    fi
}

misc_set_avatar() {
    # Description:  Changes user's avatar on login screen.
    # Arguments:    None.
    [ "$_AVATARON" != 1 ] && return 2
    local imgsrc

    # Set locations for user files
    log_message "[+] Changing user avatar on login page ..." 5
    # Check if avatar image set
    if sudo grep -q "^Icon=.*$_AVATARIMG" "$_AVATARTXT"; then
        log_message "Avatar already set. Skipping ..."
        return 0
    fi

    # Set avatar image
    if [ -f "$_MISC/$_AVATARIMG" ]; then
        sudo cp "$_MISC/$_AVATARIMG" "$_AVATARDSTDIR" 2>&1 | log_trace "[MSC]"
        imgsrc="$_AVATARDSTDIR/$_AVATARIMG"
    else
        imgsrc=$(shuf -e "$_AVATARDSTDIR"/* 2>/dev/null | head -n 1)
    fi

    # Modify the user file and copy the avatar
    if sudo test -r "$_AVATARTXT"; then
        sudo sed -i "/Icon/c\Icon=$imgsrc" "$_AVATARTXT" 2>&1 | log_trace "[MSC]"
        [ "${PIPESTATUS[0]}" -eq 0 ] && log_message "Avatar for user '$_USERNAME' changed" 1
    else
        log_message "Failed to change avatar for user '$_USERNAME'. Skipping ..." 3
    fi
}

misc_set_crontab() {
    # Description:  Appends select jobs to user's crontab.
    # Arguments:    None.
    [ "${#_CRONLINE[@]}" -eq 0 ] && return 3
    log_message "[+] Setting up crontab jobs ..." 5
    local crondir

    # Create a temporary directory to store cronjobs
    crondir="$(mktemp -d)"
    cd "$crondir" || return 4

    # Append jobs to temporary file
    for line in "${_CRONLINE[@]}"; do
        printf "%s\n" "$line" >>"./temp_crontab"
    done

    # Copy the contents of the temporary file to user's crontab
    sudo -u "$_USERNAME" crontab "./temp_crontab" 2>&1 | log_trace "[MSC]"
    [ "${PIPESTATUS[0]}" -eq 0 ] && log_message "Crontab jobs set up for user '$_USERNAME'" 1
    cd ..
}

misc_set_geary() {
    # Description:  Sets options for GNOME Geary.
    # Arguments:    None.
    [[ "$_SETGEARY" -ne 1 ]] && return 2
    log_message "[+] Setting up GNOME Geary email client ..." 5

    if ! which geary 2>&1 | log_trace "[MSC]"; then
        log_message "Failed to locate Geary on this computer. Skipping ..." 3
        return 15
    fi

    geary 2>&1 | log_trace "[MSC]"
}

misc_set_msfonts() {
    # Description:  Downloads Microsoft fonts from the external server.
    # Arguments:    None.
    [[ "$_MSFONTS" -ne 1 ]] && return 2
    local dl_url fileid fontdir pkglist tmpdir tmpurl

    log_message "[+] Setting up Microsoft fonts ..." 5
    fontdir="/usr/share/fonts/truetype/ms-fonts"
    tmpdir=$(mktemp -d)

    if [ -d "$fontdir" ] && [ -n "$(ls -A1q "$fontdir")" ]; then
        log_message "Microsoft fonts already set. Skipping ..."
        return 0
    fi

    # Define the external server's URLs
    if sudo mkdir -p $fontdir 2>&1 | log_trace "[MSC]"; then
        pkglist='https://dx37.gitlab.io/dx37essentials/pkglist-x86_64.html'
        dl_url='https://dx37.gitlab.io/dx37essentials/x86_64'
        fileid='ttf-ms-win10-10.0.*.zst'
        cd "$tmpdir" || return 4

        # Set downloadable url
        fileid=$(curl -sL $pkglist | grep -oP "$fileid")
        tmpurl="$dl_url/$fileid"
        fetch_file "$tmpurl" "$fileid" "."
        if [ -f "./$fileid" ]; then
            sudo tar --strip-components=4 --directory="$fontdir" --use-compress-program=unzstd -xf "./$fileid" 2>&1 | log_trace "[FNT]"
            sudo fc-cache -Evr 2>&1 | log_trace "[FNT]"
        fi
    else
        log_message "Failed to create directory $fontdir" 3
    fi

    cd ..
}

misc_set_templates() {
    # Description:  Extracts template files for GNOME Gedit and LibreOffice to ~/Templates.
    # Arguments:    None.
    local tmpl

    log_message "[+] Setting up template files ..." 5
    tmpl="$_MISC"/templates.tar.gz

    if [ -f "$tmpl" ] && mkdir -p "$HOME/Templates"; then
        log_message "Unpacking template files ..."
        tar_extractor "$tmpl" 'nul' "$HOME/Templates" 2>&1 | log_trace "[TPL]" 2>&1 | log_trace "[TPL]"
        [ "${PIPESTATUS[0]}" -eq 0 ] && log_message "Template files unpacked to $HOME/Templates" 1
    else
        log_message "Failed to unpack template files" 3
    fi
}

misc_set_volume() {
    # Description:  Over-amplifies the default setting for system volume.
    # Arguments:    None.
    [[ "$_OVERAMPLIFY" -ne 1 ]] && return 2

    log_message "[+] Setting volume over-amplification on ..." 5
    if gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true 2>&1 | log_trace "[MSC]"; then
        # max value 'amixer' shows when volume control set with mouse
        pactl set-sink-volume @DEFAULT_SINK@ 153% 2>&1 | log_trace "[MSC]" && log_message "Volume set to over-amplify" 1
    else
        log_message "Failed to set volume to max" 3
    fi
}

misc_set_wallpaper() {
    # Description:  Enables the use of custom wallpapers.
    # Arguments:    None.
    [ "$_WPON" -ne 1 ] && return 2
    log_message "[+] Setting up wallpapers ..." 5
    local count f screen_resolution total_wprs urls wallpaper wpfile

    count=0
    screen_resolution=$(xdpyinfo | grep 'dimensions' | awk '{print $2}')
    # Create a local directory for wallpapers
    if [ -n "$_WPSRCDIR" ] && mkdir -p "$_WPSRCDIR" >/dev/null 2>&1; then
        log_message "Directory '$_WPSRCDIR' available" 1
        # Don't proceed any further, if user specified a custom wallpaper
        if echo "${_GSETTINGS[@]}" | grep -q "set_wallpaper:\/"; then
            wpfile=$(echo "${_GSETTINGS[@]}" | grep -oE "set_wallpaper:\/[^ ]*" | cut -d: -f2)
            log_message "Wallpaper to be set: $wpfile" && return 0
        fi
    else
        log_message "Failed to create directory '$_WPSRCDIR'. Skipping ..." 3
        return 5
    fi

    # Copy wallpapers from external location to the local directory
    if [ -n "$_WPEXTDIR" ] && [ -d "$_WPEXTDIR" ] && [ -n "$(ls -A1q "$_WPEXTDIR")" ]; then
        # Count the number of wallpapers in the directory
        total_wprs=$(find "$_WPEXTDIR" -maxdepth 1 -type f -not -name '.*' -printf '.' | wc -c)
        if ((total_wprs > 0)); then
            for f in "$_WPEXTDIR"/*; do
                if cp "$f" "$_WPSRCDIR" 2>&1 | log_trace "(MSC)"; then
                    ((count++))
                    log_message "Copied $count of $total_wprs files, please wait ..." 4
                fi
            done
            log_message "Copied $count of $total_wprs wallpaper files" 1 "$_STRLEN"

            # Select a random wallpaper from the copied files
            wpfile=$(shuf -e "$_WPSRCDIR"/*.{jpg,jpeg,png,svg,gif} 2>/dev/null | head -n 1)
        else
            log_message "Nothing to copy. Skipping ..."
        fi
    else
        # Download a random wallpaper
        urls=("$(curl -sfL "https://wallhaven.cc/api/v1/search?q=landscape&categories=101&purity=110&atleast=$screen_resolution&sorting=random&order=desc&ai_art_filter=0" | bash -c "jq -r '.data[].path'")")
        wpfile=$(echo "${urls[*]}" | shuf -n 1)
        fetch_file "$wpfile" '' "$_WPSRCDIR"
    fi

    # Set the wallpaper
    wallpaper=$(basename "$wpfile")
    if [ -f "$_WPSRCDIR/$wallpaper" ]; then
        gsettings set org.gnome.desktop.background picture-uri "file://$_WPSRCDIR/$wallpaper" &&
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$_WPSRCDIR/$wallpaper" &&
            log_message "Set a random wallpaper '$wallpaper'" 1 "$_STRLEN"
    else
        log_message "Failed to set a random wallpaper. Skipping ..." 3
    fi
}

misc_set_weekday() {
    # Description:  Sets Monday as the first day of the week.
    # Arguments:    None.
    #
    # Note:         An alternative option might be `sudo sed -i -e 's:first_weekday\ 3:first_weekday\ 2:g' /usr/share/i18n/locales/en_US`,
    #               but less preferred, as it assumes reverse engineering the en_US locale.
    [[ "$_SETMONDAY" -ne 1 ]] && return 2

    if [ "$LC_TIME" != 'en_GB.UTF-8' ] || ! grep -iq "export LC_TIME=.*en_gb\.utf\-8" "$_USERPROFILE"; then
        log_message "[+] Setting the first day of the week to Monday ..." 5

        # Generate a new locale
        if ! locale -a | grep -iq "en_gb\.utf8"; then
            sudo locale-gen en_GB.UTF-8 2>&1 | log_trace "[MSC]"
        fi

        # Set the new locale in user's ~/.profile
        printf '\n%s\n' 'export LC_TIME=en_GB.UTF-8' >>"$_USERPROFILE" 2>&1 | log_trace "[MSC]" &&
            log_message "First day of the week set to Monday." 1
    fi
}

miscops() {
    # Description:  The main function to execute miscellaneous operations in the order specified.
    # Arguments:    None.
    log_message "[+] Initialising miscellaneous operations ..." 5
    misc_set_volume
    misc_automount_drives
    misc_autostart
    misc_gnome_calc_custom_functions
    misc_set_weekday
    misc_bookmark_dirs
    misc_set_geary
    misc_set_msfonts
    misc_set_templates
    misc_set_crontab
    misc_set_wallpaper
}

offline() {
    # Description:  Runs the functions that do not need Internet connection upon the start of the script.
    # Arguments:    None.
    clear
    [[ "$_MAXWIN" = 1 ]] && xdotool windowsize "$(xdotool getactivewindow)" 110% 110% && sleep 1
    headline
    user_consent
    log_message "Initialisation and checks" 5
    __init_logfile
    log_message "[+] Permission checks ..." 5
    check_user
    system_check
}

online() {
    # Description:  Runs the functions that need Internet connection upon the start of the script.
    # Arguments:    None.
    offline
    screenlock
    check_internet
    system_update
    _ENDMSG='true'
}

process_path() {
    # Description:  Bookmarks processed path(s).
    # Arguments:    One (1) - path to directory to be bookmarked.
    local path

    path="${1}"
    if [ -d "$path" ] || isExternalDir "$path"; then
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

restart() {
    # Description:  Restarts the system after system update and the successful completition of all the operations.
    # Arguments:    None.
    local sec

    sec=10
    while [ $sec != 0 ]; do
        log_message "${_CWARN}POPPI will reboot in $sec seconds to apply the system updates${_CNONE}" 4 "$_STRLEN"
        sleep 1
        ((sec--))
    done

    log_message "" 4 "$_STRLEN"
    reboot
}

screenlock() {
    # Description:  Disables screen-lock and power suspend mode during system updates and re-enables them to previous (user) values when done.
    # Arguments:    None.
    if [[ $_isLOCKED -eq 0 ]]; then
        # Backup user values
        _SCREENLOCK=$(gsettings get org.gnome.desktop.session idle-delay | awk '{print $2}')
        _POWERMODE=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)

        # Lock the screen and disable auto-suspend
        gsettings set org.gnome.desktop.session idle-delay 'uint32 0' &&
            gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' &&
            _isLOCKED=1 &&
            log_message "Screen-lock and Auto-Suspend disabled" 1
    else
        # Restore previous values
        gsettings set org.gnome.desktop.session idle-delay "uint32 $_SCREENLOCK" &&
            gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "$_POWERMODE" &&
            _isLOCKED=0 &&
            log_message "Screen-lock and Auto-Suspend re-enabled" 1
    fi
}

set_colour() {
    # Description:  Converts RGB and Hex colours to ANSI format used in Bash
    # Arguments:    Two (2)
    #   -- User colour
    #   -- Fallback colour
    [[ $# -eq 0 ]] && log_message "ERR: ${FUNCNAME[0]} requires at least 1 argument" 2 && return 3

    local char char1 char2 clr defClr hex i pos pos1 pos2 sc tmpClr usrClr
    usrClr="${1}"
    defClr="${2}"
    hex='0123456789abcdef'
    sc=';'
    clr=''

    usrClr=${usrClr,,}                  # convert input to lowercase
    if [[ "$usrClr" == *"$sc"* ]]; then # check for default value
        echo -e "$usrClr"
        return 0
    elif [[ "$usrClr" =~ ^[r][g][b]\(([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\,([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\,([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\)$ ]]; then # regex pattern to check the RGB value
        usrClr="${usrClr#*\(}" && usrClr="${usrClr%\)*}" && usrClr="${usrClr//,/$sc}"                                                                                                                       # convert user value to 'semi-ANSI' format
        clr="$usrClr"
    elif [[ "$usrClr" =~ ^\#([a-f0-9]{6}|[a-f0-9]{3})$ ]]; then # regex pattern to check the 3- or 6-char hex value
        if [[ "${#usrClr}" -eq 4 ]]; then                       # hex shorthand, i.e., #1a3
            for ((i = 1; i <= 3; i++)); do
                char="${usrClr:$i:1}"                  # determine the char
                pos="${hex%"$char"*}" && pos="${#pos}" # determine char position/index in $hex
                tmpClr=$((pos * 16 + pos))             # convert to RGB value
                clr=${clr}${sc}${tmpClr}               # concatenate the string
            done
        else
            for ((i = 1; i <= 6; i += 2)); do # hex full, i.e., #12ab34
                char1="${usrClr:$i:1}"
                char2="${usrClr:$i+1:1}"
                pos1="${hex%"$char1"*}" && pos1="${#pos1}"
                pos2="${hex%"$char2"*}" && pos2="${#pos2}"
                tmpClr=$((pos1 * 16 + pos2))
                clr=${clr}${sc}${tmpClr}
            done
        fi
        clr=${clr#*;} # remove the leading semi-colon
    else
        echo -e "$defClr" # return default colour
        return 0
    fi

    echo -e "\e[38;2;${clr}m" # remove the leading semi-colon and evaluate
}

# shellcheck disable=SC1090
set_configs() {
    # Description:  Copies package configuration files and dotfiles to relevant directories.
    # Arguments:    None.
    log_message "Setting up user configuration files ..." 5

    # Copy user configuration files, if dir exists and not empty
    if [ -d "$_CONFIGS_DIR" ] && [ -n "$(ls -A1q "$_CONFIGS_DIR")" ]; then
        cp -a "$_CONFIGS_DIR"/. "$HOME" 2>&1 | log_trace "[CFG]" && log_message "Copied config files to '$HOME'" 1
    else
        log_message "Failed to locate directory '$_CONFIGS_DIR'" 3
    fi

    # Copy user configuration files for portable programs, if dir exists and not empty
    if [ -d "$_CONFIGSP_DIR" ] && [ -n "$(ls -A1q "$_CONFIGSP_DIR")" ]; then
        cp -a "$_CONFIGSP_DIR"/. "$_APPSDIR" 2>&1 | log_trace "[CFG]" && log_message "Copied config files for portables to '$_APPSDIR'" 1
    else
        log_message "Failed to locate directory '$_CONFIGSP_DIR'" 3
    fi

    # Copy and source dotfiles, if dir exists and not empty
    if [ -d "$_DOTFILES" ] && [ -n "$(ls -A1q "$_DOTFILES")" ]; then
        cp -a "$_DOTFILES"/. "$HOME" 2>&1 | log_trace "[CFG]" && log_message "Copied dotfiles to '$HOME'" 1
        source "$_USERPROFILE" "$_BASHRC" && log_message "Dotfiles set." 1
    else
        log_message "Failed to locate directory '$_DOTFILES'" 3
    fi
}

set_dependency() {
    # Description:  Installs packages required to run POPPI properly.
    # Arguments:    One (1) - dependency package to install.
    [[ $# -eq 0 ]] && log_and_exit "${FUNCNAME[0]}: At least 1 (one) argument required." 3
    local dep url

    stop_packagekitd
    # Set directory for binaries
    if ! mkdir -p "$_BINPATH" 2>&1 | log_trace "[DEP]"; then
        log_and_exit "${FUNCNAME[0]}: Failed to set '$_BINPATH'." 5
    else
        export PATH="$_BINPATH:$PATH"
    fi

    # Iterate over each package provided as argument
    for dep in "$@"; do
        log_message "[+] Setting dependency package '$dep' ..." 5

        # Install the latest versions of prerequisites 'curl', 'jsonschema', and 'jq' — the three powerhorses of the script
        # Fall back to default/installed versions, if fail.
        if [ "$dep" == 'curl' ]; then
            url=$(curl -sfL 'https://api.github.com/repos/moparisthebest/static-curl/releases/latest' | jq -r '.assets[].browser_download_url' | grep 'curl-amd64')
        elif [ "$dep" == 'jq' ]; then
            url=$(curl -sfL 'https://api.github.com/repos/jqlang/jq/releases/latest' | jq -r '.assets[].browser_download_url' | grep 'jq-linux-amd64')
        fi

        if [ -n "$url" ]; then
            fetch_file "$url" "$dep" "$_BINPATH" && chmod +x "$_BINPATH/$dep"
            log_message "Binary package '$dep' downloaded and set" 1
            continue
        fi

        if [[ "$dep" =~ ^(cmake|jsonschema|meson|ninja|pdf.tocgen)$ ]] && ! pip3 show "$dep" >/dev/null 2>&1; then
            command -v pip3 >/dev/null || set_pip # Check if pip3 installed and install it, if not
            pip3 install -U "$dep" | log_trace "[DEP]"
            log_message "Python dependency package '$dep' installed" 1
            continue
        elif pip3 show "$dep" >/dev/null 2>&1; then
            log_message "Python dependency package '$dep' found" 1
            continue
        fi

        # Install the rest of dependencies, as necessary
        if command -v "$dep" >/dev/null || dpkg -l | grep -q "^ii.*$dep"; then
            log_message "Dependency package '$dep' found"
        elif sudo apt-get install -y "${dep}" 2>&1 | log_trace "[DEP]"; then
            [ "${PIPESTATUS[0]}" -eq 0 ] && log_message "Dependency package '$dep' installed" 1
        else
            log_and_exit "${FUNCNAME[0]}: Failed to install dependency package '$dep'" 16
        fi

    done

}

set_favourites() {
    # Description:  Searches and adds program icons to GNOME Favourites/Dock, if the programs are available on the system.
    # Arguments:    None.
    local dFile fav settings

    if [ "${#_GFAVOURITES}" -eq 0 ]; then
        log_message "No favourite programs to dock. Skipping ..." 3
        return 1
    fi

    # Try to find the associated launcher file for the favourite program
    log_message "Adding favourite programs to dock ..." 5
    for fav in "${_GFAVOURITES[@]}"; do
        fav_="${fav%%\ *}" # retrieve the first word in favourite package's title
        if which "$fav_" >/dev/null 2>&1 || [[ $(dpkg -l | grep "$fav_") =~ ^ii.*"[$fav_]" ]]; then
            # Find and assign the launcher to a variable, if the names of launcher and favourite program match
            if [ -f "$_USERAPPS"/"$fav".desktop ] || [ -f /usr/share/applications/"$fav".desktop ]; then
                dFile="$fav".desktop
            else
                # Otherwise, check the content of the launcher file, if it matches the favourite package's title
                dFile=$(grep -riE "(Name|Exec)=.*$fav" "$_USERAPPS"/*.desktop /usr/share/applications/*.desktop | grep -v 'daemon' | head -n 1)
                dFile=$(basename "${dFile%\:*}")
            fi

            # Create a comma-separated string to add to GSettings
            if [ -n "$dFile" ]; then
                settings+="'$dFile', "
            fi
        else
            log_message "Failed to determine '$fav' on the system. Skipping ..." 3
        fi
    done

    # Add favourites to GSettings
    settings='['${settings%,*}']' # remove last comma & append brackets
    if [ -n "$settings" ]; then
        gsettings set org.gnome.shell favorite-apps "$settings" 2>&1 | log_trace "FAV"
        [ "${PIPESTATUS[0]}" -eq 0 ] && log_message "Favourite programs docked" 1
    else
        log_message "Failed to add favourite programs to dock. Skipping ..." 3
    fi
}

set_firefox() {
    # Description:  Sets Firefox parameters (extensions, privacy, settings, etc.) based on user input.
    # Arguments:    None.
    [[ "$_FFXCONFIG" != 1 ]] && return 2
    log_message "Setting up Firefox ..." 5
    local ffv file url UUID

    # Firefox exists?
    if which firefox >/dev/null 2>&1 | log_trace "[FFX]"; then
        if [[ -f $_FFXAPPINI ]]; then
            ffv=$(grep "^Version" <"${_FFXAPPINI}" | cut -d= -f2 | cut -d\. -f1)

            # Compatibility check
            if [[ $ffv -le 89 ]]; then
                log_message "Your version of Firefox is not compatible with this script.
    Please upgrade and re-run the script as './${_SCRIPT} -f' to apply Firefox settings." 3
                return 17
            fi

            # Check for Firefox channel info
            if [[ -f "$_FFXCHANNELFILE" ]]; then
                _FFXCHANNEL=$(grep "channel" <"$_FFXCHANNELFILE" | cut -d\" -f4)
            else
                _FFXCHANNEL="undefined"
            fi

            log_message "Mozilla Firefox version: ${ffv}-${_FFXCHANNEL}"
        else
            log_message "Failed to determine Firefox version" 3
        fi
    else
        log_message "Mozilla Firefox not found" 3
        return 15
    fi

    # Firefox running?
    if pgrep "firefox" >/dev/null 2>&1; then
        log_message "Cannot proceed while Firefox is running.
    Please quit Firefox and re-run this script as './${_SCRIPT} -f' to apply Firefox settings." 3
        return 18
    fi

    ffx_profile                                                       # Determine Firefox profile
    ffx_permissions && log_message "Firefox persistent cookies set" 1 # Create the file 'permissions.sqlite' to keep custom cookies

    if [ -d "$_FFXDIR/$_FFXPRF" ]; then
        ffx_extensions # Download and install extensions

        # Copy user's contents to Firefox profile
        if [ -d "$_BASEDIR"/data/firefox ]; then
            cp -a "$_BASEDIR"/data/firefox/. "$_FFXDIR/$_FFXPRF" 2>&1 | log_trace "[FFX]"
        fi

        # Determine and Set UUID for GroupSpeedDial: this is a private case to ensure consistency between prefs.js and user-overrides.js
        # Otherwise (after running the Arkenfox stuff) the homepage fails to load GlobalSpeedDial also because the extension UUID values
        # are assigned/changed automatically by Firefox with each extension installation.
        #
        # run in the background again to add extension UUIDs to prefs.js
        if [ "$_FFXHOMEPAGE" -eq 1 ]; then
            firefox --headless -P "$(basename "$_FFXPRF" | cut -d\. -f2)" 2>&1 | log_trace "[FFX]" &
            sleep 7
            killproc firefox Firefox

            if [ -f "$_FFXDIR/$_FFXPRF/$_FFXPREFS" ] && [ -f "$_FFXDIR/$_FFXPRF/$_FFXUSEROVERRIDES" ]; then
                # Extract UUID from 'prefs.js'
                UUID=$(grep -oP '(?<="admin@fastaddons\.com_GroupSpeedDial\\"\:\\")[^"\\]+' "$_FFXDIR/$_FFXPRF/$_FFXPREFS")

                # Check for UUID
                if [ -z "$UUID" ]; then
                    log_message "GroupSpeedDial UUID not found in '$_FFXPREFS'. Skipping ..." 3
                elif grep -q "$UUID" "$_FFXDIR/$_FFXPRF/$_FFXUSEROVERRIDES"; then
                    log_message "GroupSpeedDial UUID already set in '$_FFXUSEROVERRIDES'. Skipping ..."
                else
                    # Replace the UUID
                    sed -i "/browser\.startup\.homepage/c\user_pref\(\"browser\.startup\.homepage\"\,\ \"moz-extension\:\/\/$UUID\/dial\.html\"\);" "$_FFXDIR/$_FFXPRF/$_FFXUSEROVERRIDES" &&
                        log_message "GroupSpeedDial UUID replaced successfully in '$_FFXUSEROVERRIDES'" 1
                fi
            else
                log_message "File '$_FFXPREFS' missing. Skipping ..." 3
            fi
        fi
    else
        log_message "Firefox profile directory missing. Skipping ..." 3
        return 12
    fi

    # Set Arkenfox stuff
    if [ "$_FFXPRIVACY" -eq 1 ]; then
        if [ -f "$_FFXDIR/$_FFXPRF/user-overrides.js" ]; then
            for file in updater.sh prefsCleaner.sh user.js; do
                url=https://raw.githubusercontent.com/arkenfox/user.js/master/"$file"
                fetch_file "$url" "$file" "$_FFXDIR/$_FFXPRF" && log_message "Downloaded '$file' to '$_FFXDIR/$_FFXPRF'" 1
            done

            # Set permissions to user preference files
            cd "$_FFXDIR/$_FFXPRF" || return 4
            if [ -f "./updater.sh" ]; then
                chmod +x "./updater.sh"
                bash "./updater.sh" 2>&1 | log_trace "[FFX]"
            else
                log_message "File ./updater.sh cannot be executed" 3
            fi

            if [ -f "./prefsCleaner.sh" ]; then
                chmod +x "./prefsCleaner.sh"
                bash "./prefsCleaner.sh" 2>&1 | log_trace "[FFX]"
            else
                log_message "File ./prefsCleaner.sh cannot be executed" 3
            fi
        fi
    else
        log_message "Failed to identify Firefox user profile." 3
    fi
}

set_gnome_extensions() {
    # Description:  Downloads and enables GNOME extensions.
    # Arguments:    None.
    local download_url dKey dVal encoded_search_term ext_data extension extensions extensions_list
    local filename gnome_version id parameter schema search_path tmp_dir uuid UUIDs

    if which gnome-extensions >/dev/null 2>&1 | log_trace "[GNM]" && [ "${#_GNOMEXTS[@]}" -ne 0 ]; then
        log_message "Installing GNOME extensions ..." 5
        check_internet
        # Retrieve the GNOME version
        # Reason: GNOME Extensions provides individual downloads based on GNOME versions
        gnome_version=$(sudo gnome-shell --version 2>&1 | grep -oP '\d+\.\d+' | awk -F. '{print $1}')
        tmp_dir=$(mktemp -d)
        cd "$tmp_dir" || return 4

        # Download the user-defined extensions
        for extension in "${_GNOMEXTS[@]}"; do
            encoded_search_term="${extension// /%20}"                                                              # Replace blank spaces with '%20' in extension name
            extensions_list=$(curl -s "https://extensions.gnome.org/extension-query/?search=$encoded_search_term") # Fetch the search results in JSON format

            # Extract the download URL and UUID from the downloaded data
            ext_data=$(echo "$extensions_list" | jq --arg gnome_version "$gnome_version" --arg extension "$extension" '
                .extensions[] | 
                    select((.name | gsub("[^a-zA-Z0-9]"; "") | test($extension | gsub("[^a-zA-Z0-9]"; "") | ascii_downcase; "i"))) | 
                    select(.shell_version_map[$gnome_version] != null) | 
                {
                    download_url: ("https://extensions.gnome.org/download-extension/" + .uuid + ".shell-extension.zip?version_tag=" + (.shell_version_map[$gnome_version].pk | tostring)),
                    uuid: .uuid
                }')

            # Download the extension
            download_url=$(echo "$ext_data" | jq -r '.download_url')
            uuid=$(echo "$ext_data" | jq -r '.uuid')
            UUIDs+=("$uuid")
            filename=$(basename "$download_url")
            filename=${filename%%\?*} # Remove the extra 'version_tag' string from the filename before download
            fetch_file "$download_url" "$filename" "."
            log_message "[+] Installing GNOME extension '$extension'"
            gnome-extensions install --force "$filename" 2>&1 | log_trace "[GNM]"

            if [ "${PIPESTATUS[0]}" -eq 0 ]; then
                extensions+=("$extension")
                log_message "GNOME extension '$extension' installed" 1 "$_STRLEN"
            else
                log_message "Failed to install GNOME extension '$extension'" 3 "$_STRLEN"
                return 16
            fi
        done
    else
        log_message "Failed to locate GNOME Extensions Manager. Skipping ..." 3
        return 15
    fi

    # Enable GNOME extensions
    if [ "${#_GNOMEXTSET}" -ne 0 ]; then
        log_message "[+] Enabling GNOME extensions ..." 5
        # Restart the shell; otherwise extensions cannot be enabled
        pgrep "gnome-shell" >/dev/null && killall -3 gnome-shell && sleep 3
        if mkdir -p "$_GTKEXTS"; then
            for ((id = 0; id < "${#UUIDs[@]}"; id++)); do
                if gnome-extensions enable "${UUIDs[$id]}" 2>&1 | log_trace "[GNM]"; then
                    if [ "${PIPESTATUS[0]}" -eq 0 ]; then
                        log_message "GNOME extension '${extensions[$id]}' enabled" 1
                    else
                        log_message "Failed to enable GNOME extension '${extensions[$id]}'" 3
                    fi
                fi
            done

            # Set extension parameters
            for parameter in "${_GNOMEXTSET[@]}"; do
                # Normalize the search string
                search_path="${parameter%%\ *}"
                search_path="${search_path%\/*}"

                # Check if the extension parameter matches the installed extension
                for schema in "${_GTKEXTS}"/*/schemas/*.xml; do
                    if grep -q "$search_path" "$schema"; then
                        # Write extension values to GNOME Shell
                        dKey=$(echo "$parameter" | cut -d' ' -f1)
                        dVal=$(echo "$parameter" | cut -d' ' -f2-)
                        dconf write "$dKey" "$dVal"
                    fi
                done
            done
        else
            log_message "Failed to locate the GNOME extensions directory" 3
        fi
    fi

    cd ..
}

set_gsettings() {
    # Desription:   Sets GNOME Gsettings parameters for the user.
    # Arguments:    None.
    local jKey jVal key l langs schema setting value xkb_lng xkb_options

    log_message "Setting GNOME settings for user '$_USERNAME' ..." 5
    # Store the existing value of 'xkb-options' to ensure non-destructive processing of settings.
    # The string will be appended, as necessary.
    xkb_options=$(gsettings get org.gnome.desktop.input-sources xkb-options | sed -E 's/^\[(.*)\]$/\1/')

    # Set pre-defined GSettings
    for setting in "${_GSETTINGS[@]}"; do
        jKey="${setting%\:*}"
        jVal="${setting#*\:}"

        # Check individual values instead of the state of _GSETTINGS().
        # Otherwise, the function will exit prematurely before processing custom settings down below.
        [ -z "$jVal" ] && continue

        case "$jKey" in
        button_layout)
            gsettings set org.gnome.desktop.wm.preferences button-layout "'appmenu:${jVal}'"
            ;;
        button_position)
            if [ "$jVal" == 'left' ]; then
                value=$(gsettings get org.gnome.desktop.wm.preferences button-layout)
                value="${value#*\:}" && value="${value%\'*}"
                gsettings set org.gnome.desktop.wm.preferences button-layout "'${value}:'"
            fi
            ;;
        capslock_as_extra_escape)
            if [ "${xkb_options:0:1}" == '@' ]; then # the value is empty
                xkb_options="'caps:escape'"
            elif [ "$jVal" -eq 1 ] && ! grep -q "'caps:escape'" <<<"$xkb_options"; then
                xkb_options=${xkb_options}", 'caps:escape'" # Append a new value to the string
            fi
            ;;
        centre_windows_on_open)
            if [ "$jVal" -eq 1 ]; then
                gsettings set org.gnome.mutter center-new-windows true
            else
                gsettings reset org.gnome.mutter center-new-windows
            fi
            ;;
        check_alive_timeout)
            gsettings set org.gnome.mutter check-alive-timeout "$jVal"
            ;;
        compose_key)
            if [ "${xkb_options:0:1}" == '@' ]; then # the value is empty
                xkb_options="'compose:$jVal'"
            elif ! grep -q "'compose:$jVal'" <<<"$xkb_options"; then
                xkb_options=${xkb_options}", 'compose:$jVal'"
            fi
            ;;
        font_scaling_factor)
            gsettings set org.gnome.desktop.interface text-scaling-factor "$jVal"
            ;;
        font_terminal)
            gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:"$_DFTRMPRFL"/ font "$jVal"
            ;;
        font_ui)
            gsettings set org.gnome.desktop.interface font-name "$jVal"
            ;;
        keyboard_languages)
            IFS=,
            read -ra langs <<<"$jVal"
            for l in "${langs[@]}"; do
                xkb_lng=${xkb_lng}"('xkb', '$l'), "
            done

            xkb_lng="[${xkb_lng%,*}]" # remove the trailing comma
            gsettings set org.gnome.desktop.input-sources sources "$xkb_lng"
            ;;
        launch_browser)
            gsettings set org.gnome.settings-daemon.plugins.media-keys www "['$jVal']"
            ;;
        launch_files)
            gsettings set org.gnome.settings-daemon.plugins.media-keys home "['$jVal']"
            ;;
        launch_settings)
            gsettings set org.gnome.settings-daemon.plugins.media-keys control-center "['$jVal']"
            ;;
        launch_terminal)
            gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "['$jVal']"
            ;;
        set_wallpaper)
            if [ -f "$jVal" ] && [ -d "$_WPSRCDIR" ]; then
                cp "$jVal" "$_WPSRCDIR"
                jVal=$(basename "$jVal")
                gsettings set org.gnome.desktop.background picture-uri "'file://$_WPSRCDIR/$jVal'"
                gsettings set org.gnome.desktop.background picture-uri-dark "'file://$_WPSRCDIR/$jVal'"
            fi
            ;;
        show_seconds)
            if [ "$jVal" -eq 1 ]; then
                gsettings set org.gnome.desktop.interface clock-show-seconds true
            else
                gsettings reset org.gnome.desktop.interface clock-show-seconds
            fi
            ;;
        show_weekdays)
            if [ "$jVal" -eq 1 ]; then
                gsettings set org.gnome.desktop.interface clock-show-weekday true
            else
                gsettings reset org.gnome.desktop.interface clock-show-weekday
            fi
            ;;
        switch_workspace_down)
            gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-down "['$jVal']"
            ;;
        switch_workspace_up)
            gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-up "['$jVal']"
            ;;
        windows_close)
            gsettings set org.gnome.desktop.wm.keybindings close "['$jVal']"
            ;;
        windows_maximise)
            gsettings set org.gnome.desktop.wm.keybindings maximize "['$jVal']"
            ;;
        windows_minimise)
            gsettings set org.gnome.desktop.wm.keybindings minimize "['$jVal']"
            ;;
        *)
            command
            ;;
        esac
    done

    # Write the full string back
    if [ -n "$xkb_options" ]; then
        gsettings set org.gnome.desktop.input-sources xkb-options "[${xkb_options}]"
    fi

    if [ ${#_GCSETTINGS[@]} -eq 0 ]; then
        log_message "No extra GNOME settings to process. Skipping ..." 3
        return 1
    fi

    # Set custom GSettings
    for setting in "${_GCSETTINGS[@]}"; do
        # Expand the Bash variables in JSON data, if any
        if [[ $setting == *'$'* ]]; then
            setting=$(eval echo "\"$setting\"")
        fi

        IFS=' ' read -r schema key value <<<"$setting"                   # populate keys with values from the array
        gsettings set "$schema" "$key" "$value" 2>&1 | log_trace "[GST]" # set the key/value pairs
    done

    log_message "GNOME settings set" 1
}

set_installers() {
    # Description:  Downloads and installs packages that require installation (e.g., .DEB files).
    # Arguments:    None.
    log_message "Initialising installation of additional programs ..." 5
    local CFLAGS LDFLAGS PKG_CONFIG_PATH amr amr_DIR debfile direx file filename gsm gsm_DIR
    local lame lame_DIR libex opus opus_DIR package perc speex speex_DIR temp_dir title url version

    # Check if the global array variable is not empty
    if [ "${#_INSTALLERS[@]}" -eq 0 ]; then
        log_message "Nothing to install. Skipping ..." 3
        return 1
    fi

    stop_packagekitd
    temp_dir=$(mktemp -d)
    for title in "${_INSTALLERS[@]}"; do
        package="${title,,}" # convert to lowercase
        log_message "[+] Installing $title ..." 5
        case "$package" in
        calibre)
            if ! which "$package" >/dev/null 2>&1; then
                set_dependency "libxcb-cursor0"
                url='https://download.calibre-ebook.com/linux-installer.sh'
                filename=$(basename "$url")
                fetch_file "$url" "$filename" "$temp_dir"
                chmod +x "$temp_dir"/linux-installer.sh
                echo
                sudo sh "$temp_dir"/linux-installer.sh 2>&1 | log_trace "[INS]"
                [ "${PIPESTATUS[0]}" -eq 0 ] && log_message "$title installation complete" 1
                rm "$temp_dir"/linux-installer.sh >/dev/null 2>&1 | log_trace "[INS]"
            else
                log_message "$title already installed. Skipping ..."
            fi
            ;;
        dconf-editor)
            if ! which "$package" >/dev/null 2>&1; then
                sudo apt-get install "$package" 2>&1 | log_trace "[INS]"
                [ "${PIPESTATUS[0]}" -eq 0 ] && log_message "$title installation complete" 1
            else
                log_message "$title already installed. Skipping ..."
            fi
            ;;
        ffmpeg_s)
            # shellcheck disable=2034,2154
            if ! which ffmpeg >/dev/null 2>&1; then
                cd "$temp_dir" || return 4

                # Install dependencies
                set_dependency autoconf \
                    automake \
                    build-essential \
                    checkinstall \
                    cmake \
                    git-core \
                    libass-dev \
                    libfreetype6-dev \
                    libgnutls28-dev \
                    libmp3lame-dev \
                    libsdl2-dev \
                    libtool \
                    libunistring-dev \
                    libva-dev \
                    libvdpau-dev \
                    libvorbis-dev \
                    libxcb1-dev \
                    libxcb-shm0-dev \
                    libxcb-xfixes0-dev \
                    meson \
                    nasm \
                    ninja \
                    pkg-config \
                    texinfo \
                    wget \
                    yasm \
                    zlib1g-dev | log_trace "[INS]"

                # Download extra libraries and set prerequisites
                log_message "[+] Processing extra libraries ..." 5
                mkdir -p "$temp_dir/build"
                mkdir -p "$temp_dir/build/local/include"
                mkdir -p "$temp_dir/build/local/lib"
                mkdir -p "$temp_dir/build/local/lib/pkgconfig"
                mkdir -p "$temp_dir/Output"
                export CPPFLAGS="-fPIC"
                export CFLAGS="-fPIC"
                export CXXFLAGS="-fPIC"
                export LDFLAGS="-fPIC"
                export PATH="$HOME/bin:$PATH"
                PKG_CONFIG_PATH="$temp_dir/build/local/lib/pkgconfig"
                export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

                gsm='http://www.quut.com/gsm/gsm-1.0.22.tar.gz'
                speex='http://downloads.us.xiph.org/releases/speex/speex-1.2.1.tar.gz'
                amr='https://downloads.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-0.1.5.tar.gz'
                lame='https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz'
                opus='https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz'

                for libex in gsm speex amr lame opus; do
                    eval url="\$$libex"
                    filename=$(basename "$url")

                    if [ ! -f "$filename" ]; then
                        if ! fetch_file "$url" "$filename" "."; then
                            log_message "Failed to download required library. Please check if URLs are valid" 3
                            return 20
                        fi
                    fi

                    # Extract the libraries
                    eval direx="$(tar tf "$filename" | sed -e '1s/\/.*//;2,$d')"
                    [ ! -x "$direx" ] && tar xf "$filename"
                    eval "${libex}_DIR"="$direx"
                done

                # Set library GSM
                if true; then
                    cd "$gsm_DIR" || return 4
                    make CCINC="${CFLAGS}" LDINC="${LDFLAGS}" lib/libgsm.a 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "GSM make failed. Skipping ..." 3
                        return 16
                    fi

                    mkdir -p "$temp_dir/build/local/include/gsm"
                    cp -pR inc/* "$temp_dir/build/local/include/gsm" 2>&1 | log_trace "[INS]"
                    cp -pR "$(find . -name \*.a)" "$temp_dir/build/local/lib" 2>&1 | log_trace "[INS]"
                    cd ..
                fi

                # Set library Speex
                if true; then
                    cd "$speex_DIR" || return 4
                    ./configure --enable-static=yes --enable-shared=no --disable-dependency-tracking 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Speex configure failed. Skipping ..." 3
                        return 16
                    fi

                    make -C libspeex 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Speex make failed. Skipping ..." 3
                        return 16
                    fi

                    make -C include 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Speex make failed. Skipping ..." 3
                        return 16
                    fi

                    cp -pR include/* "$temp_dir/build/local/include" 2>&1 | log_trace "[INS]"
                    cp -pR speex.pc "$temp_dir/build/local/lib/pkgconfig" 2>&1 | log_trace "[INS]"
                    cp -pR "$(find . -name \*.a)" "$temp_dir/build/local/lib" 2>&1 | log_trace "[INS]"
                    cd ..
                fi

                # Set library Lame
                if true; then
                    cd "$lame_DIR" || return 4
                    ./configure --enable-static=yes --enable-shared=no --disable-dependency-tracking --disable-frontend 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Lame configure failed. Skipping ..." 3
                        return 16
                    fi

                    make -C mpglib 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Lame mpglib make failed. Skipping ..." 3
                        return 16
                    fi

                    make -C libmp3lame 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Lame libmp3lame make failed. Skipping ..." 3
                        return 16
                    fi

                    mkdir -p "$temp_dir/build/local/include/lame"
                    cp -p include/* "$temp_dir/build/local/include/lame" 2>&1 | log_trace "[INS]"
                    cp -pR "$(find . -name \*.a)" "$temp_dir/build/local/lib" 2>&1 | log_trace "[INS]"
                    cd ..
                fi

                # Set library Opus
                if true; then
                    cd "$opus_DIR" || return 4
                    ./configure --enable-static=yes --enable-shared=no --disable-dependency-tracking --disable-doc --disable-extra-programs 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Opus configure failed. Skipping ..." 3
                        return 16
                    fi

                    make 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Opus make failed. Skipping ..." 3
                        return 16
                    fi

                    cp -pR opus.pc "$temp_dir/build/local/lib/pkgconfig" 2>&1 | log_trace "[INS]"
                    cp -pR include/opus.h include/opus_multistream.h include/opus_types.h include/opus_defines.h include/opus_projection.h "$temp_dir/build/local/include" 2>&1 | log_trace "[INS]"
                    cp -pR "$(find .libs -name \*.a)" "$temp_dir/build/local/lib" 2>&1 | log_trace "[INS]"
                    cd ..
                fi

                # Set library Opencore-AMR
                if true; then
                    cd "$amr_DIR" || return 4
                    ./configure --enable-static=yes --enable-shared=no --disable-dependency-tracking 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Opencore-AMR configure failed. Skipping ..." 3
                        return 16
                    fi

                    make -C amrnb 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Opencore-AMRNB make failed. Skipping ..." 3
                        return 16
                    fi

                    make -C amrwb 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "Opencore-AMRWB make failed. Skipping ..." 3
                        return 16
                    fi

                    mkdir -p "$temp_dir/build/local/include/opencore-amrnb"
                    mkdir -p "$temp_dir/build/local/include/opencore-amrwb"
                    cp -pR amrnb/*.h "$temp_dir/build/local/include/opencore-amrnb" 2>&1 | log_trace "[INS]"
                    cp -pR amrwb/*.h "$temp_dir/build/local/include/opencore-amrwb" 2>&1 | log_trace "[INS]"
                    # shellcheck disable=2038
                    find . -name "*.a" | xargs -I {} cp -pR {} "$temp_dir/build/local/lib" 2>&1 | log_trace "[INS]"
                    cd ..
                fi

                # Download and extract FFMPEG
                log_message "[+] Processing $title ..." 5
                url=$(curl -sfL 'https://ffmpeg.org/download.html' | grep -o "http.*.tar.xz")
                filename=$(basename "$url")
                fetch_file "$url" "$filename" "."

                if which checkinstall >/dev/null; then
                    tar_extractor "./$filename" 'nul' "." 2>&1 | log_trace "[INS]"
                    version="$(<VERSION)"

                    # Alternative way to determine FFMPEG version
                    if [ -z "$version" ]; then
                        version="${filename#*\-}"
                        version="${version%\.tar*}"
                    fi

                    # Set FFMPEG configuration parameters
                    sh ./configure \
                        --pkg-config-flags="--static" \
                        --toolchain=hardened \
                        --arch=x86_64 \
                        --disable-avdevice \
                        --disable-debug \
                        --disable-doc \
                        --disable-static \
                        --disable-stripping \
                        --enable-gnutls \
                        --enable-gpl \
                        --enable-libgsm \
                        --enable-libmp3lame \
                        --enable-libopencore-amrnb \
                        --enable-libopencore-amrwb \
                        --enable-libopus \
                        --enable-libpulse \
                        --enable-libspeex \
                        --enable-nonfree \
                        --enable-pthreads \
                        --enable-shared \
                        --enable-version3 \
                        --extra-cflags="-I./build/local/include" \
                        --extra-ldflags="-L./build/local/lib" \
                        --extra-libs="-lpthread -lm" 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "$title configure failed. Skipping ..." 3
                        return 16
                    fi

                    make -j"$(nproc)" 2>&1 | log_trace "[INS]"
                    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                        log_message "$title make failed. Skipping ..."
                        return 16
                    fi

                    log_message "[+] Creating a Debian file with checkinstall ..." 5
                    sudo checkinstall --install=no --pakdir="$HOME"/Downloads --pkgname=FFMPEG --pkgversion="$version" -y 2>&1 | log_trace "[INS]"

                    # Find the .DEB file created by checkinstall
                    debfile=$(find "$HOME/Downloads" -maxdepth 1 -type f -iname "*.DEB")

                    # Copy the .DEB file and set user rights
                    if [ -n "$debfile" ]; then
                        sudo mv "$debfile" "$HOME/Downloads/ffmpeg-$version.deb" 2>&1 | log_trace "[INS]" &&
                            sudo chown "$_USERID":"$_USERNAME" "$HOME/Downloads/ffmpeg-$version.deb" 2>&1 | log_trace "[INS]" &&
                            log_message "File renamed to '$HOME/Downloads/ffmpeg-$version.deb'" 1
                    else
                        log_message "No .DEB file found at '$HOME/Downloads'" 3
                    fi

                    if which "$package" >/dev/null 2>&1; then
                        log_message "$title installation complete" 1
                    fi
                else
                    log_message "Cannot continue $title installation.
                Please make sure 'yasm', 'checkinstall' installed, and/or archive intact" 3
                    return 15
                fi
            else
                log_message "$title already installed. Skipping ..."
            fi

            cd ..
            ;;
        fsearch)
            if ! which fsearch >/dev/null 2>&1; then
                sudo add-apt-repository --yes ppa:christian-boxdoerfer/fsearch-daily 2>&1 | log_trace "[INS]"
                sudo apt-get update 2>&1 | log_trace "[INS]"
                sudo apt-get install "$package" 2>&1 | log_trace "[INS]"
                if [ "${PIPESTATUS[0]}" -eq 0 ]; then
                    log_message "$title installation complete" 1
                else
                    log_message "$title installation failed" 3
                fi
            else
                log_message "$title already installed. Skipping ..."
            fi
            ;;
        libreoffice)
            if ! find /etc/apt/ -name "$package*.list" -print0 | xargs -0 cat | grep -q "^deb https.*ubuntu" 2>&1 | log_trace "[INS]"; then
                log_message "[+] Updating $title repository ..."
                sudo add-apt-repository --yes ppa:"$package"/ppa 2>&1 | log_trace "[INS]" &&
                    log_message "$title repository updated" 1
            else
                log_message "$title repository is up-to-date. Skipping ..."
            fi

            libreoffice_extensions
            ;;
        lmsensors)
            if ! which sensors >/dev/null 2>&1; then
                sudo apt-get install lm-sensors 2>&1 | log_trace "[INS]"
                if [ "${PIPESTATUS[0]}" -eq 0 ]; then
                    log_message "lm-sensors installation complete" 1
                else
                    log_message "lm-sensors installation failed" 3
                fi
            else
                log_message "lm-sensors already installed. Skipping ..."
            fi
            ;;
        pdf.tocgen)
            set_dependency "$package"
            ;;
        teamviewer)
            if ! which "$package" >/dev/null 2>&1; then
                url='https://download.teamviewer.com/download/linux/teamviewer_amd64.deb'
                filename=$(basename "$url")
                cd "$temp_dir" || return 4
                fetch_file "$url" "$filename" "."
                sudo apt-get install "./$filename" -y 2>&1 | log_trace "[INS]"
                if [ "${PIPESTATUS[0]}" -eq 0 ]; then
                    log_message "$title installation complete" 1
                else
                    log_message "$title installation failed" 3
                fi

                cd ..
            else
                log_message "$title already installed. Skipping ..."
            fi
            ;;
        virt-manager)
            if ! which "$package" >/dev/null 2>&1; then
                sudo apt-get install "$package" -y 2>&1 | log_trace "[INS]"
                if [ "${PIPESTATUS[0]}" -eq 0 ]; then
                    log_message "Virtualisation Manager installation complete" 1
                else
                    log_message "Virtualisation Manager installation failed" 3
                fi
            else
                log_message "Virtualisation Manager already installed. Skipping ..."
            fi
            ;;
        *)
            if ! which "$package" >/dev/null 2>&1; then
                sudo apt-get install "$package" 2>&1 | log_trace "[INS]"
                if [ "${PIPESTATUS[0]}" -eq 0 ]; then
                    log_message "$title installation complete" 1
                else
                    log_message "$title installation failed" 3
                fi
            else
                log_message "$title already installed. Skipping ..."
            fi
            ;;
        esac
    done
}

set_permission() {
    # Desription:   Sets user's permissions.
    # Arguments:    One (1) - object to be set permission.
    local arg

    arg="$1"
    if [ $# -ne 1 ]; then
        log_and_exit "Wrong number of arguments for ${FUNCNAME[2]}" 3
    fi

    if chown -R "$_USERID":"$_USERNAME" "$arg" && chmod -R 774 "$arg"; then
        log_message "User '$_USERNAME' set RWX permissions for $arg" 1
    else
        log_and_exit "${FUNCNAME[0]}: Failed to set permissions for $arg" 19
    fi
}

set_pip() {
    # Description:  Installs `pip` — a package installer for Python.
    # Arguments:    None.
    local filename tmpdir url

    if ! command -v pip3; then
        url='https://bootstrap.pypa.io/get-pip.py'
        filename=$(basename "$url")
        tmpdir=$(mktemp -d)
        fetch_file "$url" "$filename" "$tmpdir"
        python3 "$tmpdir/$filename" 2>&1 | log_trace "[PIP]"
        chmod +x "$_BINPATH"/pip* 2>&1 | log_trace "[PIP]"
        return 0
    fi

    return 13
}

set_portables() {
    # Description:  Downloads and installs portable packages, including AppImages, etc.
    # Arguments:    None.
    log_message "Initialising the setup of portable packages ..." 5
    local cmd codium_dir dirs extension filename full_url icon_file icon_path
    local jqcmd launcher_file name portable portables pref_package temp_dir tmp_url

    # Check if the global array variable is not empty
    if [ "${#_PORTABLES[@]}" -eq 0 ]; then
        log_message "Nothing to install. Skipping ..." 3
        return 1
    fi

    # Array of portable packages (title;filename;URL;command)
    jqcmd="jq -r '.assets[].browser_download_url' | grep -i \"appimage$\" | sort | tail -1"
    declare -a portables=(
        "Audacity;audacity;https://api.github.com/repos/audacity/audacity/releases/latest;$jqcmd"
        'Bleachbit;bleachbit;https://api.github.com/repos/bleachbit/bleachbit/releases/latest;grep 'tarball_url' | cut -d\" -f4'
        "CPU-X;cpux;https://api.github.com/repos/X0rg/CPU-X/releases/latest;$jqcmd"
        "cURL;curl;https://api.github.com/repos/moparisthebest/static-curl/releases/latest;jq -r '.assets[].browser_download_url' | grep 'curl-amd64'"
        'DeadBeef;deadbeef;https://sourceforge.net/projects/deadbeef/files/travis/linux/master/;grep -oP "https.*deadbeef-static.*bz2/download" | head -1'
        "HW-Probe;hwprobe;https://api.github.com/repos/linuxhw/hw-probe/releases/latest;$jqcmd"
        "ImageMagick;imagemagick;https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest;$jqcmd"
        'Inkscape;inkscape;https://inkscape.org/release/all/gnulinux/appimage;grep -iP "\>inkscape.*\.appimage" | cut -d\" -f2 | tail -1 | sed "s/^/https:\/\/inkscape\.org/"'
        "jq;jq;https://api.github.com/repos/jqlang/jq/releases/latest;jq -r '.assets[].browser_download_url' | grep 'jq-linux-amd64'"
        "KeePassXC;keepassxc;https://api.github.com/repos/keepassxreboot/keepassxc/releases/latest;$jqcmd"
        'Krita;krita;https://krita.org/en/download/;grep -ioP "\<a href\=https://download.kde.org/stable/krita/\d\.\d\.\d\/krita-.*-x86_64.appimage" | cut -d\= -f2 | tail -1'
        'MuseScore;musescore;https://musescore.org/en/download/musescore-x86_64.AppImage;grep -ioP "https.*appimage" | tail -1'
        "Neofetch;neofetch;https://raw.githubusercontent.com/hykilpikonna/hyfetch/master/neofetch;n/a"
        'QBittorrent;qbittorrent;https://www.qbittorrent.org/download.php;grep -P ".*sourceforge.*\d_x86_64\.AppImage\/download" | cut -d\" -f4 | head -1'
        "SMPlayer;smplayer;https://api.github.com/repos/smplayer-dev/smplayer/releases/latest;$jqcmd"
        "SQLite Browser;sqlitebrowser;https://api.github.com/repos/sqlitebrowser/sqlitebrowser/releases/latest;$jqcmd"
        "Styli.sh;styli.sh;https://raw.githubusercontent.com/thevinter/styli.sh/master/styli.sh;n/a"
        'VSCodium;codium;https://api.github.com/repos/VSCodium/vscodium/releases/latest;jq -r ".assets[].browser_download_url" | grep -i "vscodium\-linux\-x64.*tar.gz$"'
        "XnView;xnview;https://download.xnview.com/XnView_MP.glibc2.17-x86_64.AppImage;n/a"
        "Xournal++;xournalpp;https://api.github.com/repos/xournalpp/xournalpp/releases/latest;$jqcmd"
        'YT-DLP;ytdlp;https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest;jq -r ".assets[].browser_download_url" | grep -i "yt-dlp$"'
    )

    # Create a directory for portable programs
    if ! mkdir -p "$_APPSDIR"; then
        log_message "Failed to create directory '$_APPSDIR'. Skipping ..." 3
        return 5
    fi

    # Bookmark the portables directory
    if [ -w "$_GTKBKMRK" ]; then
        if ! grep -q "file://${_APPSDIR}$" "${_GTKBKMRK}"; then
            printf "%s\n" "file://${_APPSDIR}" >>"$_GTKBKMRK" 2>&1 | log_trace "[PRT]"
            log_message "Bookmarked directory '$_APPSDIR'" 1
        else
            log_message "Directory '$_APPSDIR' already bookmarked"
        fi
    else
        log_message "Failed to bookmark directory '$_APPSDIR'" 3
    fi

    check_internet
    cd "$_APPSDIR" || return 4

    for portable in "${portables[@]}"; do
        IFS=';' read -r name filename tmp_url cmd <<<"$portable"
        for pref_package in "${_PORTABLES[@]}"; do
            if [ "$filename" == "$pref_package" ]; then # $filename and $_PORTABLES[n] must match!
                log_message "[+] Processing portable package '$pref_package'" 5
                # Don't re-download the package, if its directory exists and isn't empty
                if [ -d "$_APPSDIR/$filename" ] && [ -n "$(ls -A1q "$_APPSDIR/$filename")" ]; then
                    log_message "Package '$filename' exists. Skipping ..."
                    continue
                fi

                # Compile a URL to download the package
                if [ "$cmd" != 'n/a' ]; then
                    full_url=$(curl -sfL "$tmp_url" | bash -c "$cmd")
                else
                    full_url="$tmp_url" # imagemagick, neofetch, styli.sh, etc.
                fi

                # Download the package and extract, if necessary
                if [ -n "$full_url" ]; then
                    fetch_file "$full_url" "$filename" "$_APPSDIR"
                    [ $? != 11 ] && tar_extractor "$_APPSDIR/$filename" "$filename" "$_APPSDIR" 2>/dev/null # skip extraction, if file exists
                else
                    log_message "Cannot download '$name'. Skipping ..." 3
                    continue
                fi

                # Copy launcher files
                if mkdir -p "$_USERAPPS"; then
                    launcher_file="$_BASEDIR"/data/launchers/"$filename".desktop
                    if [[ -f "$launcher_file" ]]; then
                        if [[ ! -f "$_USERAPPS"/"$filename".desktop ]]; then
                            if cp "$launcher_file" "$_USERAPPS" && chown "${_USERID}":"${_USERNAME}" "${_USERAPPS}/${filename}.desktop" && chmod 774 "${_USERAPPS}"/"${filename}.desktop"; then
                                log_message "Copied launcher '$filename.desktop' to '$_USERAPPS'" 1
                            else
                                log_message "Copying launcher '$filename.desktop' to '$_USERAPPS' failed. Skipping ..." 3
                            fi
                        else
                            log_message "Launcher '$filename.desktop' found. Skipping ..."
                        fi
                    else
                        log_message "Launcher '$filename.desktop' does not exist. Skipping ..." 3
                    fi
                else
                    log_message "Failed to locate directory '$_USERAPPS'. Skipping ..." 3
                fi

                # Copy icon files
                if mkdir -p "$_USERICONS"/hicolor/scalable/apps; then
                    icon_path=$(find "$_BASEDIR"/data/icons -type f -iwholename "$_BASEDIR/data/icons/${filename}.*")
                    icon_file=$(basename "$icon_path")
                    if [[ -f "$icon_path" ]]; then
                        if [[ ! -f "$_USERICONS"/hicolor/scalable/apps/"$icon_file" ]]; then
                            if cp "$icon_path" "$_USERICONS"/hicolor/scalable/apps; then
                                log_message "Copied icon file '$icon_file' to '$_USERICONS/hicolor/scalable/apps'" 1
                            else
                                log_message "Copying icon file '$icon_file' failed. Skipping ..." 3
                            fi
                        else
                            log_message "Icon file '$icon_file' found. Skipping ..."
                        fi
                    else
                        log_message "Icon file for '$filename' does not exist. Skipping ..." 3
                    fi
                else
                    log_message "Failed to create directory '$_USERICONS/hicolor/scalable/apps'. You'll need to create it manually. Skipping ..." 2
                fi
            fi
        done
    done

    # Download and install VS Codium extensions
    vsc_extensions

    # Set user and group permissions
    dirs="$_APPSDIR $_USERAPPS $_USERICONS/hicolor/scalable/apps"
    for dir in $dirs; do
        [ -d "$dir" ] && set_permission "$dir"
    done

    # Append the Portables directory to ~/.profile
    if touch "$_USERPROFILE"; then
        if ! grep -q "Portables" <"$_USERPROFILE"; then
            printf "\n%s\n" "export PATH=\"$_APPSDIR:\$PATH\"" >>"$_USERPROFILE"
            source "$_USERPROFILE"
            log_message "$_APPSDIR added to \$PATH" 1
        else
            log_message "$_APPSDIR already set to \$PATH. Skipping ..."
        fi
    else
        log_message "Failed to export '$_APPSDIR' to '$_USERPROFILE'" 3
    fi
}

system_check() {
    # Desription:   Checks user's operating system for compatibility with the script.
    # Arguments:    None.
    local bin version

    if [[ -r "${_OS_RELEASE}" ]]; then
        log_message "OS release file: ${_OS_RELEASE}" 1
        _DISTRO_PRETTY_NAME="$(awk '/PRETTY_NAME=/' "${_OS_RELEASE}" | sed 's/PRETTY_NAME=//' | tr -d '"')"
        _NAME="$(awk '/^NAME=/' "${_OS_RELEASE}" | sed 's/^NAME=//' | tr -d '"')"
        _VERSION_CODENAME="$(awk '/VERSION_CODENAME=/' "${_OS_RELEASE}" | sed 's/VERSION_CODENAME=//')"
        [[ ${_NAME} != "${_OS}" ]] && log_and_exit "${FUNCNAME[0]}: Operating system mismatch: ${_NAME}" 17
        log_message "Operating system: ${_DISTRO_PRETTY_NAME}" 1
    else
        log_and_exit "${FUNCNAME[0]}: Failed to determine operating system!" 21
    fi

    # Check Bash version
    if [ "${BASH_VERSINFO[0]}" -lt 5 ]; then
        log_and_exit "${FUNCNAME[0]}: Incompatible Bash version: ${BASH_VERSION}" 21
    else
        log_message "Bash version: ${BASH_VERSION%%\(*}" 1
    fi

    # Check other packages
    for bin in curl jq jsonschema; do
        if [ "$bin" == 'curl' ]; then
            command -v "$bin" >/dev/null && version=$("$bin" -V | cut -d' ' -f2 | head -1)
        elif [ "$bin" == 'jq' ]; then
            command -v "$bin" >/dev/null && version=$("$bin" -V | cut -d- -f2)
        else
            version=$(pip3 show "$bin" | grep -oE "^Version:.*" | cut -d' ' -f2-)
        fi

        log_message "Using '$bin' version: $version" 1
    done

    readonly _DISTRO_PRETTY_NAME _NAME _VERSION_CODENAME
}

stop_packagekitd() {
    # Description:  Attempts to temporarily suspend daemon packagekitd, which locks `apt`
    #               and returns error 'E: Could not get lock /var/lib/apt/lists/lock. It is held by process {PROCID} (packagekitd)'.
    #               Restarting the daemon is unnecessary, as this will be done by `apt` anyway.
    # Arguments:    None.

    # Check if PackageKit service is running
    if systemctl is-active --quiet packagekit.service; then
        log_message "Stopping PackageKit service ..."
        sudo systemctl stop packagekit.service 2>&1 | log_trace "[APT]"
        log_message "PackageKit service stopped" 1
    else
        log_message "PackageKit service not active"
    fi
}

system_update() {
    # Description:  Applies system-wide updates and removes redundant packages.
    # Arguments:    None.
    log_message "Performing system update ..." 5
    stop_packagekitd                                                      # unlock apt
    pop-upgrade release upgrade 2>&1 | log_trace "[POP]"                  # System76 upgrades
    log_trace "[APT]" <<<"$(sudo apt-get -o=Dpkg::Use-Pty=0 update 2>&1)" # no prompts with 'apt update'; redirect all msgs to log_trace()

    sudo apt-get update 2>&1 | log_trace "[APT]"
    sudo apt-get full-upgrade -y 2>&1 | log_trace "[APT]"

    # reboot the system, if necessary
    if [ -e /var/run/reboot-required ]; then
        if [ -f "$_MISC"/poppi.desktop ]; then
            if mkdir -p "$HOME"/.config/autostart 2>&1 | log_trace "[APT]"; then
                printf "%s\n" "Exec=gnome-terminal -e \"bash -c '$_BASEDIR/$_SCRIPT $_OPTION $_CONFIG_FILE; exec bash'\"" >>"$_MISC"/poppi.desktop
                # autostart POPPI on system reboot
                cp "$_MISC"/poppi.desktop "$HOME"/.config/autostart 2>&1 | log_trace "[APT]" && chmod +x "$HOME"/.config/autostart/poppi.desktop && restart
            fi
        else
            log_message "Cannot schedule autostart for '$_SCRIPT'" 3
        fi
        exit # avoid premature deletion of poppi.desktop (see: below)
    fi

    # Remove the autostart file after system reboot
    if [ -f "$HOME"/.config/autostart/poppi.desktop ]; then
        rm "$HOME"/.config/autostart/poppi.desktop
        log_message "File '$HOME/.config/autostart/poppi.desktop' deleted" 1
    fi

    # Remove unnecessary packages
    sudo apt-get autoremove -y 2>&1 | log_trace "[APT]"

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

tar_extractor() {
    # Description:  Custom extractor for tar packages powered by `tar`.
    # Arguments:    Three (3)
    #   -- Archive file to be extracted.
    #   -- Title the extracted archive will be renamed to.
    #   -- Output directory.
    local appfile appname archive_type ext fmt isArchive loc lst newdir tar xdir zip

    # Check the number of supplied arguments
    [ $# -eq 0 ] && log_message "ERR: ${FUNCNAME[0]} requires at least 1 argument: $#" 2 && return 3
    [ $# -gt 0 ] && [ $# -lt 3 ] && log_message "WRN: Insufficient arguments for ${FUNCNAME[0]}: $#" 3

    # Check if argument ${1} is a valid archive file, then
    # exit the function, if not
    appfile=${1}
    isArchive='false'
    for archive_type in "${_COMPRESSED_TYPES[@]}"; do
        if [[ "$archive_type" =~ $(file -b --mime-type "$appfile") ]]; then
            isArchive='true'
            break
        fi
    done

    if [[ $isArchive = 'false' ]]; then
        log_message "${FUNCNAME[0]}: Not a valid archive: $appfile" 2
        return 22
    fi

    # Check if the 2nd argument is a valid Linux name, then
    # convert to a valid one, if necessary, then
    # replace with the default one, if missing
    if [[ ! "${2}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_message "${FUNCNAME[0]}: Not a valid file/directory name: ${2}" 3
        # shellcheck disable=SC2001
        appname=$(echo "${2}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    fi

    appname=${2}

    # Check if the 3rd argument is a valid directory
    if [ ! -d "${3}" ]; then
        log_message "${FUNCNAME[0]}: Not a valid directory: ${3}" 3
    fi

    loc="${3:-$_BASEDIR}"
    fmt=$(file "$appfile" | awk '{print $2}')                   # determine archive's format
    declare -a tars=('gzip;tzf;xzf' 'XZ;tf;xf' 'bzip2;tjf;xjf') # create an array with tarball commands for specific archive formats
    for tar in "${tars[@]}"; do
        zip="${tar%%;*}"                   # compression format
        lst="${tar#*;}" && lst="${lst%;*}" # listing method
        ext="${tar##*;}"                   # extraction method

        if [ "$fmt" == "$zip" ]; then
            xdir=$(tar "$lst" "$appfile" | head -1 | cut -d'/' -f1) # list the contents of archive
            if [ "$xdir" = '.' ]; then                              # flat archive with no root directory
                newdir="$appname"'_'                                # append '_' to the directory name
                mkdir "$loc/$newdir" 2>&1 | log_trace "[TAR]"
                tar "$ext" "$appfile" -C "$loc/$newdir" 2>&1 | log_trace "[TAR]"
                rm "$appfile"                                              # useless archive; must precede the rename operation below
                [ -d "$loc/$newdir" ] && mv "$loc/$newdir" "$loc/$appname" # rename the archive
            elif [ "$appname" = 'nul' ]; then                              # extract archive contents to the same directory
                tar "$ext" "$appfile" --strip-components=1 -C "$loc" 2>&1 | log_trace "[TAR]"
                rm "$appfile" # useless archive
            else
                tar "$ext" "$appfile" -C "$loc" 2>&1 | log_trace "[TAR]"
                rm "$appfile"                                          # useless archive; must precede the rename operation below
                [ -d "$loc/$xdir" ] && mv "$loc/$xdir" "$loc/$appname" # rename the archive
            fi
            break
        fi
    done
}

timer() {
    # Description:  Calculate time elapsed since the script's execution.
    # Arguments:    None.
    local hrs min sec elapsed_time

    elapsed_time=$((SECONDS - _START_TIME))

    # Convert to hours, minutes, and seconds
    hrs=$((elapsed_time / 3600))
    min=$(((elapsed_time % 3600) / 60))
    sec=$((elapsed_time % 60))

    # Display the elapsed time
    if [ $elapsed_time -gt 60 ] && [ $elapsed_time -lt 3600 ]; then
        printf "%02d mins, %02d sec\n" $min $sec
    elif [ $elapsed_time -ge 3600 ]; then
        printf "%02d hrs, %02d mins, %02d sec\n" $hrs $min $sec
    else
        printf "%02d sec\n" $sec
    fi
}

# shellcheck disable=SC2001
trimex() {
    # Description:  Trims the title of a Firefox extension.
    # Arguments:    One (1) - title of the extension to be trimmed.
    if [ $# -ne 1 ]; then
        log_message "ERR: Wrong number of arguments for '${FUNCNAME[0]}': $#" 3
        return 3
    fi

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
    # Description:  Asks for user's consent to run the script.
    # Arguments:    None.
    local answer

    while true; do
        read -r -n 1 -p "${_CWARN}Running this script will make changes to your system. Continue? [Y|N] ${_CNONE}" answer

        case $answer in
        [yY])
            clear
            headline
            break
            ;;
        [nN])
            clear
            exit 0
            ;;
        *) printf '\n\n%s\n\n' "${_CSTOP}Invalid response! Try again.${_CNONE}" ;;
        esac
    done
}

validate_json() {
    # Description:  Validates user configurations provided as JSON data.
    # Arguments:    None.
    local errMsg

    set_dependency python3
    if [ -f "$_CONFIG_FILE" ] && [ -f "$_SCHEMA" ]; then
        errMsg=$(
            python3 <<EOF 2>&1 | log_trace "[JVL]"
import json
import sys
from jsonschema import validate, ValidationError

# Load the schema and the data
with open('$_SCHEMA') as schema_file:
    schema = json.load(schema_file)

with open('$_CONFIG_FILE') as data_file:
    data = json.load(data_file)

# Validate data against the schema
try:
    validate(instance=data, schema=schema)
except ValidationError as e:
    print(e.message)  # This will be captured as an error message
    sys.exit(1)
EOF
        )

        # Check the exit status of the Python command
        if [ -n "$errMsg" ]; then
            echo "$errMsg" | log_trace "[JVL]"
            log_and_exit "${FUNCNAME[0]}: JSON validation failed. A new configuration file created.
    Please make necessary changes to it and re-run the script." 23
        fi
    else
        log_and_exit "${FUNCNAME[0]}: Necessary file(s) missing." 24
    fi

    return 0
}

vsc_extensions() {
    # Description:  Downloads and sets up VS Codium extensions.
    # Arguments:    None.
    local codium_dir extension extensions_dir

    if [ ! -d "$_APPSDIR"/codium ]; then
        log_message "VS Codium is not available. Skipping ..." 3 && return 12
    fi

    if [ "${#_VSIX[@]}" -eq 0 ]; then
        log_message "No VS Codium extensions to install. Skipping ..." 3 && return 1
    fi

    codium_dir="$_APPSDIR"/codium/bin
    extensions_dir="$_APPSDIR"/codium/data/extensions # Set the extensions directory explicitly. Otherwise, installs into ~/.vscode-oss/extensions.
    if mkdir -p "$extensions_dir"; then
        if [ -f "$codium_dir"/codium ] && chmod +x "$codium_dir"/codium; then
            # Update 'product.json' before installing extensions
            if ! vsc_patcher >/dev/null 2>&1 | log_trace "[VSC]"; then
                log_message "You may need to install some of the VS Codium extensions manually" 3
            fi

            # Install extensions
            for extension in "${_VSIX[@]}"; do
                log_message "[+] Installing VS Codium extension '$extension'" 5
                "$codium_dir"/codium --install-extension "$extension" --force 2>&1 | log_trace "[VSC]"
            done
        else
            log_message "Required executable 'codium' is missing. Skipping ..." && return 24
        fi
    else
        log_message "Failed to install VS Codium extensions. Skipping ..." 3 && return 5
    fi
}

vsc_patcher() {
    # Description:  Patches VS Codium 'product.json' to allow downloading from Microsoft Marketplace.
    # Arguments:    None.
    local new_cacheUrl new_itemUrl new_nameLong new_nameShort new_serviceUrl product_json product_bak tmpfile

    product_json="$_APPSDIR"/codium/resources/app/product.json
    product_bak="$_APPSDIR"/codium/resources/app/product.bak
    tmpfile=$(mktemp)

    # Check if file exists
    if [ ! -f "$product_json" ]; then
        log_message "File '$product_json' not found. Skipping ..." 3
        return 24
    fi

    # Create a backup of the original file before any modification
    if ! cp "$product_json" "$product_bak" 2>&1 | log_trace "[PRT]"; then
        log_message "Failed to back up '$product_json'. Skipping ..." 3
        return 6
    fi

    # Define the new values
    new_nameShort="Visual Studio Code"
    new_nameLong="Visual Studio Code"
    new_serviceUrl="https://marketplace.visualstudio.com/_apis/public/gallery"
    new_cacheUrl="https://vscode.blob.core.windows.net/gallery/index"
    new_itemUrl="https://marketplace.visualstudio.com/items"

    # Update all values while preserving cacheUrl if it exists
    jq \
        --arg nameShort "$new_nameShort" \
        --arg nameLong "$new_nameLong" \
        --arg serviceUrl "$new_serviceUrl" \
        --arg cacheUrl "$new_cacheUrl" \
        --arg itemUrl "$new_itemUrl" \
        '. * {
                nameShort: $nameShort,
                nameLong: $nameLong,
                extensionsGallery: {
                    serviceUrl: $serviceUrl,
                    cacheUrl: $cacheUrl,
                    itemUrl: $itemUrl
                }
            }' "$product_json" >"$tmpfile" 2>&1 | log_trace "[PRT]" &&
        rm "$product_json" &&
        mv "$tmpfile" "$product_json"

    if [ "${PIPESTATUS[0]}" ]; then
        log_message "File '$product_json' patched" 1
    else
        log_message "Patching '$product_json' failed" 3
        return 14
    fi
}

main() {
    local arg dep f

    # Load default settings
    __init_vars

    # Check the arguments
    # At least one, but not more than two arguments are required
    if [[ $# -eq 0 || $# -gt 2 ]]; then
        display_usage
        return 3
    fi

    # Determine the option and configuration file
    for arg in "$@"; do
        if [[ $arg =~ ^-[abcdfghprvx]$ ||
            $arg =~ ^--(all|bookmark|connect|dock|firefox|gnome-extensions|help|set-gsettings|set-portables|set-repos|version)$ ]]; then
            _OPTION=$arg
            continue
        elif [[ -f $arg ]]; then
            _CONFIG_FILE=$arg
            continue
        else
            display_usage
            return 25
        fi
    done

    # At least one argument must be an option
    if [[ -z $_OPTION ]]; then
        display_usage
        return 3
    fi

    # Validate the user configuration file or make a new one, if there's none
    if ! [ -f "$_CONFIG_FILE" ] && [[ ! "$_OPTION" =~ ^(-[chv]|--(connect|help|version))$ ]]; then
        __make_configs
        _CONFIG_FILE="$_BASEDIR"/configure.pop # Assign default configuration file
    fi

    # Validate and load configs if the option is not one of the specified characters or words
    if [[ ! "$_OPTION" =~ ^(-[chv]|--(connect|help|version))$ ]]; then
        for dep in curl jq jsonschema; do
            if [ ! -f "$_BINPATH/$dep" ]; then
                set_dependency "$dep"
            fi
        done

        validate_json
        __load_configs
        __make_dirs
    fi

    # Process the arguments
    case "$_OPTION" in
    -a | --all)
        online
        all
        ;;
    -b | --bookmark)
        offline
        misc_bookmark_dirs
        ;;
    -c | --connect)
        check_internet
        ;;
    -d | --dock)
        offline
        set_favourites
        ;;
    -f | --firefox)
        online
        set_firefox
        ;;
    -g | --set-gsettings)
        offline
        set_gsettings
        ;;
    -h | --help) display_usage ;;
    -i | --set-installers)
        online
        set_installers
        set_configs
        ;;
    -p | --set-portables)
        online
        set_portables
        set_configs
        ;;
    -v | --version) display_version ;;
    -x | --gnome-extensions)
        online
        set_gnome_extensions
        ;;
    *) display_usage ;;
    esac

    if [ "$_ENDMSG" = 'true' ]; then
        system_update
        screenlock
        # Remove unnecessary binaries and/or setup files
        for f in curl jq; do
            [ -f "$_BINPATH/$f" ] && rm "$_BINPATH/$f" 2>&1 | log_trace "[000]"
        done

        finale
        restart
    fi

    # Remove unnecessary binaries and/or setup files
    for f in curl jq; do
        [ -f "$_BINPATH/$f" ] && rm "$_BINPATH/$f" 2>&1 | log_trace "[000]"
    done

    # ... and ends here.
    if [[ ! "$_OPTION" =~ ^(-[chv]|--(connect|help|version))$ ]]; then
        finale
    fi
}

# The magic starts here ...
main "$@"
