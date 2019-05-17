class CustomMessageSetting < Setting
  validate :add_errors, :convertible_to_yaml,
           :custom_message_languages_are_available, :custom_message_keys_are_available

  def self.find_or_default
    super('plugin_redmine_message_customize')
  end

  def custom_messages(lang=nil)
    messages = self.value[:custom_messages] || self.value['custom_messages']
    if lang.present?
      messages = messages[self.class.find_language(lang)]
    end

    messages.present? ? messages : {}
  end

  def custom_messages_to_flatten_hash(lang=nil)
    self.class.flatten_hash(custom_messages(lang))
  end

  def custom_messages_to_yaml
    messages = self.custom_messages
    if messages.blank?
      ''
    elsif messages.is_a?(Hash)
      YAML.dump(messages)
    else
      messages
    end
  end

  def update_with_custom_messages(custom_messages, lang)
    value = CustomMessageSetting.nested_hash(custom_messages)
    original_custom_messages = self.custom_messages
    messages =
      if value.present?
        original_custom_messages.merge({lang => value})
      else
        original_custom_messages.delete(lang)
        original_custom_messages
      end

    self.value = {custom_messages: (messages.present? ? messages : {})}
    self.save
  end

  def update_with_custom_messages_yaml(yaml)
    begin
      messages = YAML.load(yaml)
      @errs = {base: l(:error_invalid_yaml_format) } if messages.is_a?(Hash) == false && messages.present?
      self.value = {custom_messages: (messages.present? ? messages : {})}
    rescue => e
      @errs = {base: e.message}
      self.value = {custom_messages: yaml}
    end
    self.save
  end

  def self.available_messages(lang)
    messages = I18n.backend.translations[self.find_language(lang).to_sym]
    if messages.nil?
      CustomMessageSetting.reload_translations!([lang])
      messages = I18n.backend.translations[lang.to_sym] || {}
    end
    self.flatten_hash(messages)
  end

  # { date: { formats: { defaults: '%m/%d/%Y'}}} to {'date.formats.defaults' => '%m/%d/%Y'}
  def self.flatten_hash(hash=nil)
    hash = self.to_hash unless hash
    hash.each_with_object({}) do |(key, value), content|
      next self.flatten_hash(value).each do |k, v|
        content["#{key}.#{k}".intern] = v
      end if value.is_a? Hash
      content[key] = value
    end
  end

  # {'date.formats.defaults' => '%m/%d/%Y'} to { date: { formats: { defaults: '%m/%d/%Y'}}}
  def self.nested_hash(hash=nil)
    new_hash = {}
    hash.each do |key, value|
      h = value
      h = YAML.load(value) if value.first == '[' && value.last == ']'
      key.to_s.split('.').reverse_each do |k|
        h = {k => h}
      end
      new_hash = new_hash.deep_merge(h)
    end
    new_hash
  end

  def self.reload_translations!(languages)
    paths = ::I18n.load_path.select {|path| self.find_language(languages).include?(File.basename(path, '.*').to_s)}
    I18n.backend.load_translations(paths)
  end

  def self.find_language(language=nil)
    if language.is_a?(Array)
      language.select{|l| I18n.available_locales.include?(l.to_s.to_sym)}.map(&:to_s).compact
    elsif language.present? && I18n.available_locales.include?(language.to_s.to_sym)
      language.to_s
    else
      nil
    end
  end

  private

  def custom_message_keys_are_available
    return false if self.value[:custom_messages].is_a?(Hash) == false || self.errors.present?

    custom_messages_hash = {}
    custom_messages.values.compact.each do |val|
      custom_messages_hash = self.class.flatten_hash(custom_messages_hash.merge(val)) if val.is_a?(Hash)
    end
    available_keys = self.class.flatten_hash(self.class.available_messages('en')).keys
    unavailable_keys = custom_messages_hash.keys.reject{|k| available_keys.include?(k.to_sym)}
    if unavailable_keys.present?
      self.errors.add(:base, l(:error_unavailable_keys) + " keys: [#{unavailable_keys.join(', ')}]")
      false
    end
  end

  def custom_message_languages_are_available
    return false if self.value[:custom_messages].is_a?(Hash) == false || self.errors.present?
    unavailable_languages =
      custom_messages.keys.compact.reject do |language|
        I18n.available_locales.include?(language.to_sym)
      end
    if unavailable_languages.present?
      self.errors.add(:base, l(:error_unavailable_languages) + " [#{unavailable_languages.join(', ')}]")
      false
    end
  end

  def convertible_to_yaml
    YAML.dump(self.value[:custom_messages])
  end

  def add_errors
    if @errs.present?
      @errs.each do |key, value|
        self.errors.add(key, value)
      end
      @errs = nil
      false
    end
  end
end