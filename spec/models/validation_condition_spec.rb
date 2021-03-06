require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ValidationCondition do
  before(:each) do
    @validation_condition = FactoryBot.create(:validation_condition)
  end

  it "should be valid" do
     @validation_condition.should be_valid
  end
  # this causes issues with building and saving
  # it "should be invalid without a parent validation_id" do
  #   @validation_condition.validation_id = nil
  #   @validation_condition.should have(1).errors_on(:validation_id)
  # end

  it "should be invalid without an operator" do
    @validation_condition.operator = nil
    #@validation_condition.should have(2).errors_on(:operator)
    @validation_condition.valid?
    expect(@validation_condition.errors[:operator].count).to eq(2)
  end

  it "should be invalid without a rule_key" do
    @validation_condition.should be_valid
    @validation_condition.rule_key = nil
    @validation_condition.should_not be_valid
    #@validation_condition.should have(1).errors_on(:rule_key)
    @validation_condition.valid?
    expect(@validation_condition.errors[:rule_key].count).to eq(1)
  end

  it "should have unique rule_key within the context of a validation" do
   @validation_condition.should be_valid
   FactoryBot.create(:validation_condition, :validation_id => 2, :rule_key => "2")
   @validation_condition.rule_key = "2" #rule key uniquness is scoped by validation_id
   @validation_condition.validation_id = 2
   @validation_condition.should_not be_valid
   @validation_condition.valid?
   #@validation_condition.should have(1).errors_on(:rule_key)
   expect(@validation_condition.errors[:rule_key].count).to eq(1)
  end

  it "should have an operator in Surveyor::Common::OPERATORS" do
    Surveyor::Common::OPERATORS.each do |o|
      @validation_condition.operator = o
      @validation_condition.valid?
      expect(@validation_condition.errors[:operator].count).to eq(0)
      #@validation_condition.should have(0).errors_on(:operator)
    end
    @validation_condition.operator = "#"
    #@validation_condition.should have(1).error_on(:operator)
    @validation_condition.valid?
    expect(@validation_condition.errors[:operator].count).to eq(1)
  end
end

describe ValidationCondition, "validating responses" do
  def test_var(vhash, ahash, rhash)
    v = FactoryBot.create(:validation_condition, vhash)
    a = FactoryBot.create(:answer, ahash)
    r = FactoryBot.create(:response, {:answer => a, :question => a.question}.merge(rhash))
    return v.is_valid?(r)
  end

  it "should validate a response by regexp" do
    test_var({:operator => "=~", :regexp => /^[a-z]{1,6}$/.to_s},
             {:response_class => "string"},
             {:string_value => "clear"}).should be_truthy
    test_var({:operator => "=~", :regexp => /^[a-z]{1,6}$/.to_s}, {:response_class => "string"}, {:string_value => "foobarbaz"}).should be_falsey
  end
  it "should validate a response by integer comparison" do
    test_var({:operator => ">", :integer_value => 3}, {:response_class => "integer"}, {:integer_value => 4}).should be_truthy
    test_var({:operator => "<=", :integer_value => 256}, {:response_class => "integer"}, {:integer_value => 512}).should be_falsey
  end
  it "should validate a response by (in)equality" do
    test_var({:operator => "!=", :datetime_value => Date.today + 1}, {:response_class => "date"}, {:datetime_value => Date.today}).should be_truthy
    test_var({:operator => "==", :string_value => "foo"}, {:response_class => "string"}, {:string_value => "foo"}).should be_truthy
  end
  it "should represent itself as a hash" do
    @v = FactoryBot.create(:validation_condition, :rule_key => "A")
    @v.stub(:is_valid?).and_return(true)
    @v.to_hash("foo").should == {:A => true}
    @v.stub(:is_valid?).and_return(false)
    @v.to_hash("foo").should == {:A => false}
  end
end

describe ValidationCondition, "validating responses by other responses" do
  def test_var(v_hash, a_hash, r_hash, ca_hash={}, cr_hash={})
    ca = FactoryBot.create(:answer, ca_hash)
    cr = FactoryBot.create(:response, cr_hash.merge(:answer => ca, :question => ca.question))
    v = FactoryBot.create(:validation_condition, v_hash.merge({:question_id => ca.question.id, :answer_id => ca.id}))
    a = FactoryBot.create(:answer, a_hash)
    r = FactoryBot.create(:response, r_hash.merge(:answer => a, :question => a.question))
    return v.is_valid?(r)
  end
  it "should validate a response by integer comparison" do
    test_var({:operator => ">"}, {:response_class => "integer"}, {:integer_value => 4}, {:response_class => "integer"}, {:integer_value => 3}).should be_truthy
    test_var({:operator => "<="}, {:response_class => "integer"}, {:integer_value => 512}, {:response_class => "integer"}, {:integer_value => 4}).should be_falsey
  end
  it "should validate a response by (in)equality" do
    test_var({:operator => "!="}, {:response_class => "date"}, {:datetime_value => Date.today}, {:response_class => "date"}, {:datetime_value => Date.today + 1}).should be_truthy
    test_var({:operator => "=="}, {:response_class => "string"}, {:string_value => "donuts"}, {:response_class => "string"}, {:string_value => "donuts"}).should be_truthy
  end
  it "should not validate a response by regexp" do
    test_var({:operator => "=~"}, {:response_class => "date"}, {:datetime_value => Date.today}, {:response_class => "date"}, {:datetime_value => Date.today + 1}).should be_falsey
    test_var({:operator => "=~"}, {:response_class => "string"}, {:string_value => "donuts"}, {:response_class => "string"}, {:string_value => "donuts"}).should be_falsey
  end
end
