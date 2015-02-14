require 'test_helper'

class ScenarioTest < ActiveSupport::TestCase

  def test_scenario_com_page

    s = YmlRecord.load_yml("scenarios-yml/strace.yml")
    s.provider_scenario_upload_com_page

    puts s.com_page

    put = Net::HTTP::Put.new(s.com_page, 'content-type' => 'text/plain')
    put.body = "finished"

    # # send the PUT request
    http = Net::HTTP.new('higgz-edurange-com.s3.amazonaws.com', 443)
    http.set_debug_output(Logger.new($stdout))
    http.use_ssl = true
    http.start
    resp = http.request(put)
    resp = [resp.code.to_i, resp.to_hash, resp.body]
    http.finish

    assert(s.uuid.is_a? String)

  end

  def test_s3
    i = Instance.new
    name = "test-" + Time.new.to_i.to_s
    i.aws_s3_create_page(name, :write, "thisistest")
    obj = AWS::S3.new.buckets[Settings.bucket_name].objects[name]
    assert obj.exists?, "s3 object creation failed"
    obj.delete
    assert !obj.exists?, "s3 object failed to delete"
  end

  def test_instance_boot
    i = Instance.new
  end

  def test_yml_headers
    @templates = YmlRecord.yml_headers.map {|filename,name,desc| [name,filename,desc]}
  end

  def test_load_yml

  end


  def test_scenario_yml

  end

  def test_write_file
    sleep 3
    File.open("findme", "a").write("second")
  end
  # handle_asynchronously :test_write_file

  def test_boot_simple_scenario

    s = YmlRecord.load_yml("test/scenarios/simple/simple.yml")
    s.delay.foome

    delay.test_write_file
    File.open("findme", "a").write("first")


    sleep 10
    # load scenario
    # s = YmlRecord.load_yml("test/scenarios/simple/simple.yml")
    # do error checking on yaml

    # do parallel boot
    # s.boot
    # puts s.name
    # puts s
    # s.save

    # puts "Waiting for scenario to bootroo"
    # until s.booted? or s.failed?
      # sleep 1
    # end

    # wait for everything to report in
    # puts s.log

    # if s.failed?

    # sleep 1 until s.booted?
    # puts "Press [enter] to unboot scenario"
    # key = nil
    # until key == "\n"
      # key = gets
    # end

    # s.purge
    # s.destroy

  end

end