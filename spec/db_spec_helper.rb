require 'spec_helper'

logfile = File.expand_path('log/test.log')
FileUtils.mkdir_p File.dirname(logfile)
ActiveRecord::Base.logger = Logger.new(logfile) if defined?(ActiveRecord::Base)

db_config = YAML.load_file('config/database.yml')['test']
ActiveRecord::Base.establish_connection(db_config)
ActiveRecord::Migration.verbose = false
ActiveRecord::Migrator.up 'db/migrate'

RSpec.configure do |config|
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
