#!/bin/bash

adblock_file="adblock.txt"
redundant_rules="data/redundant_rules.txt"
github_email="91372088+jarelllama@users.noreply.github.com"
github_name="jarelllama"

grep -vE '^(!|$)' "$adblock_file" > adblock.tmp

while read -r entry; do
    grep "\.${entry#||}$" adblock.tmp >> "$redundant_rules"
done < adblock.tmp

# The output has a high chance of having duplicates
sort -u "$redundant_rules" -o "$redundant_rules"

rm *.tmp

if ! [[ -s "$redundant_rules" ]]; then
    echo -e "\nNo redundant rules found.\n"
    exit 0
fi

git config user.email "$github_email"
git config user.name "$github_name"

git add "$redundant_rules"
git commit -qm "Compress $adblock_file"
# Push after building list
