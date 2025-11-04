# Fluent Bit Troubleshooting Guide

## Fixed: Time String Length Too Long Error

### Problem
You were experiencing these errors:
```
[warn] [engine] failed to flush chunk '3519-1762279261.570151112.flb'
[error] [parser] time string length is too long
```

### Root Cause
The Apache error log parser was configured to parse timestamps in the legacy format:
```
Time_Format %a %b %d %H:%M:%S.%L %Y
```

However, modern Apache (and system logs) often use ISO 8601 format with high-precision timestamps (nanoseconds):
```
2025-11-04T18:01:37.439805120+00:00
```

When Fluent Bit's parser encountered these longer timestamp formats, it failed to parse them, causing chunk flush failures.

### Solution Applied

#### 1. Updated Apache Error Parser ([parsers.conf](parsers.conf))
- Changed primary parser to ISO 8601 format: `%Y-%m-%dT%H:%M:%S.%L`
- Added legacy parser as fallback: `apache_error_legacy`
- Added `Time_Keep On` to preserve original timestamps

#### 2. Updated Fluent Bit Input Configuration ([fluent-bit.conf](fluent-bit.conf))
- Removed inline parser from Apache error INPUT section
- Added parser FILTER instead (more resilient to parsing errors)
- Parser FILTER tries multiple parsers in sequence
- Added `Skip_Empty_Lines On` to avoid processing empty lines

#### 3. Added Laravel Microsecond Parser
- Created `laravel_json_micro` parser for high-precision Laravel logs
- No time format specified - lets Fluent Bit handle various timestamp formats

### How to Apply the Fix

#### If Using Docker/Container:
```bash
# Restart the Fluent Bit container
docker restart fluent-bit

# Or if using docker-compose
docker-compose restart fluent-bit
```

#### If Using Systemd Service:
```bash
# Restart Fluent Bit service
sudo systemctl restart fluent-bit

# Check status
sudo systemctl status fluent-bit

# View recent logs
sudo journalctl -u fluent-bit -n 50 -f
```

#### If Using DigitalOcean App Platform:
1. Redeploy the application to pick up the new configuration files
2. Or trigger a manual restart from the DigitalOcean console

### Verification

After restarting Fluent Bit, verify the fix:

```bash
# Check Fluent Bit logs for errors
tail -f /var/log/fluent-bit.log

# Or if using journald
journalctl -u fluent-bit -f

# Check the HTTP health endpoint
curl http://localhost:2020/api/v1/health
curl http://localhost:2020/api/v1/metrics
```

### Expected Behavior

After the fix:
- No more "time string length is too long" errors
- No more "failed to flush chunk" warnings
- Logs should flow successfully to OpenSearch indices
- All timestamp formats (ISO 8601 and legacy) should be parsed correctly

### Configuration Files Changed

1. **enterprise-deploy/fluent-bit/parsers.conf**
   - Line 13-33: Updated Apache error parsers

2. **enterprise-deploy/fluent-bit/fluent-bit.conf**
   - Line 66-79: Updated Apache error INPUT section
   - Line 165-187: Added parser FILTER for Apache errors

### Additional Notes

- The parser FILTER now tries `apache_error` first, then `apache_error_legacy`
- `Reserve_Data On` ensures unparsed data is retained
- `Preserve_Key On` keeps the original log line for debugging
- Multiple parsers provide resilience against various log formats

### Monitoring

Monitor these metrics in OpenSearch Dashboards:
- Index: `apache-error-logs`
- Watch for parsing failures in the `_tag` field
- Check that `time` field is properly populated

### Related Documentation

- [Fluent Bit Parser Documentation](https://docs.fluentbit.io/manual/pipeline/parsers)
- [Fluent Bit Time Format](https://docs.fluentbit.io/manual/pipeline/parsers/configuring-parser#time-resolution-and-fractional-seconds)
- [OpenSearch Index Patterns](https://opensearch.org/docs/latest/dashboards/management/index-patterns/)
