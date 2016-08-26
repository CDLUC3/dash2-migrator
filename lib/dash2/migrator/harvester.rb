module Dash2
  module Migrator
    module Harvester
      Dir.glob(File.expand_path('../harvester/*.rb', __FILE__)).sort.each(&method(:require))
    end
  end
end
