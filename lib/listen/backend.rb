require 'listen/adapter'
require 'listen/adapter/base'
require 'listen/adapter/config'

require 'forwardable'

# This class just aggregates configuration object to avoid Listener specs
# from exploding with huge test setup blocks
module Listen
  class Backend
    extend Forwardable

    def initialize(directories, queue, silencer, config)
      Listen::Logger.debug("InvocaDebug: Backend#initialize about to call adapter_select_options")

      adapter_select_opts = config.adapter_select_options

      Listen::Logger.debug("InvocaDebug: Backend#initialize about to call Adapter.select")

      adapter_class = Adapter.select(adapter_select_opts)

      Listen::Logger.debug("InvocaDebug: Backend#initialize chose Adapter #{adapter_class.name}")

      # Use default from adapter if possible
      @min_delay_between_events = config.min_delay_between_events ||
                                  adapter_class::DEFAULTS[:wait_for_delay] ||
                                  0.1

      adapter_opts = config.adapter_instance_options(adapter_class)

      Listen::Logger.debug("InvocaDebug: Backend#initialize about to call Adapter::Config.new")

      aconfig = Adapter::Config.new(directories, queue, silencer, adapter_opts)

      Listen::Logger.debug("InvocaDebug: Backend#initialize about to call #{adapter_class}.new")

      @adapter = adapter_class.new(aconfig)
      @adapter.start

      Listen::Logger.debug("InvocaDebug: Backend#initialize done")
    end

    delegate stop: :@adapter

    attr_reader :min_delay_between_events
  end
end
