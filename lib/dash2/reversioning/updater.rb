module Dash2
  module Reversioning
    class Updater
      attr_reader :doi
      attr_reader :last_merritt_version
      attr_reader :last_stash_version

      def initialize(doi:, last_merritt_version:, last_stash_version:)
        @doi = doi
        @last_merritt_version = last_merritt_version
        @last_stash_version = last_stash_version
      end

      def self.from_record(record)
        Updater.new(
          doi: record.doi,
          last_merritt_version: record.merritt_version,
          last_stash_version: record.stash_version
        )
      end

      def self.log
        Dash2::Reversioning.log
      end

      def log
        Dash2::Reversioning.log
      end

      def offset
        @offset ||= last_merritt_version - last_stash_version
      end

      def identifier
        @identifier ||= StashEngine::Identifier.find_by(identifier: doi)
      end

      def submitted_versions
        ((resources = identifier.resources) && resources.submitted) || []
      end

      def update!
        if offset.zero?
          log.info("#{doi} merritt and stash versions are identical: #{last_merritt_version}; skipping")
          return
        end

        log.info("#{doi} merritt and stash versions differ: #{last_merritt_version} vs #{last_stash_version}")
        submitted_versions.each { |v| update(v) }
      end

      def update(db_version)
        new_merritt_version = db_version.stash_version + offset
        if db_version.merritt_version == new_merritt_version
          log.info("stash_version #{db_version.id}: merritt_version is already #{new_merritt_version}; skipping")
          return
        end
        do_update(db_version, new_merritt_version)
      end

      def do_update(db_version, new_merritt_version)
        log_msg = "stash_version #{db_version.id}: updating merritt_version from #{db_version.merritt_version} to #{new_merritt_version}"
        if Dash2::Reversioning.dry_run?
          log.info("DRY RUN: #{log_msg}")
          return
        end

        log.info(log_msg)
        db_version.merritt_version = new_merritt_version
        db_version.save!
      end
    end
  end
end
