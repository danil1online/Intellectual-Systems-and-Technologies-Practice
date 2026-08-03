# frozen_string_literal: true

begin
  require 'prometheus/client/formats/text'
  PROMETHEUS_AVAILABLE = true
rescue LoadError
  PROMETHEUS_AVAILABLE = false
end

class MetricsService
  def prometheus_metrics_text
    return "# Prometheus metrics not available\n" unless PROMETHEUS_AVAILABLE
    ::Prometheus::Client::Formats::Text.marshal_multiprocess(multiprocess_metrics_path)
  end

  def metrics_text
    prometheus_metrics_text
  end

  private

  def multiprocess_metrics_path
    ::Gitlab::Metrics.client.configuration.multiprocess_files_dir
  end
end
