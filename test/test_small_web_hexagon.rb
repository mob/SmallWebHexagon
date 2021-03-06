require 'rack/test'
require 'rspec/expectations'
require 'test/unit'
require 'erubis'
require 'fileutils'
require 'yaml'
require_relative '../src/muffinland.rb'
require_relative '../src/ml_request'
Test::Unit::TestCase.include RSpec::Matchers



def request_via_API( app, method, path, params={} ) # app should be Muffinland (hexagon API)
  request = construct_request method, path, params
  app.handle request
end

def construct_request(method, path, params={})
  env = Rack::MockRequest.env_for(path, {:method => method, :params=>params}  )
  rr = Rack::Request.new(env)
  request = Ml_RackRequest.new( rr )
end

class Hash
  # {:a=>1, :b=>2, :c=>3}.extract_per({:b=y, :c=>z}) returns {:b=>2, :c=>3}
  def slice_per( sampleHash )
    sampleHash.inject({}) { |subset, (k,v) | subset[k] = self[k] ; subset }
  end
end




class TestRequests < Test::Unit::TestCase

  def test_00_emptyDB_is_special_case
    app = Muffinland.new

    mlResponse = request_via_API( app, "GET", '/' )
    exp = {out_action:  "EmptyDB"}
    mlResponse.slice_per( exp ).should == exp

    mlResponse = request_via_API( app, "GET", '/aaa' )
    exp =  {out_action:  "EmptyDB"}
    mlResponse.slice_per( exp ).should == exp
  end

  def test_01_posts_return_contents
    app = Muffinland.new

    mlResponse = request_via_API( app, "POST", '/ignored',{ "Add"=>"Add", "MuffinContents"=>"a" } )
    exp = {
        out_action:   "GET_named_page",
        muffin_id:   0,
        muffin_body: "a"
    }
    mlResponse.slice_per( exp ).should == exp

    mlResponse = request_via_API( app, "POST", '/stillignored',{ "Add"=>"Add", "MuffinContents"=>"b" } )
    exp = {
        out_action:   "GET_named_page",
        muffin_id:   1,
        muffin_body: "b"
    }
    mlResponse.slice_per( exp ).should == exp

    mlResponse = request_via_API( app, "GET", '/0' )
    exp = {
        out_action:   "GET_named_page",
        muffin_id:   0,
        muffin_body: "a"
    }
    mlResponse.slice_per( exp ).should == exp

    mlResponse = request_via_API( app, "GET", '/1' )
    exp = {
        out_action:   "GET_named_page",
        muffin_id:   1,
        muffin_body: "b"
    }
    mlResponse.slice_per( exp ).should == exp

    mlResponse = request_via_API( app, "GET", '/2' )
    exp = {
        out_action:   "404"
    }
    mlResponse.slice_per( exp ).should == exp


  end

  def test_04_historian_adds_to_history
    app = Muffinland.new

    warehouse = []
    app.use_warehouse warehouse

    mlResponse = request_via_API( app, "GET", '/0' )
    exp = {
        out_action:   "EmptyDB"
    }
    mlResponse.slice_per( exp ).should == exp
    warehouse.should be_empty



    mlResponse = request_via_API( app, "POST", '/ignored',{ "Add"=>"Add", "MuffinContents"=>"a" } )
    warehouse.should_not be_empty
  end

  def test_05_adding_warehouse_loads_muffins
    app = Muffinland.new

    request = construct_request('POST', '/ignored',{ "Add"=>"Add", "MuffinContents"=>"apple" })

    warehouse = [request]
    app.use_warehouse warehouse

    mlResponse = request_via_API( app, "GET", '/0' )
    exp = {
        out_action:   "GET_named_page",
        muffin_id:   0,
        muffin_body: "apple"
    }
    mlResponse.slice_per( exp ).should == exp

    request2 = construct_request("POST", '/ignored',{ "Add"=>"Add", "MuffinContents"=>"banana" } )
    app.handle request2
    warehouse[1].should == request2

    mlResponse2 = request_via_API( app, "GET", '/1' )
    exp2 = {
        out_action:   "GET_named_page",
        muffin_id:   1,
        muffin_body: "banana"
    }
    mlResponse2.slice_per( exp2 ).should == exp2
  end

  def test_06_files_can_be_warehouses
    return

    app = Muffinland.new

    request = construct_request('POST', '/ignored',{ "Add"=>"Add", "MuffinContents"=>"apple" })

#    p request
#    puts Marshal.dump(request)

    FileUtils.rm('warehouse.txt') if File.file?('warehouse.txt')
    File.open('warehouse.txt', 'w') do |f|
      f << YAML.dump(request)
    end
    warehouse = File.open('warehouse.txt')

    warehouse.should_not be_nil

    warehouse.extend FileWarehouse

    app.use_warehouse warehouse

    mlResponse = request_via_API( app, "GET", '/0' )
    exp = {
        out_action:   "GET_named_page",
        muffin_id:   0,
        muffin_body: "apple"
    }
    mlResponse.slice_per( exp ).should == exp
  end  

#=================================================


end

module FileWarehouse
  def each(&block)
    lines = readlines.map(&:strip).reject {|l| l.empty? }
    lines.each {|l| block.call(YAML.load(l)) }
  end

  def size
  end

  def <<(o)
  end
end

# class StringIO
#   def _dump(level)
#     read
#   end
# 
#   def self._load(stuff)
#     puts "***"
#     p stuff
#     new stuff
#   end
# end
