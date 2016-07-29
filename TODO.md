# To do

1. parse collection URIs out of [`harvest.sh`](data/harvest.sh) script for production environment
2. for each URI:
   - determine tenant
   - ~~get Atom feed for URI~~
   - for each page in Atom feed
     - for each entry
       - find `<link title="producer/mrt-((datacite)|(eml)).xml"/>`
         - extract `href`
         - note type (Datacite or EML)
       - ~~find all `<link title="producer/(?!mrt-).*+">`~~
         - ~~extract `href`, `length`, and `type`~~
     - determine author
       - ???
     - extract and clean up funding information
     - ~~determine DOI~~
       - ~~find `<link title="system/mrt-mom.txt"/>`~~
       - ~~parse DOI out of `localIdentifier:` line~~
     - use `lib/stash_datacite/test_import.rb` or similar to write database records
     - use indexer to index, or
       - figure out sword-edit IRI based on ark
         - make sure we post to the right environment server
         - for dev & stage, allow create rather than update, i.e. don't synthesize sword-edit IRI
       - use `stash_datacite` code to create a new ZIP package w/Datacite & stash-wrapper & post SWORD update to Merritt
