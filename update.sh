#!/bin/bash

domains_file="domains.txt"
pending_file="pending_domains.txt"
search_terms_file="search_terms.txt"
whitelist_file="whitelist.txt"
blacklist_file="blacklist.txt"
toplist_file="toplist.txt"
tlds_file="white_tlds.txt"

if [[ -s "$pending_file" ]]; then
    read -p "$pending_file is not empty. Do you want to empty it? (Y/n): " answer
    if [[ ! "$answer" == "n" ]]; then
        > "$pending_file"
    fi
fi

declare -A retrieved_domains

echo "Search terms:"

# Loop through each search term in its entirety from the search terms file
while IFS= read -r term; do
    if [[ -n "$term" ]]; then
        # gsub is used here to replace consecutive non-alphanumeric characters with a single plus sign
        encoded_term=$(echo "$term" | awk '{gsub(/[^[:alnum:]]+/,"+"); print}')

        user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36"

        google_search_url="https://www.google.com/search?q=\"${encoded_term}\"&num=100&filter=0"

        # Search Google and extract all domains
        # Duplicates are removed here for accurate counting of the retrieved domains by each search term
        domains=$(curl -s --max-redirs 0 -H "User-Agent: $user_agent" "$google_search_url" | grep -oE '<a href="https:\S+"' | awk -F/ '{print $3}' | sort -u)

        echo "$term"
        echo "Unique domains retrieved: $(echo "$domains" | wc -l)"
        echo "--------------------------------------------"

        # Check if each domain is already in the retrieved domains associative array
        for domain in $domains; do
            if [[ ${retrieved_domains["$domain"]+_} ]]; then
               continue 
            fi
            # Add the unique domain to the associative array
            retrieved_domains["$domain"]=1
            echo "$domain" >> "$pending_file"
        done
    fi
done < "$search_terms_file"

num_retrieved=${#retrieved_domains[@]}

function filter_pending {
    cp "$pending_file" "$pending_file.bak"

    awk NF "$pending_file" > tmp1.txt

    tr '[:upper:]' '[:lower:]' < tmp1.txt > tmp2.txt

    # Has to be done before sorting alphabetically
    awk '{sub(/^www\./, ""); print' tmp2.txt > tmp3.txt

    # Although the retrieved domains are already deduplicated, not emptying the pending domains file may result in duplicates
    sort -u tmp3.txt -o tmp4.txt

    # Keep only pending domains not already in the blocklist for filtering
    # This removes the majority of pending domains and makes the further filtering more efficient
    comm -23 tmp4.txt "$domains_file" > tmp5.txt

    echo "Domains removed:"

    grep -f "$whitelist_file" tmp5.txt | awk '{print $1" (whitelisted)"}'

    grep -vf "$whitelist_file" tmp5.txt > tmp6.txt

    # Print and remove non domain entries
    # The regex checks for one or more alphanumeric characters, periods or dashes infront of a period followed by two or more alphanumeric characters
    awk '{ if ($0 ~ /^[[:alnum:].-]+\.[[:alnum:]]{2,}$/) print $0 > "tmp7.txt"; else print $0" (invalid)" }' tmp6.txt

    # Print domains with whitelisted TLDs
    grep -E "(\S+)\.($(paste -sd '|' "$tlds_file"))$" tmp7.txt | awk '{print $1" (TLD)"}'

    # Remove domains with whitelisted TLDs
    grep -vE "\.($(paste -sd '|' "$tlds_file"))$" tmp7.txt > tmp8.txt

    touch tmp_dead.txt
    touch tmp_www.txt

    # Use parallel processing
    cat tmp8.txt | xargs -I{} -P4 bash -c "
        if dig @1.1.1.1 {} | grep -q 'NXDOMAIN'; then
            echo {} >> tmp_dead.txt
            echo '{} (dead)'
        fi
    "

    comm -23 tmp8.txt <(sort tmp_dead.txt) > tmp9.txt
    
    awk '{print "www." $0}' tmp_dead.txt > tmpA.txt

    # Check if the www subdomains are resolving
    cat tmpA.txt | xargs -I{} -P4 bash -c "
        if ! dig @1.1.1.1 {} | grep -q 'NXDOMAIN'; then
            echo {} >> tmp_www.txt
            echo '{} is resolving'
        fi
    "

    comm -23 <(sort tmp_www.txt) tmp9.txt >> tmp10.txt

    sort tmp10.txt -o "$pending_file"
    
    # TODO...
    
    num_pending=$(wc -l < "$pending_file")

    # Remove temporary files
    rm tmp*.txt

    # Print counters
    echo -e "\nTotal domains retrieved: $num_retrieved"
    echo "Domains not in blocklist: $num_pending"
    echo "Domains:"
    cat "$pending_file"
    echo -e "\nDomains in toplist:"
    grep -xFf "$pending_file" "$toplist_file" | grep -vxFf "$blacklist_file"
}

# Execute filtering for pending domains
filter_pending

# Define a function to merge filtered pending domains to the domains file
function merge_pending {
    echo "Merge with blocklist"

    # Backup the domains file before making any changes
    cp "$domains_file" "$domains_file.bak"

    # Count the number of domains before merging
    num_before=$(wc -l < "$domains_file")

    # Append unique pending domains to the domains file
    comm -23 "$pending_file" "$domains_file" >> "$domains_file"

    # Sort alphabetically
    sort -o "$domains_file" "$domains_file"

    # Count the number of domains after merging
    num_after=$(wc -l < "$domains_file")

    # Print counters
    echo "--------------------------------------------"
    echo "Total domains before: $num_before"
    echo "Total domains added: $((num_after - num_before))"
    echo "Final domains after: $num_after"

    # Empty pending domains file
    > "$pending_file"

    # Exit script
    exit 0
}

# Prompt the user with options on how to proceed
while true; do
    echo -e "\nChoose how to proceed:"
    echo "1. Merge with blocklist (default)"
    echo "2. Add to whitelist"
    echo "3. Add to blacklist"
    echo "4. Run filter again"
    echo "5. Exit"
    read choice

    case "$choice" in
        1)
            merge_pending
            ;;
        2)
            echo "Add to whitelist"
            read -p "Enter the new entry: " new_entry
            
            # Change the new entry to lowecase
            new_entry="${new_entry,,}"

            # Check if a similar term is already in the whitelist
            if grep -Fiq "$new_entry" "$whitelist_file"; then
                existing_entry=$(grep -Fi "$new_entry" "$whitelist_file" | head -n 1)
                echo "A similar term is already in the whitelist: $existing_entry"
                continue
            fi

            # Add the new entry
            echo -e "\nAdded to whitelist: $new_entry"
            echo "$new_entry" >> "$whitelist_file"

            # Remove empty lines
            awk NF "$whitelist_file" > tmp1.txt

            # Save changes and sort alphabetically
            sort -o "$whitelist_file" tmp1.txt

            # Remove temporary file
            rm tmp1.txt
            continue
            ;;
        3)
            echo "Add to blacklist"
            read -p "Enter the new entry: " new_entry
            
            # Change the new entry to lowecase
            new_entry="${new_entry,,}"
            
            # Check if the entry is valid
            if ! [[ $new_entry =~ ^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$ ]]; then
                echo -e "\nInvalid entry."
                continue
            fi

            # Check if the new entry is already in the list
            if grep -xq "$new_entry" "$blacklist_file"; then
                echo "The domain is already in the blacklist. Not added."
                continue
            fi

            # Add the new entry
            echo -e "\nAdded to blacklist: $new_entry"
            echo "$new_entry" >> "$blacklist_file"

            # Remove empty lines
            awk NF "$blacklist_file" > tmp1.txt

            # Save changes and sort alphabetically
            sort -o "$blacklist_file" tmp1.txt

            # Remove temporary file
            rm tmp1.txt
            continue
            ;;
        4)
            echo "Run filter again"
            filter_pending
            continue
            ;;
        5)
            exit 0
            ;;
        *)
            # Use domain merger as the default option
            if [[ -z "$choice" ]]; then
                merge_pending
            else
                echo "Invalid option."

                # Go back to options prompt
                continue     
            fi
    esac
done
