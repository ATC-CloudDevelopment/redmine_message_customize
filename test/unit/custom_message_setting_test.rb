require File.dirname(__FILE__) + '/../test_helper'

class CustomMessageSettingTest < ActiveSupport::TestCase
  fixtures :custom_message_settings
  include Redmine::I18n

  def setup
    @custom_message_setting = CustomMessageSetting.find(1)
    MessageCustomize::Locale.reload!('en')
    I18n.load_path = (I18n.load_path + Dir.glob(Rails.root.join('plugins', 'redmine_message_customize', 'config', 'locales', 'custom_messages', '*.rb'))).uniq
  end

  def test_validate_with_unused_keys_should_invalid
    @custom_message_setting.value = { custom_messages: { 'en' => {'foo' => 'bar' }} }
    assert_not @custom_message_setting.valid?
    assert_equal "#{l(:error_unused_keys)} keys: [foo]", @custom_message_setting.errors[:base].first
  end

  def test_validate_with_unusable_type_of_keys_should_invalid
    @custom_message_setting.value = { custom_messages: { 'en' => {'date' => {'order' => 'foobar' }}} }
    assert_not @custom_message_setting.valid?
    assert_equal "#{l(:error_unusable_type_of_keys)} keys: [date.order]", @custom_message_setting.errors[:base].first
  end

  def test_validate_with_not_available_languages_should_invalid
    @custom_message_setting.value = { custom_messages: { 'foo' => {'label_home' => 'Home' }} }
    assert_not @custom_message_setting.valid?
    assert_equal "#{l(:error_unavailable_languages)} [foo]", @custom_message_setting.errors[:base].first
  end

  def test_validate_with_invalid_yaml_should_invalid
    @custom_message_setting.value = { custom_messages: "---\nen:\n  label_home: Home3\ninvalid-string" }
    assert_not @custom_message_setting.valid?
    assert_equal "(<unknown>): could not find expected ':' while scanning a simple key at line 4 column 1", @custom_message_setting.errors[:base].first
  end

  def test_find_or_default
    assert_equal @custom_message_setting, CustomMessageSetting.find_or_default
  end

  def test_enabled?
    @custom_message_setting.value = { enabled: 'true' }
    assert @custom_message_setting.enabled?

    @custom_message_setting.value = { enabled: 'false' }
    assert_not @custom_message_setting.enabled?

    @custom_message_setting.value = { enabled: nil }
    assert @custom_message_setting.enabled?
  end

  def test_custom_messages
    assert_equal @custom_message_setting.value['custom_messages'], @custom_message_setting.custom_messages
    assert_equal ({'label_home' => 'Home1'}), @custom_message_setting.custom_messages('en')
    assert_equal ({}), @custom_message_setting.custom_messages('foo')
  end

  def test_custom_messages_with_check_enabled
    assert @custom_message_setting.enabled?
    assert_equal ({'label_home' => 'Home1'}), @custom_message_setting.custom_messages('en', true)
    assert_equal ({'label_home' => 'Home1'}), @custom_message_setting.custom_messages('en', false)

    @custom_message_setting.toggle_enabled!
    assert_not @custom_message_setting.enabled?
    assert_equal ({}), @custom_message_setting.custom_messages('en', true)
    assert_equal ({'label_home' => 'Home1'}), @custom_message_setting.custom_messages('en', false)
  end

  def test_custom_messages_to_yaml
    assert_equal "---\nen:\n  label_home: Home1\nja:\n  label_home: Home2\n", @custom_message_setting.custom_messages_to_yaml

    @custom_message_setting.value = { custom_messages: {} }
    assert_equal '', @custom_message_setting.custom_messages_to_yaml

    @custom_message_setting.value = { custom_messages: 'test' }
    assert_equal 'test', @custom_message_setting.custom_messages_to_yaml
  end

  def test_update_with_custom_messages_if_custom_messages_is_exist
    flatten_hash = {'label_home' => 'Home3', 'time.am' => 'foo'}

    assert @custom_message_setting.update_with_custom_messages(flatten_hash, 'en')
    assert_equal ({'label_home' => 'Home3', 'time' => { 'am' => 'foo'}}), @custom_message_setting.custom_messages('en')
  end
  def test_update_with_custom_messages_if_custom_messages_is_blank
    assert @custom_message_setting.update_with_custom_messages({}, 'en')
    assert_not @custom_message_setting.custom_messages.key('en')
  end

  def test_update_with_custom_messages_yaml_if_yaml_is_valid
    yaml = "---\nen:\n  label_home: Home3"
    assert @custom_message_setting.update_with_custom_messages_yaml(yaml)
    assert_equal ({ 'label_home' => 'Home3' }), @custom_message_setting.custom_messages('en')
  end

  def test_toggle_enabled!
    assert @custom_message_setting.enabled?
    assert_equal 'Home1', l(:label_home)

    @custom_message_setting.toggle_enabled!
    assert_not @custom_message_setting.enabled?
    assert_equal 'Home', l(:label_home)

    @custom_message_setting.toggle_enabled!
    assert @custom_message_setting.enabled?
    assert_equal 'Home1', l(:label_home)
  end

  def test_using_languages
    assert_equal ['en', 'ja'], @custom_message_setting.using_languages
  end

  def test_flatten_hash_should_return_hash_with_flat_keys
    flatten_hash = CustomMessageSetting.flatten_hash({time: {am: 'foo'}})
    assert_equal ({:'time.am' => 'foo'}), flatten_hash
  end

  def test_flatten_hash_should_return_nest_hash
    nested_hash = CustomMessageSetting.nested_hash({:'time.am' => 'foo'})
    assert_equal ({'time' => {'am' => 'foo'}}), nested_hash
  end
end
