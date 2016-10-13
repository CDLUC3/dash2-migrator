require 'datacite/mapping'

module Datacite
  module Mapping
    class Rights
      UCSF_DUA = Rights.new(
        uri: URI('https://dx.doi.org/10.5060/D8TG65'),
        value: 'UCSF Datashare Data Use Agreement'
      )
      UCSF_FEB_13 = Rights.new(
        uri:  URI('https://dx.doi.org/10.5060/D8PP47'),
        value: 'Terms of use are available at: doi:10.5060/D8PP47'
      )

      # TODO: consider pushing this to datacite-mapping
      def value=(v)
        @value = v.strip.tr("\n", ' ').squeeze(' ')
      end
    end
  end
end
