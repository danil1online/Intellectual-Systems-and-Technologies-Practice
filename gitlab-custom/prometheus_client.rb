# frozen_string_literal: true

# Stub module - prometheus metrics are disabled
module Prometheus
  module Client
    module Formats
      module Text
        def self.marshal_multiprocess(path)
          "# Prometheus metrics disabled\n"
        end
      end
    end
  end
end
