# Reports stats on an elasticsearch cluster, including health (green, yellow, red),
# number of nodes, number of shards, etc
#
# Created by John Wood of Signal
class ElasticsearchClusterStatus < Scout::Plugin

  OPTIONS = <<-EOS
    elasticsearch_host:
      default: http://127.0.0.1
      name: elasticsearch host
      notes: The host elasticsearch is running on
    elasticsearch_port:
      default: 9200
      name: elasticsearch port
      notes: The port elasticsearch is running on
    alert_on_change:
      default: true
      name: alert on any change
      notes: Generate an internal alert any time the cluster status changes
  EOS

  needs 'net/http', 'json', 'open-uri'

  def build_report
    if option(:elasticsearch_host).nil? || option(:elasticsearch_port).nil?
      return error("Please provide the host and port", "The elasticsearch host and port to monitor are required.\n\nelasticsearch Host: #{option(:elasticsearch_host)}\n\nelasticsearch Port: #{option(:elasticsearch_port)}")
    end

    base_url = "#{option(:elasticsearch_host)}:#{option(:elasticsearch_port)}/_cluster/health"
    response = JSON.parse(Net::HTTP.get(URI.parse(base_url)))

    report(:status => status(response['status']))
    report(:number_of_nodes => response['number_of_nodes'])
    report(:number_of_data_nodes => response['number_of_data_nodes'])
    report(:active_primary_shards => response['active_primary_shards'])
    report(:active_shards => response['active_shards'])
    report(:relocating_shards => response['relocating_shards'])
    report(:initializing_shards => response['initializing_shards'])
    report(:unassigned_shards => response['unassigned_shards'])

    # Send an alert every time cluster status changes, if enabled
    if truthy?(option(:alert_on_change)) && memory(:cluster_status) && memory(:cluster_status) != response['status']
      alert("elasticsearch cluster status changed to '#{response['status']}'","elasticsearch cluster health status changed from '#{memory(:cluster_status)}' to '#{response['status']}'")
    end
    remember :cluster_status => response['status']

  rescue OpenURI::HTTPError
    error("Stats URL not found", "Please ensure the base url for elasticsearch cluster stats is correct. Current URL: \n\n#{base_url}")
  rescue SocketError
    error("Hostname is invalid", "Please ensure the elasticsearch Host is correct - the host could not be found. Current URL: \n\n#{base_url}")
  rescue Errno::ECONNREFUSED
    error("Unable to connect", "Please ensure the host and port are correct. Current URL: \n\n#{base_url}")
  end

  def truthy?(val)
    !val.nil? && val.downcase.strip == "true"
  end

  # Generates a status string like "2 (green)" so triggers can be run off the status.
  def status(color)
    code = case color
    when 'green'
      2
    when 'yellow'
      1
    when 'red'
      0
    end
    "#{code} (#{color})"
  end

end

