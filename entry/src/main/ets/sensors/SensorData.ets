/**
 * SensorData types and interfaces for Parkinson's freeze detection
 */

// Sensor reading interfaces
export interface AccelerometerData {
  x: number;
  y: number;
  z: number;
  timestamp: number;
}

export interface GyroscopeData {
  x: number;
  y: number;
  z: number;
  timestamp: number;
}

export interface HeartRateData {
  bpm: number;
  timestamp: number;
  variability?: number; // For detecting pulse spikes
}

// Tremor detection result (processed data only, no raw sensor data)
export interface TremorEvent {
  severity: number; // 0-10 scale
  duration: number; // milliseconds
  timestamp: number;
}

// GPS coordinate data
export interface GPSCoordinates {
  latitude: number; // Decimal degrees (-90 to 90)
  longitude: number; // Decimal degrees (-180 to 180)
  altitude?: number; // Meters above sea level
  accuracy?: number; // Horizontal accuracy in meters
  timestamp: number; // Unix timestamp in milliseconds
}

// Freeze prediction result
export interface FreezeIndicators {
  tremor: boolean;
  gaitDisturbance: boolean;
  stressSpike: boolean;
}

export interface FreezePrediction {
  probability: number; // 0-1 scale
  timeToFreeze?: number; // milliseconds until predicted freeze
  timestamp: number;
  confidence: number; // 0-1 scale
  indicators: FreezeIndicators;
  gpsCoordinates?: GPSCoordinates; // GPS location when freeze detected (only for freezes)
}

// Monitoring status
export enum MonitoringStatus {
  STOPPED = 'stopped',
  MONITORING = 'monitoring',
  ALERT = 'alert',
  ERROR = 'error'
}

// Application state for UI
export class AppState {
  status: MonitoringStatus = MonitoringStatus.STOPPED;
  currentAccel: AccelerometerData | null = null;
  currentGyro: GyroscopeData | null = null;
  currentHeartRate: HeartRateData | null = null;
  latestPrediction: FreezePrediction | null = null;
  latestTremor: TremorEvent | null = null;
  errorMessage: string = '';
  
  // Statistics
  totalTremorsDetected: number = 0;
  totalFreezesDetected: number = 0;
  monitoringStartTime: number = 0;
}
