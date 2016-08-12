require 'typesafe_enum'

module Dash2
  module Migrator
    class IDMode < TypesafeEnum::Base
      new :ALWAYS_UPDATE
      new :ALWAYS_MINT
    end
  end
end
