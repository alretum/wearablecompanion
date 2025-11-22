/**
 * DataCollectionLogger - Comprehensive data collection for testing
 * 
 * This service collects ALL sensor data and events for analysis.
 * Used in the datacollection2 branch for testing purposes.
 * 
 * Data collected:
 * - Raw accelerometer readings (x, y, z, timestamp)
 * - Raw gyroscope readings (x, y, z, timestamp)
 * - Heart rate readings (bpm, timestamp, variability)
 * - Tremor events (severity, duration, timestamp)
 * - Freeze predictions (probability, confidence, indicators, timestamp)
 * - GPS coordinates (latitude, longitude, altitude, accuracy, timestamp)
 */

import { fileIo } from '@kit.CoreFileKit';
import { 
  AccelerometerData, 
  GyroscopeData, 
  HeartRateData,
  TremorEvent,
  FreezePrediction,
  GPSCoordinates
} from '../sensors/SensorData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0008;
const TAG = 'DataCollectionLogger';

export interface DataCollectionReport {
  sessionId: string;
  userId: string;
  deviceId: string;
  sessionStart: number;
  sessionEnd: number;
  
  // Raw sensor data arrays
  accelerometerData: AccelerometerData[];
  gyroscopeData: GyroscopeData[];
  heartRateData: HeartRateData[];
  
  // Processed events
  tremorEvents: TremorEvent[];
  freezePredictions: FreezePrediction[];
  
  // GPS data
  gpsCoordinates: GPSCoordinates[];
  
  // Statistics
  totalAccelReadings: number;
  totalGyroReadings: number;
  totalHeartRateReadings: number;
  totalTremors: number;
  totalFreezes: number;
  totalGPSReadings: number;
  
  lastUpdated: number;
}

export class DataCollectionLogger {
  private static readonly COLLECTION_FILENAME = 'data_collection.json';
  private collectionFilePath: string = '';
  private currentCollection: DataCollectionReport | null = null;
  private context: common.UIAbilityContext;
  
  // Batch size limits to prevent memory overflow
  private static readonly MAX_ACCEL_READINGS = 5000; // ~100 seconds at 50Hz
  private static readonly MAX_GYRO_READINGS = 5000;
  private static readonly MAX_HR_READINGS = 500; // ~8 minutes at 1Hz
  private static readonly MAX_GPS_READINGS = 100;

  constructor(context: common.UIAbilityContext, userId: string, deviceId: string) {
    this.context = context;
    this.collectionFilePath = `${context.filesDir}/${DataCollectionLogger.COLLECTION_FILENAME}`;
    hilog.info(DOMAIN, TAG, `Data collection file path: ${this.collectionFilePath}`);
    
    // Initialize new collection session
    this.currentCollection = {
      sessionId: `DATA_COLLECTION_${Date.now()}`,
      userId: userId,
      deviceId: deviceId,
      sessionStart: Date.now(),
      sessionEnd: 0,
      accelerometerData: [],
      gyroscopeData: [],
      heartRateData: [],
      tremorEvents: [],
      freezePredictions: [],
      gpsCoordinates: [],
      totalAccelReadings: 0,
      totalGyroReadings: 0,
      totalHeartRateReadings: 0,
      totalTremors: 0,
      totalFreezes: 0,
      totalGPSReadings: 0,
      lastUpdated: Date.now()
    };
    
    this.saveCollection();
    hilog.info(DOMAIN, TAG, 'Data collection initialized');
  }

  /**
   * Log accelerometer reading
   * Returns true if data was saved to file
   */
  public logAccelerometer(data: AccelerometerData): boolean {
    if (!this.currentCollection) return false;
    
    // Add to array
    this.currentCollection.accelerometerData.push(data);
    this.currentCollection.totalAccelReadings++;
    
    // Trim if exceeds limit
    if (this.currentCollection.accelerometerData.length > DataCollectionLogger.MAX_ACCEL_READINGS) {
      this.currentCollection.accelerometerData.shift();
    }
    
    this.currentCollection.lastUpdated = Date.now();
    
    // Save periodically (every 100 readings to reduce I/O)
    if (this.currentCollection.totalAccelReadings % 100 === 0) {
      this.saveCollection();
      hilog.debug(DOMAIN, TAG, `Accelerometer: ${this.currentCollection.totalAccelReadings} readings`);
      return true; // Data was saved
    }
    return false; // Data not yet saved
  }

  /**
   * Log gyroscope reading
   * Returns true if data was saved to file
   */
  public logGyroscope(data: GyroscopeData): boolean {
    if (!this.currentCollection) return false;
    
    this.currentCollection.gyroscopeData.push(data);
    this.currentCollection.totalGyroReadings++;
    
    if (this.currentCollection.gyroscopeData.length > DataCollectionLogger.MAX_GYRO_READINGS) {
      this.currentCollection.gyroscopeData.shift();
    }
    
    this.currentCollection.lastUpdated = Date.now();
    
    if (this.currentCollection.totalGyroReadings % 100 === 0) {
      this.saveCollection();
      hilog.debug(DOMAIN, TAG, `Gyroscope: ${this.currentCollection.totalGyroReadings} readings`);
      return true; // Data was saved
    }
    return false; // Data not yet saved
  }

  /**
   * Log heart rate reading
   */
  public logHeartRate(data: HeartRateData): void {
    if (!this.currentCollection) return;
    
    this.currentCollection.heartRateData.push(data);
    this.currentCollection.totalHeartRateReadings++;
    
    if (this.currentCollection.heartRateData.length > DataCollectionLogger.MAX_HR_READINGS) {
      this.currentCollection.heartRateData.shift();
    }
    
    this.currentCollection.lastUpdated = Date.now();
    this.saveCollection();
    
    hilog.debug(DOMAIN, TAG, `Heart rate: ${data.bpm} BPM`);
  }

  /**
   * Log tremor event
   */
  public logTremor(tremor: TremorEvent): void {
    if (!this.currentCollection) return;
    
    this.currentCollection.tremorEvents.push(tremor);
    this.currentCollection.totalTremors++;
    this.currentCollection.lastUpdated = Date.now();
    this.saveCollection();
    
    hilog.info(DOMAIN, TAG, `Activity logged: status=${tremor.status}, magnitude=${tremor.magnitude.toFixed(2)}, frequency=${tremor.frequency.toFixed(2)}Hz, total=${this.currentCollection.totalTremors}`);
  }

  /**
   * Log freeze prediction
   */
  public logFreezePrediction(prediction: FreezePrediction): void {
    if (!this.currentCollection) return;
    
    this.currentCollection.freezePredictions.push(prediction);
    this.currentCollection.totalFreezes++;
    this.currentCollection.lastUpdated = Date.now();
    this.saveCollection();
    
    hilog.info(DOMAIN, TAG, `Freeze logged: probability=${prediction.probability.toFixed(2)}, total=${this.currentCollection.totalFreezes}`);
  }

  /**
   * Log GPS coordinates
   */
  public logGPS(gps: GPSCoordinates): void {
    if (!this.currentCollection) return;
    
    this.currentCollection.gpsCoordinates.push(gps);
    this.currentCollection.totalGPSReadings++;
    
    if (this.currentCollection.gpsCoordinates.length > DataCollectionLogger.MAX_GPS_READINGS) {
      this.currentCollection.gpsCoordinates.shift();
    }
    
    this.currentCollection.lastUpdated = Date.now();
    this.saveCollection();
    
    hilog.debug(DOMAIN, TAG, `GPS: ${gps.latitude.toFixed(6)}, ${gps.longitude.toFixed(6)}`);
  }

  /**
   * Save collection to JSON file
   */
  private saveCollection(): void {
    if (!this.currentCollection) return;

    try {
      // Update session end time
      this.currentCollection.sessionEnd = Date.now();

      // Convert to JSON
      const jsonContent = JSON.stringify(this.currentCollection, null, 2);

      // Write to file
      const file = fileIo.openSync(this.collectionFilePath, 
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, jsonContent);
      fileIo.closeSync(file);

      hilog.debug(DOMAIN, TAG, `Collection saved: ${this.currentCollection.accelerometerData.length} accel, ${this.currentCollection.gyroscopeData.length} gyro, ${this.currentCollection.heartRateData.length} HR`);
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to save collection: ${error}`);
    }
  }

  /**
   * Get current collection data
   */
  public getCollection(): DataCollectionReport | null {
    return this.currentCollection;
  }

  /**
   * Get collection as JSON string
   */
  public getCollectionJSON(): string {
    if (!this.currentCollection) return '{}';
    return JSON.stringify(this.currentCollection, null, 2);
  }

  /**
   * Read collection from file
   */
  public readCollection(): DataCollectionReport | null {
    try {
      if (!fileIo.accessSync(this.collectionFilePath)) {
        hilog.warn(DOMAIN, TAG, 'Collection file does not exist');
        return null;
      }

      const file = fileIo.openSync(this.collectionFilePath, fileIo.OpenMode.READ_ONLY);
      const content = new ArrayBuffer(10 * 1024 * 1024); // 10MB buffer for large data
      const readLen = fileIo.readSync(file.fd, content);
      fileIo.closeSync(file);

      const jsonString = String.fromCharCode(...new Uint8Array(content.slice(0, readLen)));
      const collection = JSON.parse(jsonString) as DataCollectionReport;

      hilog.info(DOMAIN, TAG, `Collection loaded: ${collection.totalAccelReadings} accel readings`);
      return collection;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to read collection: ${error}`);
      return null;
    }
  }

  /**
   * Clear all collected data
   */
  public clearCollection(): void {
    if (!this.currentCollection) return;

    this.currentCollection.accelerometerData = [];
    this.currentCollection.gyroscopeData = [];
    this.currentCollection.heartRateData = [];
    this.currentCollection.tremorEvents = [];
    this.currentCollection.freezePredictions = [];
    this.currentCollection.gpsCoordinates = [];
    
    this.saveCollection();
    hilog.info(DOMAIN, TAG, 'Collection data cleared');
  }

  /**
   * Get statistics summary
   */
  public getStats(): string {
    if (!this.currentCollection) return 'No collection active';

    const duration = (this.currentCollection.sessionEnd - this.currentCollection.sessionStart) / 1000;
    
    return `Data Collection Stats:
Session: ${this.currentCollection.sessionId}
Duration: ${duration.toFixed(0)}s
Accelerometer: ${this.currentCollection.totalAccelReadings} readings (${this.currentCollection.accelerometerData.length} in memory)
Gyroscope: ${this.currentCollection.totalGyroReadings} readings (${this.currentCollection.gyroscopeData.length} in memory)
Heart Rate: ${this.currentCollection.totalHeartRateReadings} readings (${this.currentCollection.heartRateData.length} in memory)
Tremors: ${this.currentCollection.totalTremors}
Freezes: ${this.currentCollection.totalFreezes}
GPS: ${this.currentCollection.totalGPSReadings} readings (${this.currentCollection.gpsCoordinates.length} in memory)`;
  }

  /**
   * Export collection to a backup file
   */
  public exportToBackup(): string {
    if (!this.currentCollection) return '';
    
    const backupFilename = `data_collection_backup_${Date.now()}.json`;
    const backupPath = `${this.context.filesDir}/${backupFilename}`;
    
    try {
      const jsonContent = JSON.stringify(this.currentCollection, null, 2);
      const file = fileIo.openSync(backupPath, 
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, jsonContent);
      fileIo.closeSync(file);
      
      hilog.info(DOMAIN, TAG, `Backup created: ${backupPath}`);
      return backupPath;
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to create backup: ${error}`);
      return '';
    }
  }
}
