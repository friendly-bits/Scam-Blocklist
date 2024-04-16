# Jarelllama's Scam Blocklist

Blocklist for newly created scam and phishing domains automatically retrieved daily using Google Search API, automated detection, and other public sources. The [automated retrieval](https://github.com/jarelllama/Scam-Blocklist/actions/workflows/build_deploy.yml) is done at 10:00 AM UTC.

This blocklist aims to be an alternative to blocking all newly registered domains (NRDs) seeing how many, but not all, NRDs are malicious. A variety of sources are integrated to detect new malicious domains within a short time span of their registration date.

| Format | Syntax |
| --- | --- |
| [Adblock Plus](https://raw.githubusercontent.com/jarelllama/Scam-Blocklist/main/lists/adblock/scams.txt) | \|\|scam.com^ |
| [Dnsmasq](https://raw.githubusercontent.com/jarelllama/Scam-Blocklist/main/lists/dnsmasq/scams.txt) | local=/scam.com/ |
| [Unbound](https://raw.githubusercontent.com/jarelllama/Scam-Blocklist/main/lists/unbound/scams.txt) | local-zone: "scam.com." always_nxdomain |
| [Wildcard Asterisk](https://raw.githubusercontent.com/jarelllama/Scam-Blocklist/main/lists/wildcard_asterisk/scams.txt) | \*.scam.com |
| [Wildcard Domains](https://raw.githubusercontent.com/jarelllama/Scam-Blocklist/main/lists/wildcard_domains/scams.txt) | scam.com |

## Statistics

[![Build and deploy](https://github.com/jarelllama/Scam-Blocklist/actions/workflows/build_deploy.yml/badge.svg)](https://github.com/jarelllama/Scam-Blocklist/actions/workflows/build_deploy.yml)
[![Test functions](https://github.com/jarelllama/Scam-Blocklist/actions/workflows/test_functions.yml/badge.svg)](https://github.com/jarelllama/Scam-Blocklist/actions/workflows/test_functions.yml)

``` text
Total domains: 39538
Light version: 4112

New domains for each source:
Today | Yesterday | Excluded | Source
    0 |        78 |       3% | Google Search
    0 |         5 |       0% | Manual Entries
    0 |        74 |       2% | Regex Matching (NRDs)
    0 |        20 |       8% | aa419.org
    0 |        28 |       0% | dnstwist (NRDs)
    0 |         0 |      19% | guntab.com
    0 |         0 |       6% | petscams.com
    0 |         0 |      63% | scam.directory
    0 |         0 |      35% | scamadviser.com
    0 |         0 |       3% | stopgunscams.com
    0 |       205 |      15% | All sources

* The Excluded % is of domains not included in the
 blocklist. Mostly dead, whitelisted, and parked domains.
* Only active sources are shown. See the full list of
 sources in SOURCES.md.
```

All data retrieved are publicly available and can be viewed from their respective [sources](https://github.com/jarelllama/Scam-Blocklist/blob/main/SOURCES.md).

<details>
<summary>Domains over time (days)</summary>

![Domains over time](https://raw.githubusercontent.com/iam-py-test/blocklist_stats/main/stats/Jarelllamas_Scam_Blocklist.png)

Courtesy of iam-py-test/blocklist_stats.
</details>

## Light version

Targeted at list maintainers, a light version of the blocklist is available in the [lists](https://github.com/jarelllama/Scam-Blocklist/tree/main/lists) directory.

<details>
<summary>Details about the light version</summary>
<ul>
<li>Intended for collated blocklists cautious about size</li>
<li>Only includes sources whose domains can be filtered by date registered/reported</li>
<li>Only includes domains retrieved/reported from February 2024 onwards, whereas the full list goes back further historically</li>
<li>Note that dead and parked domains that become alive/unparked are not added back into the light version (due to limitations in the way these domains are recorded)</li>
</ul>
Sources excluded from the light version are marked in SOURCES.md.
<br>
<br>
The full version should be used where possible as it fully contains the light version.
</details>

## Sources

### Retrieving scam domains using Google Search API

Google provides a [Search API](https://developers.google.com/custom-search/v1/overview) to retrieve JSON-formatted results from Google Search. A list of search terms almost exclusively found in scam sites is used by the API to retrieve domains. See the list of search terms here: [search_terms.csv](https://github.com/jarelllama/Scam-Blocklist/blob/main/config/search_terms.csv)

#### Effectiveness

Scam sites often do not have long lifespans; malicious domains may be replaced before they can be manually reported. By programmatically searching Google using paragraphs from real-world scam sites, new domains can be added as soon as Google crawls the site. This requires no manual reporting.

The list of search terms is proactively maintained and is mostly sourced from investigating new scam site templates seen on [r/Scams](https://www.reddit.com/r/Scams/).

#### Statistics for Google Search source

``` text
Active search terms: 18
API calls made today: 0
Domains retrieved today: 0
```

### Retrieving phishing NRDs using dnstwist

New phishing domains are created daily, and unlike other sources that rely on manual reporting, [dnstwist](https://github.com/elceef/dnstwist) can automatically detect new phishing domains within days of their registration date.

dnstwist is an open-source detection tool for common cybersquatting techniques like [Typosquatting](https://en.wikipedia.org/wiki/Typosquatting), [Doppelganger Domains](https://en.wikipedia.org/wiki/Doppelganger_domain), and [IDN Homograph Attacks](https://en.wikipedia.org/wiki/IDN_homograph_attack).

#### Effectiveness

dnstwist uses a list of common phishing targets to find permutations of the targets' domains. The target list is a handpicked compilation of cryptocurrency exchanges, delivery companies, etc. collated while wary of potential false positives. The list of phishing targets can be viewed here: [phishing_targets.csv](https://github.com/jarelllama/Scam-Blocklist/blob/main/config/phishing_targets.csv)

The generated domain permutations are checked for matches in a newly registered domains (NRDs) feed comprising domains registered within the last 30 days. Each permutation is also tested for alternate top-level domains (TLDs) using the 15 most prevalent TLDs from the NRD feed at the time of retrieval.

Paired with the NRD feed, dnstwist can effectively retrieve newly-created phishing domains with marginal false positives.

#### Statistics for dnstwist source

``` text
Active targets: 69
Domains retrieved today: 0
```

### Regarding other sources

All sources used presently or formerly are credited here: [SOURCES.md](https://github.com/jarelllama/Scam-Blocklist/blob/main/SOURCES.md)

The domain retrieval process for all sources can be viewed in the repository's code.

## Automated filtering process

* The domains collated from all sources are filtered against an actively maintained whitelist (scam reporting sites, forums, vetted stores, etc.)
* The domains are checked against the [Tranco Top Sites Ranking](https://tranco-list.eu/) for potential false positives which are then vetted manually
* Common subdomains like 'www' are stripped to make use of wildcard matching for all other subdomains. The list of subdomains checked for can be viewed here: [subdomains.txt](https://github.com/jarelllama/Scam-Blocklist/blob/main/config/subdomains.txt)
* Only domains are included in the blocklist; IP addresses are manually checked for resolving DNS records and URLs are stripped down to their domains

Entries that require manual verification/intervention are sent in a Telegram notification for fast remediations.

Example message body:
> Entries requiring manual review:<br>
> ovsfashion.com (toplist)<br>
> aprilcash2023[.]com (invalid)

The full filtering process can be viewed in the repository's code.

## Dead domains

Dead domains are removed daily using AdGuard's [Dead Domains Linter](https://github.com/AdguardTeam/DeadDomainsLinter).

Dead domains that are resolving again are included back into the blocklist.

### Statistics for dead domains

``` text
Dead domains removed today: 0
Resurrected domains added today: 0
```

## Parked domains

From initial testing, [9%](https://github.com/jarelllama/Scam-Blocklist/commit/84e682fea95866670dd99f5c98f350bc7377011a) of the blocklist consisted of [parked domains](https://www.godaddy.com/resources/ae/skills/parked-domain) that inflated the number of entries. Because these domains pose no real threat (besides the obnoxious advertising), they are removed from the blocklist daily.

A list of common parked domain messages is used to automatically detect these domains. This list can be viewed here: [parked_terms.txt](https://github.com/jarelllama/Scam-Blocklist/blob/main/config/parked_terms.txt)

If these parked sites no longer contain any of the parked messages, they are assumed to be unparked and are added back into the blocklist.

For list maintainers interested in integrating the parked domains as a source, the list of daily-updated parked domains can be found here: [parked_domains.txt](https://github.com/jarelllama/Scam-Blocklist/blob/main/data/parked_domains.txt) (capped to newest 7000 entries)

### Statistics for parked domains

``` text
Parked domains removed today: 0
Unparked domains added today: 0
```

## Resources / see also

* [AdGuard's Dead Domains Linter](https://github.com/AdguardTeam/DeadDomainsLinter): tool for checking Adblock rules for dead domains
* [Elliotwutingfeng's repositories](https://github.com/elliotwutingfeng?tab=repositories): various original blocklists
* [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html): Shell script style guide
* [Grammarly](https://grammarly.com/): spelling and grammar checker
* [Legality of web scraping](https://www.quinnemanuel.com/the-firm/publications/the-legal-landscape-of-web-scraping/): the law firm of Quinn Emanuel Urquhart & Sullivan's memoranda on web scraping
* [ShellCheck](https://github.com/koalaman/shellcheck): Shell script static analysis tool
* [who.is](https://who.is/): WHOIS and DNS lookup tool

## As seen in

* [Collinbarrett's FilterLists directory](https://filterlists.com/)
* [Fabriziosalmi's Hourly Updated Domains Blacklist](https://github.com/fabriziosalmi/blacklists)
* [Hagezi's Threat Intelligence Feeds](https://github.com/hagezi/dns-blocklists?tab=readme-ov-file#closed_lock_with_key-threat-intelligence-feeds---increases-security-significantly-recommended-)
* [The oisd blocklist](https://oisd.nl/)
* [file-git.trli.club](https://file-git.trli.club/)
* [iam-py-test/my_filters_001](https://github.com/iam-py-test/my_filters_001)

## Appreciation

Thanks to the following people for the help, inspiration, and support!

* [@bongochong](https://github.com/bongochong)
* [@hagezi](https://github.com/hagezi)
* [@iam-py-test](https://github.com/iam-py-test)
* [@sjhgvr](https://github.com/sjhgvr)

## Sponsorship

<https://github.com/sponsors/jarelllama>
