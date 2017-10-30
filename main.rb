# frozen_string_literal: true

##
# created by Tim Meusel
##
# Some API docs at:
# .vendor/ruby/2.4.0/gems/elasticsearch-api-5.0.4/lib/elasticsearch/api/actions/reindex.rb
# http://dry-rb.org/gems/dry-types/
# https://github.com/elastic/elasticsearch-ruby/issues/319
# https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-reindex.html
# http://www.rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Indices/Actions
##

require 'elasticsearch'
require 'dry-types'
require 'dry-struct'

module Types
  include Dry::Types.module
end

class Maintenance < Dry::Struct
  attribute :source, Types::Strict::String
  attribute :destination, Types::Strict::String

  def url(force: nil)
    @url = nil if force
    @url ||= 'http://localhost:9200'
  end

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
    @task_id = client.reindex(body: { source: { index: source, size: 5000 }, dest: { index: destination } }, refresh: true, wait_for_completion: false)['task']
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
    wait_for_task
    puts "delete index #{source} in 30s"
    sleep 30
    client.indices.delete index: source
  end
end

# example
m = Maintenance.new(source: 'filebeat-2017.08.09', destination: 'filebeat-2017.08.09.new', url: 'http://localhost:9200')
m.recreate_index
m.cleanup
