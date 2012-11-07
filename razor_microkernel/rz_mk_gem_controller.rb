#!/usr/bin/env ruby

# This class makes call to the "gem" CLI (provided by the RubyGems) to install
# all of the in the stated directory.
#
#

module RazorMicrokernel
  class RzMkGemController

    attr_reader :dirName, :listFileName

    def initialize(dirName, listFileName="gem.list")
      @dirName = dirName
      @listFileName = listFileName
    end

    def installAllGems()
      fileName = @dirName + "/"+ @listFileName
      File.open(fileName, 'r').each { |gemNameFromFile|
        installGem(gemNameFromFile.chomp)
      }
    end

    def installGem(gemName)
      # Can install from the gem mirror now, no need for absolute path
      puts "installing gem #{gemName}"
      %x[gem install --no-ri --no-rdoc #{gemName}]
    end

  end
end
