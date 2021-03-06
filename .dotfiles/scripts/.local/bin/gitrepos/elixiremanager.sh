#!/bin/bash

readonly prog_name="elixiremanager"
readonly prog_ver="7.0"

#defaults
readonly apiurl="https://elixi.re/api"
readonly apikey="$(cat "$HOME/.local/bin/gitrepos/apikey")"
mode=area
wayland=false
is_admin=""
readonly filename_format="/tmp/elixire-$(date +%Y-%m-%dT%H:%M:%S).png"
readonly upload_connect_timeout="5"
readonly upload_timeout="120"
readonly upload_retries="1"

function usage() {
    echo "usage: ${1} [options] [filename]"
    echo "options:"
    echo "  -h, --help    print this help and exit"
    echo "  -v, --version print version number and exit"
    echo "      --check   check dependencies and exit"
    echo "  -a, --area    select an area to upload"
    echo "  -f, --full    upload the full screen"
    echo "  -k, --keep    keep the file after uploading"
    echo "  -w, --wayland run in Wayland mode"
    echo "  -x, --xorg    run in Xorg mode"
    echo "      --admin   upload as an admin"
    echo "      --noadmin upload as a user"
}

function version() {
    echo "$prog_name $prog_ver"
}

function check_deps() {
    for i in date jq notify-send curl; do
        (which $i &>/dev/null) && echo "OK: found $i" || echo "ERROR: $i not found"
    done

    if [[ $wayland == "true" ]]; then
        for i in grim slurp; do
            (which $i &>/dev/null) && echo "OK: found $i" || echo "ERROR: $i not found"
        done
        (which wl-copy &>/dev/null) && echo "OK: found wl-clipboard" || echo "ERROR: wl-clipboard not found"
    else
        (which escrotum &>/dev/null) && echo "OK: escrotum found (sidenote: you need it through python2, and you need to install pygtk)" || echo "ERROR: escrotum not found"
        (which xclip &>/dev/null) && echo "OK: found xclip" || echo "ERROR: xclip not found"
    fi
}

function take_screenshot() {
    if [[ $1 == "area" ]]; then
        if [[ $wayland == "true" ]]; then
            grim -g "$(slurp)" "${2}"
        else
            escrotum -s "${2}"
        fi
    else
        if [[ $wayland == "true" ]]; then
            grim "${2}"
        else
            escrotum "${2}"
        fi
    fi
}

function upload_file_and_notify() {
    response=$(curl --compressed --connect-timeout ${upload_connect_timeout} -m ${upload_timeout} --retry ${upload_retries} -H "Authorization: ${apikey}" -F upload=@"${1}" ${apiurl}/upload${is_admin} | jq .url -r | tr -d '\n')

    if [[ ! -z "${response}" ]]; then
        if [[ $wayland == "true" ]]; then
            echo -en "${response}" | wl-copy
        else
            echo -en "${response}" | xclip -selection clipboard
        fi
        notify-send -t 5000 "Success!" "${response}" -i "${1}" --hint=int:transient:1
    else
        notify-send -t 5000 "Error!" --hint=int:transient:1
    fi
}

while [[ $# != 0 ]]; do
    case "${1}" in
        --help | -h)
            usage ${0}
            exit 0 ;;
        --version | -v)
            version ${0}
            exit 0 ;;
        --check)
            check_deps
            exit 0 ;;
        --area | -a)
            mode=area
            shift ;;
        --full | -f)
            mode=full
            shift ;;
        --keep | -k)
            keep=true
            shift ;;
        --wayland | -w)
            wayland=true
            shift ;;
        --xorg | -x)
            wayland=false
            shift ;;
        --admin)
            is_admin="?admin=true"
            shift ;;
        --noadmin)
            is_admin=""
            shift ;;
        *)
            file_provided=true
            file="${1}"
            shift ;;
    esac
done

if [[ -z $file ]]; then
    file="${filename_format}"
fi

if [[ -z $file_provided ]]; then
    take_screenshot $mode "${file}"
fi

upload_file_and_notify "${file}"

if [[ -z $file_provided && -z $keep ]]; then
    rm -f "${file}"
fi
