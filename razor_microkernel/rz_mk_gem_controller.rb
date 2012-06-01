#!/usr/bin/env ruby

# This class makes call to the "gem" CLI (provided by the RubyGems) to install
# all of the in the stated directory.
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
# @author Tom McSweeney

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
      puts "installing gem #{gemName}"
      gemFile = @dirName + "/"+ gemName
      %x[gem install --no-ri --no-rdoc #{gemFile}]
    end

  end
end
