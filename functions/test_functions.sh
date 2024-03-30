#!/bin/bash
raw_file='data/raw.txt'
raw_light_file='data/raw_light.txt'
domain_log='config/domain_log.csv'
whitelist_file='config/whitelist.txt'
blacklist_file='config/blacklist.txt'
toplist_file='data/toplist.txt'
root_domains_file='data/root_domains.txt'
subdomains_file='data/subdomains.txt'
subdomains_to_remove_file='config/subdomains.txt'
wildcards_file='data/wildcards.txt'
redundant_domains_file='data/redundant_domains.txt'
dead_domains_file='data/dead_domains.txt'
parked_domains_file='data/parked_domains.txt'

[[ "$CI" != true ]] && exit 1  # Do not allow running locally

function main {
    : > "$raw_file"  # Initialize raw file
    sed -i '1q' "$domain_log"  # Initialize domain log file
    [[ "$1" == 'retrieve' ]] && test_retrieve_validate "$1"
    [[ "$1" == 'validate' ]] && test_retrieve_validate "$1"
    [[ "$1" == 'dead' ]] && test_dead_check
    [[ "$1" == 'parked' ]] && test_parked_check
    [[ "$1" == 'shellcheck' ]] && shellcheck
    exit 0
}

function shellcheck {
    url='https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz'
    wget -qO - "$url" | tar -xJ  # Download ShellCheck
    printf "%s\n" "$(shellcheck-stable/shellcheck --version)"

    scripts=$(find . ! -path "./legacy/*" -type f -name "*.sh")  # Find scripts
    while read -r script; do  # Loop through scripts
        shellcheck-stable/shellcheck "$script" || error=true  # Run ShellCheck for each script
    done <<< "$scripts"

    # Check for carriage return characters
    problematic_files=$(grep -rl $'\r' --exclude-dir={legacy,.git,shellcheck-stable} .)
    if [[ -n "$problematic_files" ]]; then
        printf "\n[warn] Lines with carriage return characters:\n"
        printf "%s\n" "$problematic_files"
        error=true
    fi

    # Check for missing space before comments
    problematic_files=$(grep -rn '\S\s#' --exclude-dir={legacy,.git,shellcheck-stable} --exclude=*.csv .)
    if [[ -n "$problematic_files" ]]; then
        printf "\n[warn] Lines with missing space before comments:\n"
        printf "%s\n" "$problematic_files"
        error=true
    fi

    printf "\n[info] Scripts checked (%s):\n%s\n" "$(wc -l <<< "$scripts")" "$scripts"
    [[ "$error" == true ]] && { printf "\n"; exit 1; }  # Exit with error if test failed
}

function test_retrieve_validate {
    script_to_test="$1"
    [[ -d data/pending ]] && rm -r data/pending  # Initialize pending directory
    [[ "$script_to_test" == 'retrieve' ]] && mkdir data/pending

    if [[ "$script_to_test" == 'retrieve' ]]; then
        # Test removal of known dead domains
        {
            printf "dead-test.com\n"
            printf "www.dead-test-2.com\n"
        } > "$dead_domains_file"  # Sample data
        {
            printf "dead-test.com\n"
            printf "www.dead-test-2.com\n"
        } >> input.txt  # Input
        # No expected output (dead domains check does not log)
    fi

    # Test removal of common subdomains
    : > "$subdomains_file"  # Initialize subdomains file
    : > "$root_domains_file"  # Initialize root domains file
    while read -r subdomain; do
        subdomain="${subdomain}.subdomain-test.com"
        printf "%s\n" "$subdomain" >> input.txt  # Input
        printf "%s\n" "$subdomain" >> out_subdomains.txt  # Expected output
        grep -v 'www.' <(printf "subdomain,%s" "$subdomain") >> out_log.txt  # Expected output
    done < "$subdomains_to_remove_file"
    # Expected output
    [[ "$script_to_test" == 'validate' ]] && printf "subdomain,www.subdomain-test.com\n" >> out_log.txt  # The Check script does not exclude 'www' subdomains
    printf "subdomain-test.com\n" >> out_raw.txt
    printf "subdomain-test.com\n" >> out_root_domains.txt

    # Removal of domains already in raw file is redundant to test

    if [[ "$script_to_test" == 'retrieve' ]]; then
        # Test removal of known parked domains
        printf "parked-domains-test.com\n" > "$parked_domains_file"  # Sample data
        printf "parked-domains-test.com\n" >> input.txt  # Input
        printf "parked,parked-domains-test.com\n" >> out_log.txt  # Expected output
    fi

    # Test removal of whitelisted domains and blacklist exclusion
    # Sample data
    printf "whitelist\n" > "$whitelist_file"
    printf "whitelist-blacklisted-test.com\n" > "$blacklist_file"
    # Input
    printf "whitelist-test.com\n" >> input.txt
    printf "whitelist-blacklisted-test.com\n" >> input.txt
    # Expected output
    printf "whitelist-blacklisted-test.com\n" >> out_raw.txt
    printf "whitelist,whitelist-test.com\n" >> out_log.txt
    [[ "$script_to_test" == 'retrieve' ]] && printf "blacklist,whitelist-blacklisted-test.com\n" \
        >> out_log.txt  # The check script does not log blacklisted domains

    # Test removal of domains with whitelisted TLDs
    {
        printf "white-tld-test.gov\n"
        printf "white-tld-test.edu\n"
        printf "white-tld-test.mil\n"
    } >> input.txt  # Input
    {
        printf "tld,white-tld-test.gov\n"
        printf "tld,white-tld-test.edu\n"
        printf "tld,white-tld-test.mil\n"
    } >> out_log.txt  # Expected output

    # Test removal of invalid entries and IP addresses
    {
        printf "invalid-test-com\n"
        printf "100.100.100.100\n"
        printf "invalid-test.xn--903fds\n"
        printf "invalid-test.x\n"
        printf "invalid-test.100\n"
        printf "invalid-test.1x\n"
    } >> input.txt  # Input
    printf "invalid-test.xn--903fds\n" >> out_raw.txt  # Expected output
    [[ "$script_to_test" == 'retrieve' ]] &&
        {
            printf "invalid-test-com\n"
            printf "100.100.100.100\n"
            printf "invalid-test.x\n"
            printf "invalid-test.100\n"
            printf "invalid-test.1x\n"
        } >> out_manual.txt  # Expected output
    {
        printf "invalid,invalid-test-com\n"
        printf "invalid,100.100.100.100\n"
        printf "invalid,invalid-test.x\n"
        printf "invalid,invalid-test.100\n"
        printf "invalid,invalid-test.1x\n"
    } >> out_log.txt  # Expected output

    : > "$redundant_domains_file"  # Initialize redundant domains file
    if [[ "$script_to_test" == 'retrieve' ]]; then
        # Test removal of new redundant domains
        printf "redundant-test.com\n" > "$wildcards_file"  # Sample data
        printf "redundant-test.com\n" >> out_wildcards.txt  # Wildcard should already be in expected wildcards file
        printf "domain.redundant-test.com\n" >> input.txt  # Input
        printf "redundant,domain.redundant-test.com\n" >> out_log.txt  # Expected output
    elif [[ "$script_to_test" == 'validate' ]]; then
        # Test addition of new wildcard from wildcard file (manually adding a new wildcard to wildcards file)
        printf "domain.redundant-test.com\n" >> input.txt  # Sample data
        printf "redundant-test.com\n" > "$wildcards_file"  # Input
        # Expected output
        printf "redundant-test.com\n" >> out_raw.txt
        printf "redundant-test.com\n" >> out_wildcards.txt
        printf "domain.redundant-test.com\n" >> out_redundant.txt
        printf "redundant,domain.redundant-test.com\n" >> out_log.txt
    fi

    # Test toplist check
    printf "microsoft.com\n" >> input.txt  # Input
    # Expected output
    [[ "$script_to_test" == 'validate' ]] && printf "microsoft.com\n" >> out_raw.txt
    [[ "$script_to_test" == 'retrieve' ]] && printf "microsoft.com\n" >> out_manual.txt
    printf "toplist,microsoft.com\n" >> out_log.txt

    # Test light raw file exclusion of specific sources
    if [[ "$script_to_test" == 'retrieve' ]]; then
        cp "$raw_file" "$raw_light_file"
        printf "raw-light-test.com\n" > data/pending/domains_guntab.com.tmp  # Input
        printf "raw-light-test.com\n" >> out_raw.txt  # Expected output
        grep -vF "raw-light-test.com" out_raw.txt > out_raw_light.txt  # Expected output for light (source excluded from light)
    elif [[ "$script_to_test" == 'validate' ]]; then
        cp out_raw.txt out_raw_light.txt  # Expected output for light
    fi

    prep_output  # Prepare expected output files

    if [[ "$script_to_test" == 'retrieve' ]]; then
        # Distribute the sample input into various sources
        split -n l/3 input.txt
        mv xaa data/pending/domains_aa419.org.tmp
        mv xab data/pending/domains_google_search_search-term-1.tmp
        mv xac data/pending/domains_google_search_search-term-2.tmp
        run_script "retrieve_domains.sh" "exit 0"
    elif [[ "$script_to_test" == 'validate' ]]; then
        cp input.txt "$raw_file"  # Input
        mv input.txt "$raw_light_file"  # Input
        run_script "validate_raw.sh" "exit 0"
    fi

    check_output "$raw_file" "out_raw.txt" "Raw"  # Check raw file
    check_output "$raw_light_file" "out_raw_light.txt" "Raw light"  # Check raw light file
    check_output "$subdomains_file" "out_subdomains.txt" "Subdomains"  # Check subdomains file
    check_output "$root_domains_file" "out_root_domains.txt" "Root domains"  # Check root domains file
    if [[ "$script_to_test" == 'retrieve' ]]; then
        check_output "data/pending/domains_manual_review.tmp" "out_manual.txt" "Manual review"  # Check manual review file
    elif [[ "$script_to_test" == 'validate' ]]; then
        check_output "$redundant_domains_file" "out_redundant.txt" "Redundant domains"  # Check redundant domains file
        check_output "$wildcards_file" "out_wildcards.txt" "Wildcards"  # Check wildcards file
    fi
    check_log  # Check log file

    [[ "$error" != true ]] && printf "[success] Test completed. No errors found.\n\n"
    [[ "$log_error" != true ]] && printf "[info] Log:\n%s\n" "$(<$domain_log)"
    [[ "$error" == true ]] && { printf "\n"; exit 1; }  # Exit with error if test failed
}

function test_dead_check {
    # Test addition of resurrected domains
    # Input
    printf "www.google.com\n" > "$dead_domains_file"  # Subdomains should be stripped
    printf "584031dead-domain-test.com\n" >> "$dead_domains_file"
    # Expected output
    printf "google.com\n" >> out_raw.txt
    printf "584031dead-domain-test.com\n" >> out_dead.txt
    printf "resurrected,google.com,dead_domains_file\n" >> out_log.txt

    # Test removal of dead domains with subdomains
    : > "$subdomains_file"  # Initialize subdomains file
    printf "584308-dead-subdomain-test.com\n" >> "$raw_file"  # Input
    printf "584308-dead-subdomain-test.com\n" > "$root_domains_file"  # Input
    while read -r subdomain; do
        subdomain="${subdomain}.584308-dead-subdomain-test.com"
        printf "%s\n" "$subdomain" >> "$subdomains_file"  # Input
        printf "%s\n" "$subdomain" >> out_dead.txt  # Expected output
    done < "$subdomains_to_remove_file"
    printf "%s\n" "dead,584308-dead-subdomain-test.com,raw" >> out_log.txt  # Expected output

    # Test removal of dead redundant domains and wildcards
    : > "$redundant_domains_file"  # Initialize redundant domains file
    printf "493053dead-wildcard-test.com\n" >> "$raw_file"  # Input
    printf "493053dead-wildcard-test.com\n" > "$wildcards_file"  # Input
    {
        printf "redundant-1.493053dead-wildcard-test.com\n"
        printf "redundant-2.493053dead-wildcard-test.com\n"
    } >> "$redundant_domains_file"  # Input
    {
        printf "redundant-1.493053dead-wildcard-test.com\n"
        printf "redundant-2.493053dead-wildcard-test.com\n"
    } >> out_dead.txt  # Expected output
    {
        printf "dead,493053dead-wildcard-test.com,wildcard\n"
        printf "dead,493053dead-wildcard-test.com,wildcard\n"
    } >> out_log.txt  # Expected output

    # Check removal of dead domains
    # Input
    printf "apple.com\n" >> "$raw_file"
    printf "49532dead-domain-test.com\n" >> "$raw_file"  # Input
    # Expected output
    printf "apple.com\n" >> out_raw.txt
    printf "49532dead-domain-test.com\n" >> out_dead.txt
    printf "dead,49532dead-domain-test.com,raw\n" >> out_log.txt

    # Test raw light file
    cp "$raw_file" "$raw_light_file"
    grep -vF 'google.com' out_raw.txt > out_raw_light.txt  # Expected output for light (resurrected domains are not added back to light)

    run_script "check_dead.sh"
    check_output "$raw_file" "out_raw.txt" "Raw"  # Check raw file
    check_output "$raw_light_file" "out_raw_light.txt" "Raw light"  # Check raw light file
    check_output "$dead_domains_file" "out_dead.txt" "Dead domains"  # Check dead domains file
    check_if_dead_present "$subdomains_file" "Subdomains"  # Check subdomains file
    check_if_dead_present "$root_domains_file" "Root domains"  # Check root domains file
    check_if_dead_present "$redundant_domains_file" "Redundant domains"  # Check redundant domains file
    check_if_dead_present "$wildcards_file" "Wildcards"  # Check wildcards file
    check_log  # Check log file

    [[ "$error" != true ]] && printf "[success] Test completed. No errors found.\n\n" ||
        printf "[warn] The dead-domains-linter may have false positives. Rerun the job to confirm.\n\n"
    [[ "$log_error" != true ]] && printf "[info] Log:\n%s\n" "$(<$domain_log)"
    [[ "$error" == true ]] && { printf "\n"; exit 1; }  # Exit with error if test failed
}

function test_parked_check {
    # Placeholders needed as sample data (split does not work well without enough records)
    not_parked_placeholder=$(head -n 50 "$toplist_file")
    parked_placeholder=$(head -n 50 "$parked_domains_file")
    printf "%s\n" "$not_parked_placeholder" > placeholders.txt
    printf "%s\n" "$not_parked_placeholder" > "$raw_file"
    printf "%s\n" "$parked_placeholder" >> placeholders.txt
    printf "%s\n" "$parked_placeholder" > "$parked_domains_file"

    # Test addition of unparked domains in parked domains file
    printf "google.com\n" >> "$parked_domains_file"  # Unparked domain as input
    # Expected output
    printf "google.com\n" >> out_raw.txt
    printf "unparked,google.com,parked_domains_file\n" >> out_log.txt

    # Test removal of parked domains
    # Input
    printf "tradexchange.online\n" >> "$raw_file"
    printf "apple.com\n" >> "$raw_file"
    # Expected output
    printf "tradexchange.online\n" >> out_parked.txt
    printf "apple.com\n" >> out_raw.txt
    printf "parked,tradexchange.online,raw\n" >> out_log.txt

    # Test raw light file
    cp "$raw_file" "$raw_light_file"
    grep -vxF 'google.com' out_raw.txt > out_raw_light.txt  # Unparked domains are not added back to light

    run_script "check_parked.sh"

    # Remove placeholder lines
    comm -23 "$raw_file" placeholders.txt > raw.tmp && mv raw.tmp "$raw_file"
    comm -23 "$raw_light_file" placeholders.txt > raw_light.tmp && mv raw_light.tmp "$raw_light_file"
    grep -vxFf placeholders.txt "$parked_domains_file" > parked.tmp && mv parked.tmp "$parked_domains_file"

    check_output "$raw_file" "out_raw.txt" "Raw"  # Check raw file
    check_output "$raw_light_file" "out_raw_light.txt" "Raw light"  # Check raw light file
    check_output "$parked_domains_file" "out_parked.txt" "Parked domains"  # Check parked domains file
    check_log  # Check log file
    [[ "$error" != true ]] && printf "[success] Test completed. No errors found.\n\n"
    [[ "$error" == true ]] && { printf "\n"; exit 1; }  # Exit with error if test failed
}

function run_script {
    for file in out_*; do  # Format expected output files
        [[ "$file" != out_dead.txt ]] && [[ "$file" != out_parked.txt ]] && sort "$file" -o "$file"
    done
    printf "[start] %s\n" "$1"
    printf "%s\n" "----------------------------------------------------------------------"
    [[ "$2" == "exit 0" ]] && bash "functions/${1}" || printf ""  # printf to negative exit status 1
    [[ -z "$2" ]] && bash "functions/${1}"
    [[ "$?" -eq 1 ]] && errored=true  # Check returned exit status
    printf "%s\n" "----------------------------------------------------------------------"
    [[ "$errored" == true ]] && { printf "[warn] Script returned an error.\n"; error=true; }  # Check exit status
}

function check_output {
    cmp -s "$1" "$2" && return  # Return if files are the same
    printf "[warn] %s file is not as expected:\n" "$3"
    cat "$1"
    printf "\n[info] Expected output:\n"
    cat "$2"
    printf "\n"
    error=true
}

function check_if_dead_present {
    ! grep -q '[[:alnum:]]' "$1" && return  # Return if file has no domains
    printf "[warn] %s file still has dead domains:\n" "$2"
    cat "$1"
    printf "\n"
    error=true
}

function check_log {
    while read -r log_term; do
        ! grep -qF "$log_term" "$domain_log" && { log_error=true; break; }  # Break when error found
    done < out_log.txt
    [[ "$log_error" != true ]] && return  # Return if no error found
    printf "[warn] Log file is not as expected:\n"
    cat "$domain_log"
    printf "\n[info] Terms expected in log:\n"
    cat out_log.txt  # No need for additional new line since the log is not printed again
    error=true
}

main "$1"
