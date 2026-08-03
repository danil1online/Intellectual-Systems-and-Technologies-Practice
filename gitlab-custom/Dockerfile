FROM gitlab/gitlab-ce:18.10.4-ce.0

# Patch GitLab to disable prometheus metrics entirely
# The prometheus-client-mmap gem causes kernel-level stack overflow on this system

# 1. Remove the problematic gem
RUN rm -rf /opt/gitlab/embedded/lib/ruby/gems/3.3.0/gems/prometheus-client-mmap-* && \
    rm -f /opt/gitlab/embedded/lib/ruby/gems/3.3.0/specifications/prometheus-client-mmap-* && \
    find /opt/gitlab/embedded/service -name '*prometheus-client-mmap*' -delete 2>/dev/null || true

# 2. Replace the prometheus initializer with a no-op
RUN cat > /opt/gitlab/embedded/service/gitlab-rails/config/initializers/7_prometheus_metrics.rb << 'EOF'
# frozen_string_literal: true
# Prometheus metrics disabled - gem causes stack overflow on this system
EOF

# 3. Patch files that require prometheus to skip the require
RUN sed -i "s/require 'prometheus\/pid_provider'/begin; require 'prometheus\/pid_provider'; rescue LoadError; end/" /opt/gitlab/embedded/service/gitlab-rails/lib/gitlab/utils/measuring.rb

# 4. Patch metrics_service.rb to handle missing prometheus
RUN cat > /opt/gitlab/embedded/service/gitlab-rails/app/services/metrics_service.rb << 'EOF'
# frozen_string_literal: true

PROMETHEUS_AVAILABLE = false

class MetricsService
  def prometheus_metrics_text
    "# Prometheus metrics not available\n"
  end

  def metrics_text
    prometheus_metrics_text
  end

  private

  def multiprocess_metrics_path
    "/tmp"
  end
end
EOF

# 5. Remove prometheus-client-mmap from Gemfile and Gemfile.lock
RUN sed -i '/gem .prometheus-client-mmap./d' /opt/gitlab/embedded/service/gitlab-rails/Gemfile && \
    sed -i '/prometheus-client-mmap/d' /opt/gitlab/embedded/service/gitlab-rails/Gemfile.lock

# 6. Create stub prometheus/client.rb in site_ruby (in $LOAD_PATH)
RUN mkdir -p /opt/gitlab/embedded/lib/ruby/site_ruby/prometheus/client/formats/rack && \
    cat > /opt/gitlab/embedded/lib/ruby/site_ruby/prometheus/client.rb << 'EOF'
# frozen_string_literal: true
module Prometheus
  module Client
    def self.register(*); end
    def self.clear; end
    def self.reinitialize_on_pid_change(*); end
    def self.configure
      yield Configuration.new
    end
    def self.configuration
      @configuration ||= Configuration.new
    end
    def self.cleanup_multiproc_dir(*); end

    class Configuration
      attr_accessor :multiprocess_files_dir, :pid_provider
      def initialize
        @multiprocess_files_dir = nil
        @pid_provider = nil
      end
    end

    class Collector; end
    class Counter
      def initialize(**); end
      def increment(*); end
      def decrement(*); end
    end
    class Gauge
      def initialize(**); end
      def set(*); end
      def increment(*); end
      def decrement(*); end
    end
    class Histogram
      DEFAULT_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0, Float::INFINITY].freeze
      def initialize(**); end
      def observe(*); end
    end
    class Summary
      def initialize(**); end
      def observe(*); end
    end
    class Info
      def initialize(**); end
      def set(*); end
    end
    class Unknown
      def initialize(**); end
      def set(*); end
    end
  end
end
EOF

# 6b. Create stub prometheus/client/formats/text.rb
RUN cat > /opt/gitlab/embedded/lib/ruby/site_ruby/prometheus/client/formats/text.rb << 'EOF'
# frozen_string_literal: true
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
EOF

# 6c. Create stub prometheus/client/rack/exporter.rb
RUN mkdir -p /opt/gitlab/embedded/lib/ruby/site_ruby/prometheus/client/rack && \
    cat > /opt/gitlab/embedded/lib/ruby/site_ruby/prometheus/client/rack/exporter.rb << 'EOF'
# frozen_string_literal: true
module Prometheus
  module Client
    module Rack
      class Exporter
        def initialize(app = nil, **); end
        def call(env); end
      end
    end
  end
end
EOF

# 8. Create stub pid_provider.rb
RUN cat > /opt/gitlab/embedded/lib/ruby/site_ruby/prometheus/pid_provider.rb << 'EOF'
# frozen_string_literal: true
module Prometheus
  class PidProvider
    def self.worker_id
      "gitlab_stub"
    end
  end
end
EOF

# 9b. Allow GET requests for OIDC login (OmniAuth blocks GET by default for CSRF)
RUN sed -i 's/OmniAuth.config.allowed_request_methods = \[:post\]/OmniAuth.config.allowed_request_methods = [:get, :post]/' /opt/gitlab/embedded/service/gitlab-rails/config/initializers/omniauth.rb

# 10. Patch Gitlab::OmniauthInitializer.arguments_for to pass through all provider keys
# Omnibus initializer only extracts app_id, app_secret, and args hash.
# Top-level keys like issuer, discovery, scope, redirect_uri are ignored.
# This patch uses prepend to override arguments_for and merge all provider keys.
RUN cat >> /opt/gitlab/embedded/service/gitlab-rails/lib/gitlab/omniauth_initializer.rb << 'RUBY'

module Gitlab
  class OmniauthInitializer
    module ArgumentsForPatch
      def arguments_for(provider)
        provider_arguments = []

        %w[app_id app_secret].each do |argument|
          provider_arguments << provider[argument] if provider[argument]
        end

        # Build options hash from all top-level provider keys (except handled keys)
        skip_keys = %w[name args label strategy_class app_id app_secret]
        options_hash = provider.reject { |k| skip_keys.include?(k.to_s) }

        # Move openid_connect-specific keys to client_options
        client_opts_keys = %w[redirect_uri authorization_endpoint token_endpoint userinfo_endpoint jwks_uri end_session_endpoint]
        client_opts_keys.each do |key|
          if options_hash.key?(key)
            options_hash[:client_options] ||= {}
            options_hash[:client_options][key.to_sym] = options_hash.delete(key)
          end
        end

        arguments = options_hash.delete(:args) || provider.fetch('args', {})
        defaults = provider_defaults(provider)

        case arguments
        when Array
          provider_arguments.concat arguments
          provider_arguments << defaults unless defaults.empty?
        when Hash, GitlabSettings::Options
          verify_saml_cert_arguments!(provider['name'], arguments)
          hash_arguments = merge_hash_defaults_and_args(defaults, arguments)
          normalized = normalize_hash_arguments(hash_arguments)
          normalized.merge!(options_hash.symbolize_keys) unless options_hash.empty?
          provider_arguments << normalized unless normalized.empty?
        else
          Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
            ConfigurationError.new("Arguments were provided for #{provider['name']}, but not as an array or a hash"),
            provider_name: provider['name'],
            arguments_type: arguments.class.name
          )
          provider_arguments << defaults unless defaults.empty?
        end

        provider_arguments
      end
    end
    prepend ArgumentsForPatch
  end
end
RUBY

# 10b. Patch openid_connect omniauth strategy to accept omnibus-style positional args
# GitLab passes app_id/app_secret as positional args, but OpenIDConnect expects them in options
RUN cat >> /opt/gitlab/embedded/lib/ruby/gems/3.3.0/gems/omniauth_openid_connect-0.8.0/lib/omniauth/strategies/openid_connect.rb << 'RUBY'

# Patch for omnibus GitLab compatibility - accepts app_id/app_secret as positional args
module OmniAuth
  module Strategies
    class OpenIDConnect
      def initialize(app, *args)
        if args.length >= 2 && args.first.is_a?(String) && args[1].is_a?(String)
          app_id = args[0]
          app_secret = args[1]
          options_hash = args[2] || {}
          options_hash = options_hash.to_h if options_hash.respond_to?(:to_h)
          options_hash = options_hash.dup
          options_hash[:client_options] ||= {}
          options_hash[:client_options] = options_hash[:client_options].dup
          options_hash[:client_options][:identifier] = app_id
          options_hash[:client_options][:secret] = app_secret
          super(app, options_hash)
        else
          super
        end
      end
    end
  end
end
RUBY

# Copy custom entrypoint
COPY docker-entrypoint.sh /opt/gitlab/docker-entrypoint.sh
RUN chmod +x /opt/gitlab/docker-entrypoint.sh

ENTRYPOINT ["/opt/gitlab/docker-entrypoint.sh"]
