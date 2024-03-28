#!/bin/bash
raw_file='data/raw_light.txt'



raw_light_file='data/raw_light.txt'
parked_terms_file='config/parked_terms.txt'
parked_domains_file='data/parked_domains.txt'
domain_log='config/domain_log.csv'
time_format=$(date -u +"%H:%M:%S %d-%m-%y")

function main {
    for file in config/* data/*; do  # Format files in the config and data directory
        format_list "$file"
    done
    #add_unparked_domains
    remove_parked_domains
    #update_light_file
}

function add_unparked_domains {
    touch unparked_domains.tmp
    printf "\nChecking for domains that have been unparked.\n"

    # Split into 12 equal files
    split -d -l $(($(wc -l < "$parked_domains_file")/12)) "$parked_domains_file"
    check_for_unparked "x00" "main" & check_for_unparked "x01" &
    check_for_unparked "x02" & check_for_unparked "x03" &
    check_for_unparked "x04" & check_for_unparked "x05" &
    check_for_unparked "x06" & check_for_unparked "x07" &
    check_for_unparked "x08" & check_for_unparked "x09" &
    check_for_unparked "x10" & check_for_unparked "x11" &
    [[ -f x12 ]] && check_for_unparked "x12" || printf ""  # printf to negate exit status 1

    find . -maxdepth 1 -type f -name "x??" -delete  # Reset split files

    [[ ! -f unparked_domains.tmp ]] && return
    format_list unparked_domains.tmp

    # Remove unparked domains from parked domains file
    comm -23 "$parked_domains_file" unparked_domains.tmp > parked.tmp && mv parked.tmp "$parked_domains_file"
    cat unparked_domains.tmp >> "$raw_file"  # Add unparked domains to raw file
    format_list "$raw_file"
    log_event "$(<unparked_domains.tmp)" "unparked" "parked_domains_file"
}

function remove_parked_domains {
    touch parked_domains.tmp
    printf "\nChecking for parked domains.\n"

    # Split into 12 equal files
    split -d -l $(($(wc -l < "$raw_file")/12)) "$raw_file"
    check_for_parked "x00" "main" & check_for_parked "x01" &
    check_for_parked "x02" & check_for_parked "x03" &
    check_for_parked "x04" & check_for_parked "x05" &
    check_for_parked "x06" & check_for_parked "x07" &
    check_for_parked "x08" & check_for_parked "x09" &
    check_for_parked "x10" & check_for_parked "x11" &
    [[ -f x12 ]] && check_for_parked "x12" || printf ""  # printf to negate exit status 1

    find . -maxdepth 1 -type f -name "x??" -delete  # Reset split files

    [[ ! -f parked_domains.tmp ]] && return
    format_list parked_domains.tmp

    # Remove parked domains from raw file
    comm -23 "$raw_file" parked_domains.tmp > raw.tmp && mv raw.tmp "$raw_file"
    cat parked_domains.tmp >> "$parked_domains_file"  # Add parked domains to parked domains file
    format_list "$parked_domains_file"
    log_event "$(<parked_domains.tmp)" "parked" "raw"
}

function check_for_unparked {
    total=$(wc -l < "$1")
    count=1
    # Check for parked message in site's HTML
    while read -r domain; do
        if ! grep -qiFf "$parked_terms_file" <<< "$(curl -sL --max-time 1 "http://${domain}/" | tr -d '\0')"; then
            printf "%s\n" "$domain" >> "unparked_domains_${1}.tmp"
        fi
        if [[ "$2" == 'main' ]]; then
            percentage_count="$((count*100/total))"
            ((percentage_count % 10 == 0)) && printf "%s%%\n" "$percentage_count"
            ((count++))
        fi
    done < "$1"
    # Collate unparked domains
    [[ -f "unparked_domains_${1}.tmp" ]] && cat "unparked_domains_${1}.tmp" >> unparked_domains.tmp
}

function check_for_parked {
    total=$(wc -l < "$1")
    count=1
    # Check for parked message in site's HTML
    while read -r domain; do
        if grep -qiFf "$parked_terms_file" <<< "$(curl -sL --max-time 1 "http://${domain}/" | tr -d '\0')"; then
            printf "Parked: %s\n" "$domain"
            printf "%s\n" "$domain" >> "parked_domains_${1}.tmp"
        fi
        if [[ "$2" == 'main' ]]; then
            percentage_count="$((count*100/total))"
            ((percentage_count % 10 == 0)) && printf "%s%%\n" "$percentage_count"
            ((count++))
        fi
    done < "$1"
    # Collate parked domains
    [[ -f "parked_domains_${1}.tmp" ]] && cat "parked_domains_${1}.tmp" >> parked_domains.tmp
}

function update_light_file {
    comm -12 "$raw_file" "$raw_light_file" > light.tmp && mv light.tmp "$raw_light_file"  # Keep only domains found in full raw file
}

function log_event {
    # Log domain events
    printf "%s\n" "$1" | awk -v type="$2" -v source="$3" -v time="$time_format" '{print time "," type "," $0 "," source}' >> "$domain_log"
}

function format_list {
    bash data/tools.sh "format" "$1"
}

function cleanup {
    find . -maxdepth 1 -type f -name "*.tmp" -delete
}

trap cleanup EXIT
main