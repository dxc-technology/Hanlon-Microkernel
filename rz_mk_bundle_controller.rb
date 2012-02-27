#!/usr/bin/env ruby

# This class makes call to the "bundle" CLI (provided by the bundler RubyGem) to install
# bundles in the stated directory.
#
# @author Tom McSweeney

class RzMkBundleController

  attr_reader :dirName, :listFileName, :gemFile

  def initialize(dirName, listFileName="bundle.list", gemFile = "Gemfile")
    @dirName = dirName
    @listFileName = listFileName
    @gemFile = gemFile
  end

  def installAllBundles()
    fileName = @dirName + "/"+ @listFileName
    File.open(fileName, 'r').each { |bundleNameFromFile|
      installBundle(bundleNameFromFile.chomp)
    }
  end

  def installBundle(bundleName)
    puts "installing bundle #{bundleName}"
    bundleGemFile = @dirName + "/"+ bundleName + '/'  + @gemFile
    %x[bundle install --local --gemfile #{bundleGemFile}]
  end

end
