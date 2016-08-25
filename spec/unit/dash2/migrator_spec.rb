module Dash2
  describe Migrator do
    it 'writes stash-wrapper dates as Zulu'
    it 'writes the modified datacite XML back into the stash wrapper'
    it 'collapses whitespace'
    it 'trims'
    it 'dehyphenates' # gsub(/-\s+/, '')
  end
end
