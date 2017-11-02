# Elasticsearch maintenance foo

## Install deps

```sh
bundle install --path .vendor/
```

## Count docs

```ruby
client = Elasticsearch::Client.new
docs = client.cluster.stats['indices']['docs']['count']
until false
  docs2 = client.cluster.stats['indices']['docs']['count']
  puts "docs in last 10s: #{docs2 - docs}"
  docs = docs2
  sleep 10
end
```

Or in more beautiful:

```ruby
client = Elasticsearch::Client.new
a = client.cluster.stats.dig("indices","docs","count")
loop do
  sleep 1
  x = client.cluster.stats.dig("indices","docs","count")
  print "\r#{x-a}  "
  a = x
end
```
## Infos about a node

```ruby
puts client.cluster.stats
```

## Stats about nodes

```ruby
client.nodes.stats
```

## Infos about nodes

```ruby
client.nodes.infos
```
