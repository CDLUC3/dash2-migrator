require 'spec_helper'
require 'stash_datacite'
require 'stash_engine'

logfile = File.expand_path('log/test.log')
FileUtils.mkdir_p File.dirname(logfile)
ActiveRecord::Base.logger = Logger.new(logfile) if defined?(ActiveRecord::Base)

db_config = YAML.load_file('config/database.yml')['test']
ActiveRecord::Base.establish_connection(db_config)
ActiveRecord::Migration.verbose = false
ActiveRecord::Migrator.up 'db/migrate'

# NOTE: This should really be in stash_datacite, but we don't have the test
# infrastructure, so it's convenient to put it here.

module Datacite
  module Mapping

    describe DataciteXMLBuilder do

      def create_builder(se_resource)
        doi_value = ((se_ident = se_resource.identifier) && se_ident.identifier) || '10.5555/12345678'
        total_size_bytes = se_resource.current_file_uploads.inject(0) { |sum, u| sum + u.upload_file_size }
        version = se_resource.next_version
        DataciteXMLBuilder.new(
          se_resource: se_resource,
          doi_value: doi_value,
          total_size_bytes: total_size_bytes,
          version: version
        )
      end

      it 'writes all DB resources as DC4 and DC3' do
        ActiveRecord::Base.transaction do
          total = 0
          aggregate_failures 'writing all resources' do
            StashEngine::Resource.where.not(download_uri: nil).each do |se_resource|
              total += 1
              id = se_resource.id
              titles = se_resource.titles
              puts "writing #{id}: '#{titles.map(&:title).join(': ')}'"

              begin
                builder = create_builder(se_resource)
                resource_dc4 = builder.build_resource
                expect(resource_dc4).to be_a(Resource)
                resource_dc4.write_to_file("tmp/#{se_resource.id}-dc4.xml", pretty: true)

                resource_dc3 = builder.build_resource(datacite_3: true)
                expect(resource_dc3).to be_a(Resource)
                resource_dc3.write_to_file("tmp/#{id}-dc3.xml", pretty: true, options: { mapping: :datacite_3 })
              rescue NoMethodError => e
                warn "#{e}\n#{e.backtrace.join("\n")}"
                raise
              rescue ArgumentError => e
                warn "#{e}\n#{e.backtrace.join("\n")}"
                expect(e).to be_nil, "ArgumentError writing resource #{id}: #{e}"
              end
            end
          end
          expect(total).to eq(297)
        end
      end

    end
  end
end
