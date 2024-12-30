#!/bin/bash

# Checks for parked/unparked domains and removes/adds them accordingly.
# Current calculations put the processing speed at 12.5 entries/second.
# It should be noted that although the domain may be parked, subfolders of the
# domain may host malicious content. This script does not account for that.

readonly FUNCTION='bash scripts/tools.sh'
readonly RAW='data/raw.txt'
readonly RAW_LIGHT='data/raw_light.txt'
readonly PARKED_TERMS='config/parked_terms.txt'
readonly PARKED_DOMAINS='data/parked_domains.txt'
readonly ROOT_DOMAINS='data/root_domains.txt'
readonly SUBDOMAINS='data/subdomains.txt'
readonly SUBDOMAINS_TO_REMOVE='config/subdomains.txt'
readonly LOG_SIZE=50000

main() {
    case "$1" in
        'checkunparked')
            # The unparked check being done in the workflow before the parked
            # check means the recently added unparked domains are processed by
            # the parked check while the recently added parked domains are not
            # processed by the unparked check.
            check_unparked
            ;;
        'checkparked')
            check_parked
            ;;
        *)
            printf "\n\e[1;31mNo argument passed.\e[0m\n\n"
            exit 1
            ;;
    esac
}

# Function 'check_parked' removes parked domains from the raw file, raw light
# file, and subdomains file.
check_parked() {
    # Include subdomains in the parked check. It is assumed that if the
    # subdomain is parked, so is the root domain. For this reason, the root
    # domains are excluded to not waste processing time.
    comm -23 <(sort "$RAW" "$SUBDOMAINS") "$ROOT_DOMAINS" > domains.tmp

    find_parked_in domains.tmp || return

    # Save parked domains to be used as a filter for newly retrieved
    # domains. This includes subdomains.
    # Note the parked domains file should remain unsorted
    cat parked.tmp >> "$PARKED_DOMAINS"

    # Remove parked domains from subdomains file
    comm -23 "$SUBDOMAINS" parked.tmp > temp
    mv temp "$SUBDOMAINS"

    # Strip subdomains from parked domains
    while read -r subdomain; do
        sed -i "s/^${subdomain}\.//" parked.tmp
    done < "$SUBDOMAINS_TO_REMOVE"
    sort -u parked.tmp -o parked.tmp

    # Remove parked domains from the various files
    for file in "$RAW" "$RAW_LIGHT" "$ROOT_DOMAINS"; do
        comm -23 "$file" parked.tmp > temp
        mv temp "$file"
    done

    # Call shell wrapper to log number of parked domains in domain log
    $FUNCTION --log-domains "$(wc -l < parked.tmp)" parked_count raw
}

# Function 'check_unparked' finds unparked domains in the parked domains file
# (also called the parked domains cache) and adds them back into the raw file.
#
# Note that resurrected domains are not added back into the raw light file as
# the parked domains are not logged with their sources.
check_unparked() {
    find_parked_in "$PARKED_DOMAINS"

    # Assume domains that errored out during the check are still parked
    sort -u errored.tmp parked.tmp -o parked.tmp

    # Get unparked domains in parked domains file
    comm -23 <(sort "$PARKED_DOMAINS") parked.tmp > unparked_domains.tmp

    [[ ! -s unparked_domains.tmp ]] && return

    # Update parked domains file to only include parked domains
    # grep is used here because the parked domains file is unsorted
    grep -xFf parked.tmp "$PARKED_DOMAINS" > temp
    mv temp "$PARKED_DOMAINS"

    # Add unparked domains to raw file
    # Note that unparked subdomains are added back too and will be processed by
    # the validation check outside of this script.
    sort -u unparked.tmp "$RAW" -o "$RAW"

    # Call shell wrapper to log number of unparked domains in domain log
    $FUNCTION --log-domains "$(wc -l < unparked.tmp)" unparked_count parked_domains_file
}

# Function 'find_parked_in' efficiently checks for parked domains in a given
# file by running the checks in parallel.
# Input:
#   $1: file to process
# Output:
#   parked.tmp
#   errored.tmp (consists of domains that errored during curl)
#   return 1 (if parked domains not found)
find_parked_in() {
    local execution_time
    execution_time="$(date +%s)"

    # Always create parked.tmp file to avoid not found errors
    touch parked.tmp

    printf "\n[info] Processing file %s\n" "$1"
    printf "[start] Analyzing %s entries for parked domains\n" "$(wc -l < "$1")"

    # Split file into 17 equal files
    split -d -l $(( $(wc -l < "$1") / 17 )) "$1"
    # Sometimes an x19 exists
    [[ -f x19 ]] && cat x19 >> x18

    # Run checks in parallel
    find_parked x00 & find_parked x01 & find_parked x02 & find_parked x03 &
    find_parked x04 & find_parked x05 & find_parked x06 & find_parked x07 &
    find_parked x08 & find_parked x09 & find_parked x10 & find_parked x11 &
    find_parked x12 & find_parked x13 & find_parked x14 & find_parked x15 &
    find_parked x16 & find_parked x17 & find_parked x18
    wait
    rm x??

    # Collate parked domains and errored domains (ignore not found errors)
    sort -u parked_domains_x??.tmp -o parked.tmp 2> /dev/null
    sort -u errored_domains_x??.tmp -o errored.tmp 2> /dev/null
    rm ./*_x??.tmp 2> /dev/null

    printf "[success] Found %s parked domains\n" "$(wc -l < parked.tmp) "
    printf "Processing time: %s second(s)\n" "$(( $(date +%s) - execution_time ))"

    # Return 1 if no parked domains were found
    [[ ! -s parked.tmp ]] && return 1 || return 0
}

# Function 'find_parked' queries sites in a given file for parked messages in
# their HTML.
# Input:
#   $1: file to process
# Output:
#   parked_domains_x??.tmp (if parked domains found)
#   errored_domains_x??.tmp (if any domains errored during curl)
find_parked() {
    [[ ! -f "$1" ]] && return

    # Track progress only for first split file
    if [[ "$1" == 'x00' ]]; then
        local track=true
        local count=1
    fi

    # Loop through domains
    while read -r domain; do
        if [[ "$track" == true ]]; then
            if (( count % 100 == 0 )); then
                printf "[progress] Analyzed %s%% of domains\n" \
                    "$(( count * 100 / $(wc -l < "$1") ))"
            fi

            (( count++ ))
        fi

        # Get the site's HTML and redirect stderror to stdout for error
        # checking later
        # tr is used here to remove null characters found in some sites
        # Appears that -k causes some domains to have an empty response, which
        # causes parked domains to seem unparked.
        html="$(curl -sSL --max-time 3 "https://${domain}/" 2>&1 | tr -d '\0')"

        # If using HTTPS fails, use HTTP
        if grep -qF 'curl: (60) SSL: no alternative certificate subject name matches target host name' \
            <<< "$html"; then
            # Lower max time
            html="$(curl -sSL --max-time 2 "http://${domain}/" 2>&1 \
                | tr -d '\0')"
        elif grep -qF 'curl:' <<< "$html"; then
            # Collate domains that errored so they can be dealt with later
            # accordingly
            printf "%s\n" "$domain" >> "errored_domains_${1}.tmp"
            continue
        fi

        # Check for parked messages in the site's HTML
        if grep -qiFf "$PARKED_TERMS" <<< "$html"; then
            printf "[info] Found parked domain: %s\n" "$domain"
            printf "%s\n" "$domain" >> "parked_domains_${1}.tmp"
        fi
    done < "$1"
}

cleanup() {
    find . -maxdepth 1 -type f -name "*.tmp" -delete
    find . -maxdepth 1 -type f -name "x??" -delete

    # Call shell wrapper to prune old entries from parked domains file
    $FUNCTION --prune-lines "$PARKED_DOMAINS" "$LOG_SIZE"
}

# Entry point

trap cleanup EXIT

$FUNCTION --format-all

main "$1"
