require File.dirname(__FILE__) + '/spec_helper'

require "open-uri"
require "sqlite3"

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

describe "Upload" do
  def setup_db
    ActiveRecord::Schema.define(:version => 1) do
      create_table :photos do |t|
        t.column :image, :string
      end
    end
  end

  def drop_db
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
  end

  class PhotoUploader < CarrierWave::Uploader::Base
    include CarrierWave::MiniMagick

    version :small do
      process :resize_to_fill => [120, 120]
    end

    def store_dir
      "photos"
    end
  end

  class Photo < ActiveRecord::Base
    mount_uploader :image, PhotoUploader
  end


  before :all do
    setup_db
  end

  after :all do
    drop_db
  end

  context "Upload Image" do
    it "does upload image" do
      f = load_file("foo.jpg")
      puts Benchmark.measure {
        @photo = Photo.create(:image => f)
      }
      @photo.errors.count.should == 0
      open(@photo.image.url).should_not == nil
      open(@photo.image.url).size.should == f.size
      open(@photo.image.small.url).should_not == nil
    end
  end

  context "Connection" do
    it "create shared connection" do
      expect {
        CarrierWave::Storage::UpYun::Connection.find_or_initialize 'bucket0', :upyun_username => "foo"
        CarrierWave::Storage::UpYun::Connection.find_or_initialize 'bucket0', :upyun_username => "foo"
        CarrierWave::Storage::UpYun::Connection.find_or_initialize 'bucket1', :upyun_username => "foo"
      }.to change{ CarrierWave::Storage::UpYun::Connection.shared_connections.size }.by(2)
    end

    it "create only one instance for same buckets" do
      CarrierWave::Storage::UpYun::Connection.find_or_initialize 'bucket999', :upyun_username => "foo"
      CarrierWave::Storage::UpYun::Connection.find_or_initialize 'bucket999', :upyun_username => "foo"
      instances = []
      ObjectSpace.each_object(CarrierWave::Storage::UpYun::Connection) do |conn|
        instances << conn if conn.upyun_bucket == 'bucket999'
      end
      instances.should have(1).item
    end
  end
end
