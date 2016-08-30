require 'active_support'
require 'logger'

module Dash2
  module Migrator
    Dir.glob(File.expand_path('../migrator/*.rb', __FILE__)).sort.each(&method(:require))
  end
end
