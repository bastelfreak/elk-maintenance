# Elasticsearch maintenance foo

## Install deps

```sh
bundle install --path .vendor/
```

## Count docs

```ruby
docs = client.cluster.stats['indices']['docs']['count']
until false
  docs2 = client.cluster.stats['indices']['docs']['count']
  puts "docs in last 10s: #{docs2 - docs}"
  docs = docs2
  sleep 10
end
```
