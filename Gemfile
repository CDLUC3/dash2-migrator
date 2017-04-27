source 'https://rubygems.org'

gem 'nokogiri', '1.6.7.2'
gem 'rest-client', '2.0.0'
gem 'mysql2', '~> 0.3'

gem 'config-factory', '~> 0.0', '>= 0.0.9'
gem 'datacite-mapping', '~> 0.2', '>= 0.2.4'
gem 'xml-mapping_extensions', '~> 0.4', '>= 0.4.6'

gem 'simple-rss', '~> 1.3'

path '../stash' do
  gem 'stash-harvester'
  gem 'stash-merritt'
  gem 'stash-sword'
  gem 'stash-wrapper'
  gem 'stash_datacite'
  gem 'stash_engine'
end

# Development

gem 'rubocop', '~> 0.42', group: :development

# Test

group :test do
  gem 'diffy', '~> 3.1'
  gem 'equivalent-xml', '~> 0.6.0'
  gem 'database_cleaner', '~> 1.5'
  gem 'rspec', '~> 3.5'
  gem 'rspec-rails', '~> 3.5'
  gem 'simplecov', '~> 0.12'
  gem 'simplecov-console', '~> 0.3.0'
  gem 'webmock', '~> 1.24'
end
