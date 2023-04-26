#!/bin/bash

readme="README.md"
domains_file="domains.txt"
adblock_file="adblock.txt"
github_email="91372088+jarelllama@users.noreply.github.com"
github_name="jarelllama"

git config user.email "$github_email"
git config user.name "$github_name"

git add "$domains_file" "$adblock_file"
git commit -m "Build lists"

git add "$readme"
git commit -m "Update domains/entries count"

git push
