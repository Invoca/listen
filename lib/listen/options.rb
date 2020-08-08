module Listen
  class Options
    def initialize(opts, defaults)
      @options = {}
      given_options = opts.dup
      defaults.keys.each do |key|
        @options[key] = given_options.delete(key) || defaults[key]
      end

      given_options.empty? or raise ArgumentError, "Unknown options: #{given_options.inspect}"
    end

    def method_missing(name, *_)
      @options.key?(name) or raise NameError, "Bad option: #{name.inspect} (valid:#{@options.keys.inspect})"
      @options[name]
    end
  end
end
