# frozen_string_literal: true

##
# created by Tim Meusel
# with suggestions from Joakim Reinert
##
# Some API docs at:
# .vendor/ruby/2.4.0/gems/elasticsearch-api-5.0.4/lib/elasticsearch/api/actions/reindex.rb
# http://dry-rb.org/gems/dry-types/
# http://dry-rb.org/gems/dry-types/default-values/
# https://github.com/elastic/elasticsearch-ruby/issues/319
# https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-reindex.html
# http://www.rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Indices/Actions
# https://github.com/elastic/elasticsearch-ruby/blob/master/elasticsearch-api/lib/elasticsearch/api/actions/indices/put_settings.rb
##

# main lib to interact with elasticsearch
require 'elasticsearch'
# provide safe types
require 'dry-types'
require 'dry-struct'
# for CLI support
require 'optparse'

module Types
  include Dry::Types.module
  # URI = Instance(::URI).constructor { |value| ::URI(value) }
end

class Maintenance < Dry::Struct
  attribute :source, Types::Strict::String
  attribute :destination, Types::Strict::String
  attribute :url, Types::Strict::String.default('http://localhost:9200')

  def client(force: nil)
    @client = nil if force
    @client ||= Elasticsearch::Client.new url: url
  end

  def all_indicies
    client.indices.get index: '_all'
  end

  def recreate_index
    exit unless client.cluster.health['status'] == 'green'
    client.indices.create index: destination
    wait_for_cluster
    @task_id = client.reindex(body: { source: { index: source, size: 10_000 }, dest: { index: destination } }, refresh: true, wait_for_completion: false)['task']
  end

  def wait_for_cluster
    until client.cluster.health['status'] == 'green'
      puts 'waiting 30s for cluster to become green'
      sleep 30
    end
    puts 'cluster is green now!'
  end

  def wait_for_task
    until client.tasks.list(task_id: @task_id)['completed'] == true
      puts 'waiting 30s for the job to finish'
      sleep 30
    end
    puts "job status is: #{client.tasks.list task_id: @task_id}"
    puts ''
    true
  end

  def cleanup
    wait_for_task if @task_id
    puts "Set replicas for #{destination} from #{index_number_of_shards(destination)} to #{template_number_of_replicas}"
    response = set_correct_replicas(destination)
    if response
      puts 'successfully modified replica'
      wait_for_cluster
      puts "delete index #{source} in 30s"
      sleep 30
      client.indices.delete index: source
    else
      puts "setting replicas failed, we got: #{response}"
    end
  end

  def template_settings
    client.cluster.state['metadata']['templates']['filebeat']['settings']['index']
  end

  def template_number_of_shards
    settings = template_settings
    settings['number_of_shards'].to_i
  end

  def template_number_of_replicas
    settings = template_settings
    settings['number_of_replicas'].to_i
  end

  def index_settings(index)
    result = client.indices.get index: index
    result[index]['settings']['index']
  end

  def index_number_of_shards(index)
    settings = index_settings(index)
    settings['number_of_shards']
  end

  def index_number_of_replicas
    settings = index_settings(index)
    settings['number_of_replicas']
  end

  def set_replicas(index, replicas)
    response = client.indices.put_settings index: index, body: { index: { number_of_replicas: replicas } }
    # {"acknowledged"=>true}
    response['acknowledged']
  end

  def drop_replicas(index)
    response = client.indices.put_settings index: index, body: { index: { number_of_replicas: 0 } }
    response['acknowledged']
  end

  def set_correct_replicas(index)
    response = client.indices.put_settings index: index, body: { index: { number_of_replicas: template_number_of_replicas } }
    response['acknowledged']
  end
end

# example to migrate a single index
index = 'filebeat-2017.08.12'
m = Maintenance.new(source: index, destination: "#{index}.new", url: nil)
m.recreate_index
m.cleanup
