# Fluent Bit Troubleshooting Guide

## Fixed: Time String Length Too Long Error

### Problem
You were experiencing these errors:
```
[warn] [engine] failed to flush chunk '3519-1762279261.570151112.flb'
[error] [parser] time string length is too long
```

### Root Cause
The Apache error log parser was configured to parse timestamps in the legacy format with milliseconds:
```
Time_Format %a %b %d %H:%M:%S.%L %Y
```

However, ModSecurity and other Apache modules log with **microsecond precision** (6 digits):
```
[Tue Nov 04 18:19:02.603409 2025] [security2:error] ...
```

Fluent Bit's `%L` format only handles **3 digits** (milliseconds), not 6 digits (microseconds). When the parser encountered timestamps with microseconds, it failed with "time string length is too long", causing chunk flush failures.

### Solution Applied

#### 1. Updated Apache Error Parser ([parsers.conf](parsers.conf))

Created multiple parsers to handle different log formats:

**Primary Parser (`apache_error`):**
- Captures timestamp as text field (no time parsing to avoid format issues)
- Includes `tid` (thread ID) field for ModSecurity logs
- Handles duplicate `[client ...]` fields in ModSecurity output
- Types: `pid:integer tid:integer`

**Fallback Parsers:**
- `apache_error_simple`: Standard Apache errors without thread ID
- `apache_error_iso`: ISO 8601 format timestamps
- `apache_error_legacy`: Legacy format with milliseconds

The primary parser **does not parse the timestamp** to avoid the microsecond vs millisecond issue. Instead:
- Timestamp is captured as `log.timestamp` field (text)
- Fluent Bit uses ingestion time for `@timestamp` field in OpenSearch
- Original timestamp is preserved for reference

#### 2. Updated Fluent Bit Input Configuration ([fluent-bit.conf](fluent-bit.conf))
- Removed inline parser from Apache error INPUT section
- Added parser FILTER that tries 4 different parsers in sequence
- Parser FILTER includes detailed comments explaining each variant
- Added `Skip_Empty_Lines On` to avoid processing empty lines
- `Reserve_Data On` ensures unparsed fields are retained
- `Preserve_Key On` keeps original log line

#### 3. Enhanced Field Mapping
- `timestamp` field renamed to `log.timestamp` to preserve original time
- `severity` field renamed to `log.level` for ECS compatibility
- Multiple `client` fields handled for ModSecurity logs
- `tid` (thread ID) captured for multi-threaded logging

#### 4. Added Laravel Microsecond Parser
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
   - Lines 12-30: Updated Apache error parsers (4 variants)
   - Primary parser extracts fields without strict time parsing
   - Handles ModSecurity logs with tid and multiple client fields

2. **enterprise-deploy/fluent-bit/fluent-bit.conf**
   - Lines 66-79: Updated Apache error INPUT section
   - Lines 165-182: Added parser FILTER for Apache errors (tries 4 parsers)
   - Lines 184-195: Enhanced field mapping and renaming

### Additional Notes

#### Timestamp Handling
- Original timestamps are preserved in `log.timestamp` field
- OpenSearch `@timestamp` uses log ingestion time (not original event time)
- This approach prevents parsing errors while maintaining timestamp reference
- For precise time-series analysis, use `log.timestamp` field in queries

#### Parser Order
The parser FILTER tries parsers in this order:
1. `apache_error` - ModSecurity logs with tid and microseconds
2. `apache_error_simple` - Standard Apache errors
3. `apache_error_iso` - ISO 8601 format
4. `apache_error_legacy` - Legacy format with milliseconds

#### ModSecurity-Specific Handling
- Thread ID (`tid`) field captured for correlation
- Duplicate `[client ...]` fields handled (ModSecurity adds both)
- All OWASP tags and security metadata preserved in `message` field

#### Performance Optimization
- `Reserve_Data On` ensures unparsed data is retained
- `Preserve_Key On` keeps the original log line for debugging
- Multiple parsers provide resilience without performance penalty

### Monitoring

Monitor these metrics in OpenSearch Dashboards:
- Index: `apache-error-logs`
- Watch for parsing failures in the `_tag` field
- Check that `time` field is properly populated

### Related Documentation

- [Fluent Bit Parser Documentation](https://docs.fluentbit.io/manual/pipeline/parsers)
- [Fluent Bit Time Format](https://docs.fluentbit.io/manual/pipeline/parsers/configuring-parser#time-resolution-and-fractional-seconds)
- [OpenSearch Index Patterns](https://opensearch.org/docs/latest/dashboards/management/index-patterns/)
