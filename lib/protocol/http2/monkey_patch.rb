begin
  ''.unpack1('*')
rescue => NoMethodError
  # for compat ruby 2.3
  class String
    def unpack1(template)
      unpack(template).first
    end
  end
end
