class S3bucket
  require 'set'
  
  include MongoMapper::Document     
  
  key :name, String
  key :prefixes, Array

  TMP_DIR_PREFIX = "/tmp/myopicvicar/"
  
  def directories
    # return the cached version
   return self.prefixes if self.prefixes && self.prefixes.size > 0
    
    # get the bucket
    c = Fog::Storage.new(:provider => 'AWS')
    
    set = Set.new

    # cycle through each key
    c.directories.get(self.name).files.all.each do |f|
      # add the stem to the set
      dir = File.dirname(f.key)
      set.add(dir)
    end
    # save the items
    self.prefixes = set.to_a
    # save the whole thing
    save!
    self.prefixes
  end
  
  def ls(dir)
    return nil unless directories.include?(dir)
    dir = dir + '/' unless dir.ends_with?('/')
    c = Fog::Storage.new(:provider => 'AWS')
    c.directories.get(self.name).files.all(:prefix => dir, :delimiter => '/')

  end
  
  
  def flush_to_slash_tmp(dir) 
    
    files = ls(dir)
    files.each do |s3_file|
      FileUtils.mkdir_p(File.dirname(key_to_file(s3_file.key)))
      File.open(key_to_file(s3_file.key), 'w+') do |local_file|
        local_file.write(s3_file.body)
      end 
    end
    
  end
  
  private
  
  def key_to_file(key)
    File.join(TMP_DIR_PREFIX, self.name, key)
  end
  
  def self.dir_from_key(key) 
    File.join(File.dirname(key), '')
  end
  
end
