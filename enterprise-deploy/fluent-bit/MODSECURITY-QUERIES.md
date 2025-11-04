# ModSecurity Log Queries in OpenSearch

## Overview
ModSecurity logs are now properly parsed and indexed in the `apache-error-logs` index. This guide provides useful queries for security monitoring.

## Index Information
- **Index Name**: `apache-error-logs`
- **Module Field**: `module` = "security2"
- **Severity Field**: `log.level` (e.g., "error", "warning")
- **Original Timestamp**: `log.timestamp` (text field)
- **Ingestion Time**: `@timestamp` (date field)

## Common Fields in ModSecurity Logs

| Field | Description | Example |
|-------|-------------|---------|
| `module` | Apache module name | "security2" |
| `log.level` | Severity level | "error", "warning" |
| `pid` | Process ID | 3535 |
| `tid` | Thread ID | 139247818376896 |
| `client` | Client IP (first occurrence) | "172.68.138.149:0" |
| `client_ip` | Client IP (second occurrence) | "172.68.138.149" |
| `message` | Full ModSecurity message | "ModSecurity: Warning..." |
| `log.timestamp` | Original log timestamp | "Tue Nov 04 18:19:02.603409 2025" |
| `log` | Original raw log line | Full log entry |

## Useful OpenSearch Queries

### 1. All ModSecurity Alerts
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "module.keyword": "security2" } }
      ]
    }
  },
  "sort": [
    { "@timestamp": { "order": "desc" } }
  ]
}
```

### 2. Critical ModSecurity Alerts Only
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "module.keyword": "security2" } },
        { "term": { "log.level.keyword": "error" } },
        { "regexp": { "message": ".*severity.*CRITICAL.*" } }
      ]
    }
  }
}
```

### 3. OWASP Attack Categories
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "module.keyword": "security2" } }
      ],
      "should": [
        { "match": { "message": "OWASP_CRS" } }
      ]
    }
  },
  "aggs": {
    "attack_types": {
      "terms": {
        "field": "message.keyword",
        "size": 20,
        "include": ".*tag.*attack.*"
      }
    }
  }
}
```

### 4. Top Attacking IPs
```json
{
  "query": {
    "term": { "module.keyword": "security2" }
  },
  "aggs": {
    "top_attackers": {
      "terms": {
        "field": "client_ip.keyword",
        "size": 10
      }
    }
  }
}
```

### 5. Path Traversal Attacks
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "module.keyword": "security2" } },
        { "match": { "message": "Path Traversal Attack" } }
      ]
    }
  }
}
```

### 6. SQL Injection Attempts
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "module.keyword": "security2" } },
        { "regexp": { "message": ".*(SQL|sql).*injection.*" } }
      ]
    }
  }
}
```

### 7. XSS (Cross-Site Scripting) Attempts
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "module.keyword": "security2" } },
        { "regexp": { "message": ".*XSS.*|.*cross.*site.*script.*" } }
      ]
    }
  }
}
```

### 8. High Anomaly Scores
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "module.keyword": "security2" } },
        { "regexp": { "message": ".*Anomaly Score.*" } },
        { "range": { "@timestamp": { "gte": "now-1h" } } }
      ]
    }
  }
}
```

### 9. Blocked Requests (Inbound Score >= 5)
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "module.keyword": "security2" } },
        { "regexp": { "message": ".*Inbound Anomaly Score Exceeded.*" } }
      ]
    }
  }
}
```

### 10. Specific OWASP Rules Triggered
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "module.keyword": "security2" } },
        { "match": { "message": "id \"930110\"" } }
      ]
    }
  }
}
```

## OpenSearch Dashboard Visualizations

### Recommended Visualizations

1. **Timeline of Security Events**
   - Type: Line chart
   - X-axis: `@timestamp` (date histogram)
   - Y-axis: Count
   - Filter: `module.keyword = security2`

2. **Attack Types Distribution**
   - Type: Pie chart
   - Slice by: Extract OWASP tags from `message` field
   - Filter: `module.keyword = security2`

3. **Top Attacking IPs**
   - Type: Data table
   - Columns: `client_ip.keyword`, Count
   - Sort: Count descending
   - Size: 20

4. **Severity Levels**
   - Type: Vertical bar chart
   - X-axis: `log.level.keyword`
   - Y-axis: Count
   - Color by terms

5. **Geographic Map of Attacks** (requires IP geo-enrichment)
   - Type: Coordinate map
   - Geohash: `client_geo.location`
   - Metric: Count

## Alert Rules

### Create Alerts for Critical Events

#### Alert 1: High-Severity Attack Detected
```json
{
  "trigger": {
    "schedule": {
      "interval": "5m"
    }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["apache-error-logs"],
        "body": {
          "query": {
            "bool": {
              "must": [
                { "term": { "module.keyword": "security2" } },
                { "regexp": { "message": ".*CRITICAL.*" } },
                { "range": { "@timestamp": { "gte": "now-5m" } } }
              ]
            }
          }
        }
      }
    }
  },
  "condition": {
    "compare": {
      "ctx.payload.hits.total": {
        "gt": 0
      }
    }
  }
}
```

#### Alert 2: Multiple Attacks from Same IP
```json
{
  "trigger": {
    "schedule": {
      "interval": "10m"
    }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["apache-error-logs"],
        "body": {
          "query": {
            "bool": {
              "must": [
                { "term": { "module.keyword": "security2" } },
                { "range": { "@timestamp": { "gte": "now-10m" } } }
              ]
            }
          },
          "aggs": {
            "by_ip": {
              "terms": {
                "field": "client_ip.keyword",
                "min_doc_count": 10
              }
            }
          }
        }
      }
    }
  },
  "condition": {
    "compare": {
      "ctx.payload.aggregations.by_ip.buckets.length": {
        "gt": 0
      }
    }
  }
}
```

## Sample OpenSearch Dashboard Filters

Add these to your dashboard for quick filtering:

1. **Time Range**: Last 24 hours
2. **Module**: `security2`
3. **Exclude Info**: `NOT log.level:info`
4. **Attack Tags**: `message: "tag" AND message: "attack"`
5. **Specific URIs**: `message: "/app/to-do"` (adjust as needed)

## Tips for Analysis

1. **Correlate with Access Logs**: Cross-reference `client_ip` with Apache access logs
2. **Track Anomaly Scores**: Watch for patterns in score increases
3. **Monitor Rule IDs**: Certain rule IDs may indicate false positives
4. **Geographic Analysis**: Use IP geolocation to identify attack origins
5. **Time-based Patterns**: Look for attack timing patterns (e.g., off-hours)

## Performance Considerations

- Use specific time ranges to improve query performance
- Create index patterns with timestamp-based routing
- Consider data retention policies for security logs
- Use aggregations carefully on high-cardinality fields

## References

- [ModSecurity Documentation](https://github.com/SpiderLabs/ModSecurity)
- [OWASP Core Rule Set](https://owasp.org/www-project-modsecurity-core-rule-set/)
- [OpenSearch Query DSL](https://opensearch.org/docs/latest/query-dsl/)
