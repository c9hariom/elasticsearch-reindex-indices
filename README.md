Before you proceed.

to generated indices.txt run this

```
curl -s 'http://localhost:9200/_cat/indices/?h=index' > indices.txt
```

Add below in /etc/elasticsearch/elasticsearch.yml and restart the elasticsearch

```
reindex.remote.whitelist : localhost:9200
```

```
systemctl restart elasticsearch
```
