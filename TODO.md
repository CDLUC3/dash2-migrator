# To do

1. parse collection URIs out of [`harvest.sh`](data/harvest.sh) script for production environment
2. for each URI:
   - get Atom feed for URI
   - for each page in Atom feed
     - for each entry
       - find `<link title="producer/mrt-((datacite)|(eml)).xml"/>`
         - extract `href`
         - note type (Datacite or EML)
       - find all `<link title="producer/(?!mrt-).*+">`
         - extract `href`, `length`, and `type`
     - determine author
       - ???
     - use `lib/stash_datacite/test_import.rb` or similar to write database records
     - use indexer to index, or
       - figure out sword-edit IRI based on ark
       - use `stash_datacite` code to create a new ZIP package w/Datacite & stash-wrapper
       - post SWORD update to Merritt 
