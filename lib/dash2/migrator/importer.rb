require 'active_support'
require 'logger'

module Dash2
  module Migrator
    module Importer
      Dir.glob(File.expand_path('../importer/*.rb', __FILE__)).sort.each(&method(:require))
    end
  end
end
