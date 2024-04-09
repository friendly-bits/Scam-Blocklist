#!/bin/bash

# Validates the entries in the raw file via a variety of checks and flags
# entries that require attention.

readonly FUNCTION='bash functions/tools.sh'
readonly RAW='data/raw.txt'
readonly RAW_LIGHT='data/raw_light.txt'
readonly WHITELIST='config/whitelist.txt'
readonly BLACKLIST='config/blacklist.txt'
readonly ROOT_DOMAINS='data/root_domains.txt'
readonly SUBDOMAINS='data/subdomains.txt'
readonly SUBDOMAINS_TO_REMOVE='config/subdomains.txt'

# Function 'filter' logs the given entries and removes them from the raw file.
# Input:
#   $1: entries to process
#   $2: tag given to entries
#   --preserve: pass argument to keep entries in the raw file
# Output:
#   Number of entries that were passed
filter() {
    local entries="$1"
    local tag="$2"

    # Return if no entries passed
    [[ -s "$entries" ]] && return

    # Record entries in the filter log
    awk -v tag="$tag" '{print $0 " (" tag ")"}' <<< "$entries" >> filter_log.tmp

    # Call shell wrapper to log entries into domain log
    $FUNCTION --log-domains "$entries" "$tag" raw

    if [[ "$3" != '--preserve' ]]; then
        # Remove entries from raw file
        comm -23 "$RAW" <(printf "%s" "$entries") > raw.tmp
        mv raw.tmp "$RAW"
    fi

    # Return the number of entries
    wc -l <<< "$entries"
}

validate_raw() {
    before_count="$(wc -l < "$RAW")"

    # Strip away subdomains
    subdomains_count=0
    while read -r subdomain; do  # Loop through common subdomains
        subdomains="$(grep "^${subdomain}\." "$RAW")" || continue
        subdomains_count="$(( subdomains_count \
            + "$(filter "$subdomains" subdomain --preserve)" ))"

        # Strip subdomains from raw file and raw light file
        sed -i "s/^${subdomain}\.//" "$RAW"
        sed -i "s/^${subdomain}\.//" "$RAW_LIGHT"

        # Save subdomains to be filtered later
        printf "%s\n" "$subdomains" >> subdomains.tmp

        # Save root domains to be filtered later
        printf "%s\n" "$subdomains" | sed "s/^${subdomain}\.//" >> root_domains.tmp

    done < "$SUBDOMAINS_TO_REMOVE"
    sort -u "$RAW" -o "$RAW"
    sort -u "$RAW_LIGHT" -o "$RAW_LIGHT"

    # Remove whitelisted domains excluding blacklisted domains
    # Note whitelist matching uses keywords
    whitelisted="$(grep -Ff "$WHITELIST" "$RAW" | grep -vxFf "$BLACKLIST")"
    whitelisted_count="$(filter "$whitelisted" whitelist)"

    # Remove domains that have whitelisted TLDs
    whitelisted_tld="$(grep -E '\.(gov|edu|mil)(\.[a-z]{2})?$' "$RAW")"
    whitelisted_tld_count="$(filter "$whitelisted_tld" tld)"

    # Remove non-domain entries including IP addresses
    # Punycode TLDs (.xn--*) are allowed
    invalid="$(grep -vE '^[[:alnum:].-]+\.[[:alnum:]-]*[a-z][[:alnum:]-]{1,}$' "$RAW")"
    invalid_count="$(filter "$invalid" invalid)"

    # Call shell wrapper to download toplist
    $FUNCTION --download-toplist
    # Find matching domains in toplist excluding blacklisted domains
    # Note the toplist does not include subdomains
    in_toplist="$(comm -12 toplist.tmp "$RAW" | grep -vxFf "$BLACKLIST")"
    toplist_count="$(filter "$in_toplist" toplist --preserve)"

    # Exit if no filtering done
    [[ ! -f filter_log.tmp ]] && exit

    # Collate only filtered subdomains and root domains into the subdomains
    # file and root domains file
    if [[ -f root_domains.tmp ]]; then
        # Find root domains (subdomains stripped off) in the filtered raw file
        root_domains="$(comm -12 <(sort root_domains.tmp) "$RAW")"

        # Collate filtered root domains to exclude from dead check
        printf "%s\n" "$root_domains" >> "$ROOT_DOMAINS"
        sort -u "$ROOT_DOMAINS" -o "$ROOT_DOMAINS"

        # Collate filtered subdomains for dead check
        grep "\.${root_domains}$" subdomains.tmp >> "$SUBDOMAINS"
        sort -u "$SUBDOMAINS" -o "$SUBDOMAINS"
    fi

    # Print filter log
    printf "\n\e[1mProblematic domains (%s):\e[0m\n" "$(wc -l < filter_log.tmp)"
    sed 's/(toplist)/& - \o033[31mmanual verification required\o033[0m/' filter_log.tmp

    # Call shell wrapper to send telegram notification
    $FUNCTION --send-telegram \
        "Problematic domains detected during validation check:\n$(<filter_log.tmp)"

    # Save changes to raw light file
    comm -12 "$RAW" "$RAW_LIGHT" > light.tmp
    mv light.tmp "$RAW_LIGHT"

    total_whitelisted_count="$(( whitelisted_count + whitelisted_tld_count ))"
    after_count="$(wc -l < "$RAW")"

    printf "\nBefore: %s  After: %s  Subdomains: %s  Whitelisted: %s  Invalid %s  Toplist: %s\n\n" \
        "$before_count" "$after_count" "$subdomains_count" "$total_whitelisted_count" \
        "$invalid_count" "$toplist_count"
}

# Entry point

trap 'find . -maxdepth 1 -type f -name "*.tmp" -delete' EXIT

$FUNCTION --format-all

validate_raw
