# 🚨 Emergency Call Configuration

## Overview

When a tremor/freeze is detected, the watch waits **15 seconds** and then triggers an emergency phone call via the Supabase Edge Function.

## Configuration (Before Build)

### 1. Phone Number

Edit `entry/src/main/ets/config/AppConfig.ets`:

```typescript
static readonly EMERGENCY_PHONE_NUMBER = '+4915165140425'; // Change this!
```

**Format**: International format with country code (e.g., `+49` for Germany)

### 2. Location

Edit `entry/src/main/ets/config/AppConfig.ets`:

```typescript
static readonly EMERGENCY_LOCATION = {
  lat: 48.1351,  // Latitude
  lng: 11.5820   // Longitude
};
```

**Default**: Munich, Germany (TUM area)

## API Endpoint Details

- **URL**: `https://smmwnlhdcrauwnstfasu.supabase.co/functions/v1/call-me`
- **Method**: POST
- **API Key**: `ParkinsonAtHackatum` (already configured)

### Request Payload

```json
{
  "phone": "+4915165140425",
  "incident_id": "INC_1732392847125",
  "user_id": "USER_WATCH_001",
  "severity": 0.85,
  "confidence": 0.92,
  "location": {
    "lat": 48.1351,
    "lng": 11.5820
  }
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `phone` | string | Guardian's phone number (from `EMERGENCY_PHONE_NUMBER`) |
| `incident_id` | string | Unique incident ID (auto-generated: `INC_<timestamp>`) |
| `user_id` | string | User identifier (currently hardcoded: `USER_WATCH_001`) |
| `severity` | number | Incident severity (0.0-1.0, currently 0.85) |
| `confidence` | number | Detection confidence (0.0-1.0, currently 0.92) |
| `location` | object | GPS coordinates from `EMERGENCY_LOCATION` |

## Testing the Endpoint

### Manual Test with curl

```bash
curl -X POST https://smmwnlhdcrauwnstfasu.supabase.co/functions/v1/call-me \
  -H "Content-Type: application/json" \
  -H "x-api-key: ParkinsonAtHackatum" \
  -d '{
    "phone": "+4915165140425",
    "incident_id": "INC_TEST_001",
    "user_id": "USER_123",
    "severity": 0.85,
    "confidence": 0.92,
    "location": {"lat": 48.1351, "lng": 11.5820}
  }'
```

### Expected Response

- **Success**: HTTP 200 or 201
- **Body**: JSON response from Supabase function

## Demo Flow

1. **T=0s**: Violent shake detected
   - Red screen appears
   - Metronome plays
   - Vibration starts

2. **T=15s**: Emergency call triggered
   - HTTP POST sent to Supabase
   - UI shows "Calling Guardian..."
   - Guardian receives phone call

3. **Success**: UI shows "Guardian Notified"

## Troubleshooting

### Call Not Made

1. Check watch is connected to WiFi
2. Verify logs: `hdc shell hilog | grep DemoManager`
3. Look for:
   ```
   Sending POST to https://smmwnlhdcrauwnstfasu.supabase.co/functions/v1/call-me
   Response code: 200
   ✅ Emergency call triggered successfully
   ```

### Wrong Number Called

1. Open `entry/src/main/ets/config/AppConfig.ets`
2. Update `EMERGENCY_PHONE_NUMBER`
3. Rebuild and redeploy app

### Network Errors

- **Timeout**: Increase `connectTimeout` in `DemoManager.ets`
- **403 Forbidden**: Check API key is correct
- **500 Server Error**: Check Supabase function status

## Logs to Monitor

```bash
# Watch logs
hdc shell hilog | grep -E "(DemoManager|AudioPlayer)"

# Look for:
# 🚨 DEMO SEQUENCE STARTED
# ⚡ PHASE 1: Starting immediate intervention
# 🎵 Metronome started
# 📳 Vibration started
# ⏰ Scheduling phone call trigger in 15000ms
# 📞 PHASE 2: Triggering emergency phone call
# Sending POST to https://...
# Response code: 200
# ✅ Emergency call triggered successfully
```

## Configuration Checklist

- [ ] Set `EMERGENCY_PHONE_NUMBER` in `AppConfig.ets`
- [ ] Set `EMERGENCY_LOCATION` in `AppConfig.ets`
- [ ] Build app
- [ ] Deploy to watch
- [ ] Test with shake gesture
- [ ] Verify phone rings after 15 seconds
- [ ] Test "Stop Demo" button works

## Future Enhancements

- [ ] Add multiple guardian phone numbers (fallback)
- [ ] Use real GPS coordinates instead of static location
- [ ] Add SMS fallback if call fails
- [ ] Store user_id in app preferences
- [ ] Make severity/confidence dynamic based on detection
