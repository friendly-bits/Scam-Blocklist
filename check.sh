#!/bin/bash

domains_file="domains"
whitelist_file="whitelist.txt"
blacklist_file="blacklist.txt"
toplist_file="toplist.txt"
tlds_file="white_tlds.txt"

cp "$domains_file" "$domains_file.bak"

awk NF "$domains_file" > tmp1.txt

tr '[:upper:]' '[:lower:]' < tmp1.txt > tmp2.txt

num_before=$(wc -l < tmp2.txt)

sort -u tmp2.txt -o tmp3.txt

echo "Domains removed:"

grep -Ff "$whitelist_file" tmp3.txt | grep -vxFf "$blacklist_file" | awk '{print $0 " (whitelisted)"}'

grep -Ff "$whitelist_file" tmp3.txt | grep -vxFf "$blacklist_file" > tmp_white.txt

comm -23 tmp3.txt <(sort tmp_white.txt) > tmp4.txt

grep -vE '^[[:alnum:].-]+\.[[:alnum:]]{2,}$' tmp4.txt | awk '{print $0 " (invalid)"}'
    
grep -E '^[[:alnum:].-]+\.[[:alnum:]]{2,}$' tmp4.txt > tmp5.txt
   
grep -E "(\S+)\.($(paste -sd '|' "$tlds_file"))$" tmp5.txt | awk '{print $0 " (TLD)"}'

grep -vE "\.($(paste -sd '|' "$tlds_file"))$" tmp5.txt > tmp6.txt
    
touch tmp_dead.txt

cat tmp6.txt | xargs -I{} -P8 bash -c "
  if dig @1.1.1.1 {} | grep -Fq 'NXDOMAIN'; then
      echo {} >> tmp_dead.txt
      echo '{} (dead)'
  fi
"

comm -23 tmp6.txt <(sort tmp_dead.txt) > tmp7.txt

mv tmp7.txt "$domains_file"

echo -e "\nDomains in toplist:"
grep -xFf "$domains_file" "$toplist_file" | grep -vxFf "$blacklist_file"

num_after=$(wc -l < "$domains_file")

rm tmp*.txt

echo "Total domains before: $num_before"
echo "Total domains removed: $((num_before - num_after))"
echo "Final domains after: $num_after"
