class InputValidator
  attr_reader :model

  def initialize(attrs_to_manage)
    @attrs_to_manage = attrs_to_manage.merge({:strip => :all})
  end

  def before_validation(model)
    @model = model
    strip_attributes(@attrs_to_manage[:strip]) if @attrs_to_manage[:strip]
    normalize_phone_numbers(@attrs_to_manage[:phone_number]) if @attrs_to_manage[:phone_number]
  end

  def validate(model)
    @model = model
    check_email_formats(@attrs_to_manage[:email_format]) if @attrs_to_manage[:email_format]
    check_phone_numbers(@attrs_to_manage[:phone_number]) if @attrs_to_manage[:phone_number]
    check_against_bad_word_list(@attrs_to_manage[:bad_words]) if @attrs_to_manage[:bad_words]
  end


  def self.strip_value(value)
    value.strip
  end

  def self.normalize_phone_number_value(value)
    value.gsub(/\D/, '')
  end

  def self.check_email_format_value(value)
    return :invalid unless value.blank? || value.to_s =~ /\A[\w-]+(\.[\w-]+)*@([\w-]+(\.[\w-]+)*?\.[a-zA-Z]{2,6}|(\d{1,3}\.){3}\d{1,3})(:\d{4})?\Z/
  end

  def self.check_phone_number_value(value)
    ## Nil and empty values will need to be validated on the actual model.
    return nil if value.nil? || value.empty?

    check = []

    ## These two validations can be used as validates_numericality_of and validates_length_of,
    ## but this allows it to always be used for phone numbers.
    check << :not_a_number unless value.to_s =~ /\A[+-]?\d+\Z/
    check << :wrong_length unless value.to_s.size == 10

    ## Validate phony phone numbers; no real phone number should have these variations.
    check << :invalid if (
      value.to_s =~ /\A(1{3}|2{3}|3{3}|4{3}|5{3}|6{3}|7{3}|8{3}|9{3}|0{3}|123|911)/ ||
      value.to_s =~ /\A.{3}(5{3}|0{3}|012|123|911)/ ||
      value.to_s =~ /(1{7}|2{7}|3{7}|4{7}|5{7}|6{7}|7{7}|8{7}|9{7}|0{7}|1234567|3456789|4567890)\Z/
    )

    return check unless check.empty?
  end

  def self.check_bad_word(value)
    if value
      check = false
      for bw in bad_word_list
        check = true if value.match(Regexp.new('\b' + bw + '\b', Regexp::IGNORECASE))
      end
      return :invalid if check
    end
  end




  private

    ## Strip the whitespace off of the given attributes before validation is performed.
    def strip_attributes(attrs_to_check)
      attrs_to_check = model.attribute_names if @attrs_to_manage[:strip] == :all

      attrs_to_check.each do |attribute|
        value = strip_attribute(attribute)
        model[attribute] = value if value
      end
    end

    def strip_attribute(attribute)
      value = get_attr_value(attribute)
      return self.class.strip_value(value) if value && value.class == String
    end

    ## Remove all characters that are not digits to phone numbers before the validation is performed.
    def normalize_phone_numbers(attrs_to_check)
      attrs_to_check.each do |attribute|
        value = normalize_phone_number(attribute)
        model[attribute] = value if value
      end
    end

    def normalize_phone_number(attribute)
      ## The phone number will only be normalized if it is paired with a 'raw_' attribute.
      ## The raw attribute is used for displaying so the substitution is performed on it but saved to the regualar attribute.
      if model.methods.include?("raw_#{attribute.to_s}")
        raw_attribute = model.method("raw_#{attribute.to_s}").call
        return self.class.normalize_phone_number_value(raw_attribute) unless raw_attribute.nil?
      end
    end

    ## Email specific validations.
    def check_email_formats(attrs_to_check)
      attrs_to_check.each do |attribute|
        check = check_email_format(attribute)
        model.errors.add(attribute, I18n.translate('activerecord.errors.messages')[check]) unless check.nil?
      end
    end

    def check_email_format(attribute)
      value = get_attr_value(attribute)
      return self.class.check_email_format_value(value)
    end

    ## Phone number specific validations.
    def check_phone_numbers(attrs_to_check)
      attrs_to_check.each do |attribute|
        check = check_phone_number(attribute)
        if check
          check.each do |c|
            if c == :wrong_length
              model.errors.add(attribute, I18n.translate('activerecord.errors.messages.wrong_length', :count => 10))
            else
              model.errors.add(attribute, I18n.translate('activerecord.errors.messages')[c])
            end
          end
        end
      end
    end

    def check_phone_number(attribute)
      value = get_attr_value(attribute)
      return self.class.check_phone_number_value(value)
    end

    ## Validate values against the bad word list.
    ## We don't want to accept phony information.
    def check_against_bad_word_list(attrs_to_check)
      attrs_to_check.each do |attribute|
        check = check_bad_word_list(attribute)
        model.errors.add(attribute, I18n.translate('activerecord.errors.messages')[check]) unless check.nil?
      end
    end

    def check_bad_word_list(attribute)
      value = get_attr_value(attribute)
      return self.class.check_bad_word(value)
    end

    ## Retrieve and cache the bad word list for use in validations.
    def self.bad_word_list
      unless @bad_word_list
        badwords = IO.readlines(File.join(File.dirname(__FILE__), 'badwordlist.txt'))
        badwords.collect! {|x| x.strip}
      end
      @bad_word_list ||= badwords
    end


  protected

    def get_attr_value(attribute)
      value = model.respond_to?(attribute.to_s) ? model.send(attribute.to_s) : model[attribute.to_s]
    end

end