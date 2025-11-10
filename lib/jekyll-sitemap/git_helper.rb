# frozen_string_literal: true

require "pathname"
require "shellwords"
require "time"

module Jekyll
  module Sitemap
    # Helper module for retrieving git commit information
    module GitHelper
      extend self

      # Check if the current directory is part of a git repository
      # @return [Boolean] true if git is available and we're in a repo
      def git_available?
        @git_available ||= begin
          `git rev-parse --is-inside-work-tree 2>/dev/null`.strip == "true"
        rescue StandardError
          false
        end
      end

      # Get the last commit date for a specific file
      # @param file_path [String] the path to the file relative to the site source
      # @param site_source [String] the absolute path to the site source directory
      # @return [Time, nil] the date of the last commit affecting this file, or nil
      def last_commit_date(file_path, site_source)
        return nil unless git_available?

        # Get the absolute path to the file
        absolute_path = File.join(site_source, file_path)
        return nil unless File.exist?(absolute_path)

        # Get relative path from git root
        git_relative_path = get_git_relative_path(absolute_path)
        return nil if git_relative_path.nil?

        # Get the last commit date for this file
        # Need to run git log from the git root directory
        git_root = `git rev-parse --show-toplevel 2>/dev/null`.strip
        timestamp = `cd #{Shellwords.escape(git_root)} && git log -1 --format=%aI -- #{Shellwords.escape(git_relative_path)} 2>/dev/null`.strip
        return nil if timestamp.empty?

        Time.parse(timestamp)
      rescue StandardError => e
        # Log error if Jekyll is loaded, otherwise silently return nil
        if defined?(Jekyll) && defined?(Jekyll.logger)
          Jekyll.logger.debug "GitHelper:", "Error getting commit date for #{file_path}: #{e.message}"
        end
        nil
      end

      private

      # Convert an absolute file path to a path relative to the git repository root
      # @param absolute_path [String] the absolute path to the file
      # @return [String, nil] the path relative to git root, or nil on error
      def get_git_relative_path(absolute_path)
        git_root = `git rev-parse --show-toplevel 2>/dev/null`.strip
        return nil if git_root.empty?

        # Calculate relative path from git root
        Pathname.new(absolute_path).relative_path_from(Pathname.new(git_root)).to_s
      rescue StandardError => e
        # Log error if Jekyll is loaded, otherwise silently return nil
        if defined?(Jekyll) && defined?(Jekyll.logger)
          Jekyll.logger.debug "GitHelper:", "Error getting git relative path: #{e.message}"
        end
        nil
      end
    end
  end
end

