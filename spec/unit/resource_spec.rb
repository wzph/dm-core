require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

# rSpec completely FUBARs everything if you give it a Module here.
# So we give it a String of the module name instead.
# DO NOT CHANGE THIS!
describe "DataMapper::Resource" do

  before(:all) do

    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]
    DataMapper.setup(:legacy, "mock://localhost/mock") unless DataMapper::Repository.adapters[:legacy]

    unless DataMapper::Repository.adapters[:yet_another_repository]
      adapter = DataMapper.setup(:yet_another_repository, "mock://localhost/mock")
      adapter.resource_naming_convention = DataMapper::NamingConventions::Underscored
    end

    class Planet

      include DataMapper::Resource

      resource_names[:legacy] = "dying_planets"

      property :id, Fixnum, :key => true
      property :name, String, :lock => true
      property :age, Fixnum
      property :core, String, :private => true

      # An example of how to scope a property to a specific repository.
      # Un-specced currently.
      # repository(:legacy) do
      #   property :name, String
      # end
    end
  end

  it "should return an instance of the created object" do
    Planet.create(:name => 'Venus', :age => 1_000_000, :core => nil, :id => 42).should be_a_kind_of(Planet)
  end

  it "should provide persistance methods" do
    Planet.should respond_to(:get)
    Planet.should respond_to(:first)
    Planet.should respond_to(:all)
    Planet.should respond_to(:[])

    planet = Planet.new
    planet.should respond_to(:new_record?)
    planet.should respond_to(:save)
    planet.should respond_to(:destroy)
  end

  it "should provide a resource_name" do
    Planet.should respond_to(:resource_name)
    Planet.resource_name(:default).should == 'planets'
    Planet.resource_name(:legacy).should == 'dying_planets'
    Planet.resource_name(:yet_another_repository).should == 'planet'
  end

  it "should provide properties" do
    Planet.properties(:default).should have(4).entries
  end

  it "should provide mapping defaults" do
    Planet.properties(:yet_another_repository).should have(4).entries
  end

  it "should have attributes" do
    attributes = { :name => 'Jupiter', :age => 1_000_000, :core => nil, :id => 42 }
    jupiter = Planet.new(attributes)
    jupiter.attributes.should == attributes
  end

  it "should be able to set attributes (including private attributes)" do
    attributes = { :name => 'Jupiter', :age => 1_000_000, :core => nil, :id => 42 }
    jupiter = Planet.new(attributes)
    jupiter.attributes.should == attributes
    jupiter.attributes = attributes.merge({ :core => 'Magma' })
    jupiter.attributes.should == attributes
    jupiter.send(:private_attributes=, attributes.merge({ :core => 'Magma' }))
    jupiter.attributes.should == attributes.merge({ :core => 'Magma' })
  end

  it "should provide a repository" do
    Planet.repository.name.should == :default
  end

  it "should track attributes" do

    # So attribute tracking is a feature of the Resource,
    # not the Property. Properties are class-level declarations.
    # Instance-level operations like this happen in Resource with methods
    # and ivars it sets up. Like a @dirty_attributes Array for example to
    # track dirty attributes.

    mars = Planet.new :name => 'Mars'
    # #attribute_loaded? and #attribute_dirty? are a bit verbose,
    # but I like the consistency and grouping of the methods.

    # initialize-set values are dirty as well. DM sets ivars
    # directly when materializing, so an ivar won't exist
    # if the value wasn't loaded by DM initially. Touching that
    # ivar at all will declare it, so at that point it's loaded.
    # This means #attribute_loaded?'s implementation could be very
    # similar (if not identical) to:
    #   def attribute_loaded?(name)
    #     instance_variable_defined?("@#{name}")
    #   end
    mars.attribute_loaded?(:name).should be_true
    mars.attribute_dirty?(:name).should be_true
    mars.attribute_loaded?(:age).should be_false

    mars.age.should be_nil

    # So accessing a value should ensure it's loaded.
# XXX: why?  if the @ivar isn't set, which it wouldn't be in this
# case because mars is a new_record?, then perhaps it should return
# false
#    mars.attribute_loaded?(:age).should be_true

    # A value should be able to be both loaded and nil.
    mars[:age].should be_nil

    # Unless you call #[]= it's not dirty.
    mars.attribute_dirty?(:age).should be_false

    mars[:age] = 30
    # Obviously. :-)
    mars.attribute_dirty?(:age).should be_true

    mars.should respond_to(:shadow_attribute_get)
  end

  it 'should return the dirty attributes' do
    pluto = Planet.new(:name => 'Pluto', :age => 500_000)
    pluto.attribute_dirty?(:name).should be_true
    pluto.attribute_dirty?(:age).should be_true
  end

  it 'should provide a key' do
    Planet.new.should respond_to(:key)
  end

  it 'should temporarily store original values for locked attributes' do
    mars = Planet.new
    mars.instance_variable_set('@name', 'Mars')
    mars.instance_variable_set('@new_record', false)

    mars[:name] = 'God of War'
    mars[:name].should == 'God of War'
    mars.name.should == 'God of War'
    mars.shadow_attribute_get(:name).should == 'Mars'
  end

  it 'should add hook functionality to including class' do
    Planet.should respond_to(:before)
    Planet.should respond_to(:after)
  end

  describe 'when retrieving by key' do
    it 'should return the corresponding object' do
      m = mock("planet")
      Planet.should_receive(:get).with(1).and_return(m)

      Planet[1].should == m
    end

    it 'should raise an error if not found' do
      Planet.should_receive(:get).and_return(nil)

      lambda do
        Planet[1]
      end.should raise_error(DataMapper::ObjectNotFoundError)
    end
  end
end