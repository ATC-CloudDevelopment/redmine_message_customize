class CustomMessageSettingsController < ApplicationController
  layout 'admin'
  before_action :require_admin, :set_custom_message_setting, :set_lang
  require_sudo_mode :edit, :update, :toggle_enabled, :default_messages

  def edit
  end

  def default_messages
    @file_path = Rails.root.join('config', 'locales', "#{@lang}.yml")
  end

  def update
    languages = @setting.using_languages

    if setting_params.key?(:custom_messages) || params[:tab] == 'normal'
      @setting.update_with_custom_messages(setting_params[:custom_messages].try(:to_unsafe_h).try(:to_hash) || {}, @lang)
    elsif setting_params.key?(:custom_messages_yaml)
      @setting.update_with_custom_messages_yaml(setting_params[:custom_messages_yaml])
    end

    if @setting.errors.blank?
      flash[:notice] = l(:notice_successful_update)
      languages += @setting.using_languages
      CustomMessageSetting.reload_translations!(languages)

      redirect_to edit_custom_message_settings_path(tab: params[:tab], lang: @lang)
    else
      render :edit
    end
  end

  def toggle_enabled
    if @setting.toggle_enabled!
      flash[:notice] =
        @setting.enabled? ? l(:notice_enabled_customize) : l(:notice_disabled_customize)
      redirect_to edit_custom_message_settings_path
    else
      render :edit
    end
  end

  private
  def set_custom_message_setting
    @setting = CustomMessageSetting.find_or_default
  end

  def setting_params
    params.fetch(:settings, {})
  end

  def set_lang
    @lang = CustomMessageSetting.find_language(params[:lang].presence || User.current.language.presence || 'en')
  end
end