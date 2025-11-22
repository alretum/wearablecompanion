# GPS Coordinate Retrieval Guide for HarmonyOS Wearables

This guide provides a complete implementation reference for retrieving, calculating, and saving GPS coordinates from HarmonyOS wearable devices (watches).

## Overview

The implementation uses HarmonyOS LocationKit to acquire GPS coordinates from wearable devices, convert them to different formats (decimal degrees to DMS - Degrees, Minutes, Seconds), and display/log the results.

## Prerequisites

- HarmonyOS SDK with LocationKit support
- Target device: Wearable (watch) or phone
- Development environment: DevEco Studio

## Required Permissions

### 1. Module Configuration (module.json5)

Add the following permissions to your `module.json5` file under the `requestPermissions` array:

```json
{
  "module": {
    "name": "entry",
    "type": "entry",
    "deviceTypes": [
      "phone",
      "wearable"
    ],
    "requestPermissions": [
      {
        "name": "ohos.permission.APPROXIMATELY_LOCATION",
        "reason": "$string:permission_reason_location",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "always"
        }
      },
      {
        "name": "ohos.permission.LOCATION",
        "reason": "$string:permission_reason_location",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "always"
        }
      }
    ]
  }
}
```

### 2. String Resources

Add permission reason strings to your `resources/base/element/string.json`:

```json
{
  "string": [
    {
      "name": "permission_reason_location",
      "value": "This app needs location access to provide GPS coordinates"
    }
  ]
}
```

## Implementation Components

### Component 1: Coordinate Conversion Utility

Create a utility file for converting decimal degrees to DMS format: `CoordinatesConverter.ts`

```typescript
export enum CoordinateType {
  LATITUDE = 'LATITUDE',
  LONGITUDE = 'LONGITUDE'
}

/**
 * Converts decimal degrees to DMS (Degrees, Minutes, Seconds) format
 * @param value - The coordinate value in decimal degrees
 * @param type - The coordinate type (LATITUDE or LONGITUDE)
 * @returns Formatted string in DMS format (e.g., "51°10'44.04"N")
 */
export function toDMS(value: number, type: CoordinateType): string {
  const absValue = Math.abs(value);
  const degrees = Math.floor(absValue);
  const minutesDecimal = (absValue - degrees) * 60;
  const minutes = Math.floor(minutesDecimal);
  const seconds = (minutesDecimal - minutes) * 60;

  const direction = type === CoordinateType.LATITUDE
    ? (value >= 0 ? 'N' : 'S')
    : (value >= 0 ? 'E' : 'W');

  return `${degrees}°${minutes}'${seconds.toFixed(2)}"${direction}`;
}
```

**Usage Examples:**
- `toDMS(51.1789, CoordinateType.LATITUDE)` → `"51°10'44.04"N"`
- `toDMS(-0.0014, CoordinateType.LONGITUDE)` → `"0°0'5.04"W"`

### Component 2: Main GPS Retrieval Logic

Implement the GPS retrieval in your component/page (e.g., `Index.ets`):

```typescript
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CoordinateType, toDMS } from '../common/CoordinatesConverter';

@Entry
@Component
struct Index {
  private atManager: abilityAccessCtrl.AtManager | null = null
  private context: common.UIAbilityContext | undefined = undefined

  aboutToAppear(): void {
    // Get the UI context
    try {
      this.context = this.getUIContext().getHostContext() as common.UIAbilityContext
    } catch {
      this.context = undefined
    }
    
    // Initialize permission manager
    this.atManager = abilityAccessCtrl.createAtManager()
    
    // Request permissions on startup
    this.requestPermissionsAndStart()

    // Check if location services are enabled
    if (!this.isLocationSettingOpen()) {
      this.requestLocation()
    }
  }

  /**
   * Check if location services are enabled on the device
   */
  isLocationSettingOpen(): boolean {
    return geoLocationManager.isLocationEnabled();
  }

  /**
   * Request location permissions from the user
   */
  async requestPermissionsAndStart(): Promise<void> {
    const perms: Permissions[] = [
      'ohos.permission.LOCATION', 
      'ohos.permission.APPROXIMATELY_LOCATION'
    ]
    
    try {
      if (this.atManager && this.context) {
        const result = await this.atManager.requestPermissionsFromUser(this.context, perms)
        console.log('Permission request result: ' + JSON.stringify(result))
      }
    } catch (err) {
      console.error('Request permission failed: ' + JSON.stringify(err))
    }
  }

  /**
   * Request user to enable location services via system dialog
   */
  requestLocation(): void {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    let context: Context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    
    atManager.requestGlobalSwitch(context, abilityAccessCtrl.SwitchType.LOCATION)
      .then((data: Boolean) => {
        console.info(`requestGlobalSwitch success, result: ${data}`);
      })
      .catch((err: BusinessError) => {
        console.error(`requestGlobalSwitch fail, code: ${err.code}, message: ${err.message}`);
      });
  }

  /**
   * Get current GPS location coordinates
   * This is the main function for retrieving GPS data
   */
  getLocationInfo(): void {
    // Configure location request parameters
    let request: geoLocationManager.SingleLocationRequest = {
      'locatingPriority': geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
      'locatingTimeoutMs': 10000  // 10 second timeout
    }
    
    try {
      geoLocationManager.getCurrentLocation(request)
        .then((result) => {
          // Log raw coordinates (decimal degrees)
          console.log('Current location (raw): ' + JSON.stringify(result));
          
          // Convert and log in DMS format
          const latDMS = toDMS(result.latitude, CoordinateType.LATITUDE);
          const lonDMS = toDMS(result.longitude, CoordinateType.LONGITUDE);
          console.log(`Current location (DMS): ${latDMS}, ${lonDMS}`);
          
          // Access coordinate data:
          // - result.latitude: decimal degrees latitude
          // - result.longitude: decimal degrees longitude
          // - result.altitude: altitude in meters (if available)
          // - result.accuracy: accuracy in meters
          // - result.speed: speed in meters per second (if available)
          // - result.timeStamp: timestamp of the location fix
        })
        .catch((error: BusinessError) => {
          console.error('getCurrentLocation error: ' + JSON.stringify(error));
        });
    } catch (err) {
      console.error("Error: " + JSON.stringify(err));
    }
  }

  build() {
    Column() {
      Button('Get GPS Location')
        .onClick(() => {
          this.getLocationInfo()
        })
    }
    .height('100%')
    .width('100%')
  }
}
```

## GPS Data Structure

When you call `getCurrentLocation()`, the result object contains:

```typescript
{
  latitude: number,      // Decimal degrees (-90 to 90)
  longitude: number,     // Decimal degrees (-180 to 180)
  altitude: number,      // Meters above sea level
  accuracy: number,      // Horizontal accuracy in meters
  speed: number,         // Speed in meters per second
  timeStamp: number,     // Unix timestamp in milliseconds
  direction: number,     // Direction of travel in degrees
  timeSinceBoot: number  // Time since device boot in nanoseconds
}
```

## Saving GPS Coordinates

### Option 1: Save to Preferences (Key-Value Storage)

```typescript
import { preferences } from '@kit.ArkData';

async saveLocationToPreferences(latitude: number, longitude: number): Promise<void> {
  try {
    const dataPreferences = await preferences.getPreferences(this.context, 'gpsData');
    await dataPreferences.put('latitude', latitude);
    await dataPreferences.put('longitude', longitude);
    await dataPreferences.put('timestamp', Date.now());
    await dataPreferences.flush();
    console.log('Location saved successfully');
  } catch (err) {
    console.error('Failed to save location: ' + JSON.stringify(err));
  }
}

async loadLocationFromPreferences(): Promise<{lat: number, lon: number, time: number}> {
  try {
    const dataPreferences = await preferences.getPreferences(this.context, 'gpsData');
    const latitude = await dataPreferences.get('latitude', 0.0);
    const longitude = await dataPreferences.get('longitude', 0.0);
    const timestamp = await dataPreferences.get('timestamp', 0);
    return { lat: latitude as number, lon: longitude as number, time: timestamp as number };
  } catch (err) {
    console.error('Failed to load location: ' + JSON.stringify(err));
    return { lat: 0, lon: 0, time: 0 };
  }
}
```

### Option 2: Save to File System

```typescript
import { fileIo } from '@kit.CoreFileKit';

async saveLocationToFile(latitude: number, longitude: number): Promise<void> {
  try {
    const filesDir = this.context.filesDir;
    const filePath = `${filesDir}/gps_data.json`;
    
    const data = {
      latitude: latitude,
      longitude: longitude,
      timestamp: Date.now(),
      latitudeDMS: toDMS(latitude, CoordinateType.LATITUDE),
      longitudeDMS: toDMS(longitude, CoordinateType.LONGITUDE)
    };
    
    const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(file.fd, JSON.stringify(data, null, 2));
    fileIo.closeSync(file);
    
    console.log('Location saved to file: ' + filePath);
  } catch (err) {
    console.error('Failed to save location to file: ' + JSON.stringify(err));
  }
}
```

### Option 3: Save Multiple Locations (Location History)

```typescript
import { relationalStore } from '@kit.ArkData';

// Create database and table
async initDatabase(): Promise<void> {
  const config: relationalStore.StoreConfig = {
    name: 'LocationDatabase.db',
    securityLevel: relationalStore.SecurityLevel.S1
  };
  
  const store = await relationalStore.getRdbStore(this.context, config);
  
  const CREATE_TABLE = `CREATE TABLE IF NOT EXISTS locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    altitude REAL,
    accuracy REAL,
    timestamp INTEGER NOT NULL
  )`;
  
  await store.executeSql(CREATE_TABLE);
}

// Insert location record
async saveLocationToDatabase(result: geoLocationManager.Location): Promise<void> {
  const config: relationalStore.StoreConfig = {
    name: 'LocationDatabase.db',
    securityLevel: relationalStore.SecurityLevel.S1
  };
  
  const store = await relationalStore.getRdbStore(this.context, config);
  
  const valueBucket: relationalStore.ValuesBucket = {
    'latitude': result.latitude,
    'longitude': result.longitude,
    'altitude': result.altitude,
    'accuracy': result.accuracy,
    'timestamp': result.timeStamp
  };
  
  await store.insert('locations', valueBucket);
  console.log('Location saved to database');
}
```

## Location Request Configuration Options

### Priority Settings

```typescript
// For fastest response (uses cached location if available)
locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED

// For most accurate location (may take longer)
locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_ACCURACY

// Balanced accuracy and speed
locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_BALANCE_POWER_ACCURACY
```

### Timeout Configuration

```typescript
let request: geoLocationManager.SingleLocationRequest = {
  'locatingPriority': geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
  'locatingTimeoutMs': 10000  // 10 seconds (adjustable based on needs)
}
```

## Continuous Location Updates

For tracking location continuously (e.g., fitness tracking):

```typescript
startContinuousLocation(): void {
  const config: geoLocationManager.LocationRequest = {
    priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
    scenario: geoLocationManager.LocationRequestScenario.UNSET,
    timeInterval: 1,  // Update every 1 second
    distanceInterval: 0,  // Update for any distance change
    maxAccuracy: 0
  };

  try {
    geoLocationManager.on('locationChange', config, (location) => {
      console.log('Location update: ' + JSON.stringify(location));
      // Save or process location data here
    });
  } catch (err) {
    console.error('Failed to start location updates: ' + JSON.stringify(err));
  }
}

stopContinuousLocation(): void {
  try {
    geoLocationManager.off('locationChange');
    console.log('Stopped location updates');
  } catch (err) {
    console.error('Failed to stop location updates: ' + JSON.stringify(err));
  }
}
```

## Best Practices

1. **Permission Handling**: Always request permissions before attempting to access location services
2. **Check Location Services**: Verify location services are enabled before requesting coordinates
3. **Error Handling**: Implement robust error handling for location requests (timeout, denied permissions, etc.)
4. **Battery Efficiency**: Use appropriate priority settings and update intervals to balance accuracy with battery consumption
5. **User Privacy**: Only request location when necessary and inform users why location access is needed
6. **Coordinate Format**: Store coordinates in decimal degrees for calculations; convert to DMS only for display
7. **Data Persistence**: Choose appropriate storage method based on use case:
   - Preferences: Single/latest location
   - File System: Structured data with metadata
   - Database: Location history with query capabilities

## Common Issues and Solutions

### Issue: Location Request Times Out
- **Solution**: Ensure GPS has clear sky view; increase timeout value; check device location settings

### Issue: Permissions Denied
- **Solution**: Implement proper permission request flow; guide users to app settings if needed

### Issue: Inaccurate Coordinates
- **Solution**: Use `PRIORITY_ACCURACY` priority; wait for better accuracy value in result; filter out low-accuracy readings

### Issue: High Battery Consumption
- **Solution**: Use appropriate update intervals; stop location updates when not needed; use lower priority settings

## Testing on Wearables

1. Test on actual wearable device for accurate GPS performance
2. Emulator may not provide realistic GPS behavior
3. GPS performance varies based on watch model and GPS hardware
4. Indoor testing may result in poor or no GPS signal

## Summary

This implementation provides:
- ✅ Location permission request and management
- ✅ GPS coordinate retrieval from wearable devices
- ✅ Coordinate format conversion (decimal ↔ DMS)
- ✅ Multiple data persistence options
- ✅ Continuous location tracking capability
- ✅ Error handling and best practices

Use this guide as a reference to implement GPS functionality in any HarmonyOS wearable application without needing context from the original project.
