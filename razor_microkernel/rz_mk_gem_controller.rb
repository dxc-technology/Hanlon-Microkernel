#!/usr/bin/env ruby

# This class makes call to the "gem" CLI (provided by the RubyGems) to install
# all of the in the stated directory.
#
#

require 'net/http'
require 'singleton'

module RazorMicrokernel
  class RzMkGemController
    # make this class a singleton class (only want one)
    include Singleton

    GEM_LIST_PARSE_EXPR = /^(\S*)\s*\((.*)\)$/

    def gemSource=(gemSource)
      @gemSource = gemSource
      # get the map of gem versions available from this source (by gem name)
      @gemVersions = getRemoteGemList
      # and save a copy of those names for later use
      @gemNames = @gemVersions.keys
    end

    def gemListURI=(gemListURI)
      @gemListURI = gemListURI
    end

    def getRemoteGemList
      output = %x[gem list --clear-sources --source #{@gemSource} --remote]
      gem_version_map = {}
      output.split("\n").each { |line|
        parsed_line = GEM_LIST_PARSE_EXPR.match(line)
        gem_version_map[parsed_line[1]] = parsed_line[2].split(", ")
      }
      gem_version_map
    end

    def getLocalVersions(gemName)
      line = %x[gem list --local --versions #{gemName}]
      name_versions_match = GEM_LIST_PARSE_EXPR.match(line)
      return nil unless name_versions_match
      name_versions_match[2].split(", ")
    end

    # installs a "new" version of a gem locally from the current @gemSource
    # (Note; the gem is only installed if it hasn't been installed yet on the
    # local system or if this version of the gem has not been installed yet)
    def addToInstalledGems(gemName)
      # if the named gem is not available from the named mirror, then print out
      # a warning and return without trying to install this gem
      unless @gemNames.include?(gemName)
        puts "WARNING; gem '#{gemName}' is not available from the named mirror (#{@gemSource})"
        return
      end
      # otherwise, determine the most recent version available from the @gemSource mirror
      # (this is the version that will be installed)
      newVersion = @gemVersions[gemName][0]
      # next, get a list of the locally installed version(s) for the named gem (if any)
      version_array = getLocalVersions(gemName)
      # and check to see if the "newVersion" of this gem has already been
      # installed locally; if so just return (nothing to do here...move along)
      return if version_array && version_array.include?(newVersion)
      # otherwise the gem is either not installed locally or the latest version of that gem
      # available from the @gemSource is not installed locally, so install it
      installGem(gemName, newVersion)
    end

    def installListedGems
      uri = URI(@gemListURI)
      begin
        response = Net::HTTP.get_response(uri)
        case response
          when Net::HTTPSuccess
          response.body.split.each { |gemNameFromFile|
            gemName = gemNameFromFile.chomp
            addToInstalledGems(gemName)
          }
        else
          puts response.body
        end
      rescue Exception => e
        # catches errors that might occur when trying to retrieve the list
        # of gems to install from the gemSource
        puts e.message
        e.backtrace.each { |line| puts line }
      end
    end

    def installGem(gemName, newVersion)
      # Can install from the gem mirror now, no need for absolute path
      puts "installing gem #{gemName} (#{newVersion})"
      %x[gem install --no-ri --no-rdoc #{gemName} --source #{@gemSource} --version #{newVersion}]
    end

  end
end
