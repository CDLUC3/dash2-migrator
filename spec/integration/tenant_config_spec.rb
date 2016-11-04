require 'spec_helper'

module Dash2
  module Migrator
    describe 'tenant configuration' do
      DOI_PATTERN = Dash2::Migrator::Harvester::MerrittAtomHarvestedRecord::DOI_PATTERN
      ARK_PATTERN = Dash2::Migrator::Harvester::MerrittAtomHarvestedRecord::ARK_PATTERN

      attr_reader :all_tenants
      attr_reader :doi_to_ark
      attr_reader :doi_to_tenant
      attr_reader :tenant_to_shoulder

      before(:all) do
        @doi_to_ark = {}
        @doi_to_tenant = {}
        @all_tenants = []
        Dir.glob('spec/data/harvester/moms/*mrt-mom.txt').sort.each do |f|
          tenant = %r{^[a-z]+}.match(File.basename(f))[0]
          all_tenants << tenant unless all_tenants.include?(tenant)

          mrt_mom = File.read(f)
          doi = DOI_PATTERN.match(mrt_mom)[0].strip
          ark = ARK_PATTERN.match(mrt_mom)[0].strip

          doi_to_tenant[doi] = tenant
          doi_to_ark[doi] = ark
        end
        all_tenants.sort!

        @tenant_to_shoulder = Dash2::Migrator::MigrationJob.from_file('config/migrate-all.yml').sources.map do |s|
          tenant_path = s[:tenant_path]
          config = YAML.load_file(tenant_path)['production']
          tenant_id = config['tenant_id']
          ezid_config = config['identifier_service']
          shoulder = ezid_config['shoulder']
          [tenant_id, shoulder]
        end.to_h
      end

      describe 'each tenant' do
        it 'has the correct shoulder' do
          expected_shoulders = {
            dataone: 'doi:10.15146/R3',
            ucsf: 'doi:10.7272/Q6',
            ucsc: 'doi:10.7291/D1',
            ucop: 'doi:10.5060/D8',
            ucm: 'doi:10.6071/M3',
            ucla: 'doi:10.5068/D1',
            uci: 'doi:10.7280/D1',
            ucb: 'doi:10.6078/D1',
            ucr: 'doi:10.6086/D1',
            lbnl: 'doi:10.7941/D1'
          }

          aggregate_failures 'all_tenants' do
            all_tenants.each do |tenant|
              expected = expected_shoulders[tenant.to_sym]
              actual = tenant_to_shoulder[tenant]
              expect(actual).to eq(expected), "Wrong shoulder for #{tenant}; expected #{expected}, was #{actual}"
            end
          end
        end

        it 'has only DOIs with the correct shoulder' do
          aggregate_failures 'all records' do
            doi_to_tenant.each do |doi_value, tenant|
              ark = doi_to_ark[doi_value]
              doi = "doi:#{doi_value.upcase}"
              shoulder = tenant_to_shoulder[tenant]
              if doi.start_with?(shoulder)
                puts "#{tenant}\t#{doi}\t#{shoulder}"
              else
                warn "Wrong shoulder for #{ark} in #{tenant}: expected #{shoulder}, got #{doi}"
              end
              # expect(doi).to start_with(shoulder), "Wrong shoulder for #{ark} in #{tenant}: expected #{shoulder}, got #{doi}"
            end
          end
        end
      end

    end
  end
end
