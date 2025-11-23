/**
 * APIService - Handles communication with AWS Lambda functions
 * 
 * TODO: Replace endpoint URLs in AppConfig.ets with your actual AWS API Gateway endpoints
 * 
 * Expected Lambda functions:
 * 1. /tremor-report - POST tremor event data for doctor reports
 * 2. /freeze-alert - POST freeze prediction alerts
 * 3. /sync-data - POST periodic sync of all monitoring data
 */

import { http } from '@kit.NetworkKit';
import { TremorEvent, FreezePrediction } from '../sensors/SensorData';
import { HeartRateReport } from '../services/HeartRateLogger';
import { AppConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { APILogger, APILogStats } from '../services/APILogger';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0004;
const TAG = 'APIService';

interface HttpHeaders {
  'Content-Type': string;
  'Accept'?: string;
  'x-api-key'?: string;
}

interface HttpResponseData {
  success?: boolean;
  reportId?: string;
  alertId?: string;
  syncId?: string;
  message?: string;
}

export interface ConnectivityResults {
  tremorReport: boolean;
  freezeAlert: boolean;
  syncData: boolean;
}

interface EndpointMap {
  tremorReport: string;
  freezeAlert: string;
  syncData: string;
}

export interface TremorReportPayload {
  userId: string; // TODO: Add user authentication
  deviceId: string;
  tremors: TremorEvent[];
  timestamp: number;
}

export interface FreezeAlertPayload {
  userId: string; // TODO: Add user authentication
  deviceId: string;
  prediction: FreezePrediction;
  timestamp: number;
}

export interface SyncDataPayloadData {
  tremors: TremorEvent[];
  predictions: FreezePrediction[];
}

export interface SyncDataPayload {
  userId: string; // TODO: Add user authentication
  deviceId: string;
  sessionStart: number;
  sessionEnd: number;
  totalTremors: number;
  totalFreezes: number;
  data: SyncDataPayloadData;
}

export interface TremorDataPayload {
  status: string;
  magnitude: number;
  frequency: number;
}

export interface HeartRateMinuteData {
  timestamp: string;
  avgBpm: number;
  minBpm: number;
  maxBpm: number;
  tremorData?: TremorDataPayload | null;
}

export interface HeartRateUploadPayload {
  userId: string;
  deviceId: string;
  reportTimestamp: string;
  minuteData: HeartRateMinuteData[];
}

export interface MedicationIntakePayload {
  userId: string;
  deviceId: string;
  medicationTime: string;
}

export interface EmergencyCallLocation {
  lat: number;
  lng: number;
}

export interface EmergencyCallPayload {
  phone: string;
  incident_id: string;
  user_id: string;
  severity: number;
  confidence: number;
  location: EmergencyCallLocation;
}

export class APIService {
  private deviceId: string;
  private userId: string; // TODO: Implement user authentication
  private apiLogger: APILogger | null = null;

  constructor() {
    // TODO: Get actual device ID and user ID from authentication system
    this.deviceId = 'DEVICE_' + Date.now(); // Placeholder
    this.userId = 'USER_PLACEHOLDER'; // Replace with actual user ID
    hilog.info(DOMAIN, TAG, 'APIService initialized');
  }

  /**
   * Initialize API logger with context
   */
  public initializeLogger(context: common.UIAbilityContext, userId: string, deviceId: string): void {
    this.apiLogger = new APILogger(context, userId, deviceId);
    hilog.info(DOMAIN, TAG, 'API logger initialized');
  }

  /**
   * Send tremor report to AWS Lambda for doctor review
   * Endpoint: POST /tremor-report
   * 
   * Expected Lambda response:
   * {
   *   "success": boolean,
   *   "reportId": string,
   *   "message": string
   * }
   */
  public async sendTremorReport(tremors: TremorEvent[]): Promise<boolean> {
    if (tremors.length === 0) {
      hilog.warn(DOMAIN, TAG, 'No tremors to report');
      return true;
    }

    const payload: TremorReportPayload = {
      userId: this.userId,
      deviceId: this.deviceId,
      tremors: tremors,
      timestamp: Date.now()
    };

    try {
      hilog.info(DOMAIN, TAG, `Sending ${tremors.length} tremor(s) to server`);
      
      const response = await this.sendRequest(
        AppConfig.TREMOR_REPORT_ENDPOINT,
        http.RequestMethod.POST,
        payload
      );

      hilog.info(DOMAIN, TAG, `Tremor report sent successfully: ${JSON.stringify(response)}`);
      return true;

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to send tremor report: ${error}`);
      return false;
    }
  }

  /**
   * Send freeze prediction alert to AWS Lambda
   * Endpoint: POST /freeze-alert
   * 
   * Expected Lambda response:
   * {
   *   "success": boolean,
   *   "alertId": string,
   *   "message": string
   * }
   */
  public async sendFreezeAlert(prediction: FreezePrediction): Promise<boolean> {
    const payload: FreezeAlertPayload = {
      userId: this.userId,
      deviceId: this.deviceId,
      prediction: prediction,
      timestamp: Date.now()
    };

    try {
      hilog.info(DOMAIN, TAG, `Sending freeze alert (probability: ${prediction.probability.toFixed(2)})`);
      
      const response = await this.sendRequest(
        AppConfig.FREEZE_ALERT_ENDPOINT,
        http.RequestMethod.POST,
        payload
      );

      hilog.info(DOMAIN, TAG, `Freeze alert sent successfully: ${JSON.stringify(response)}`);
      return true;

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to send freeze alert: ${error}`);
      return false;
    }
  }

  /**
   * Upload report.json file to AWS Lambda for analysis
   * Endpoint: POST /upload-report
   * 
   * This sends the entire report.json file containing all tremors and freeze predictions
   */
  public async syncReportFile(reportJSON: string): Promise<boolean> {
    try {
      const report = JSON.parse(reportJSON) as Object;
      hilog.info(DOMAIN, TAG, `Uploading report file`);
      
      const response = await this.sendRequest(
        AppConfig.SYNC_DATA_ENDPOINT,
        http.RequestMethod.POST,
        report
      );

      // Log successful API call
      this.apiLogger?.logAPICall(
        AppConfig.SYNC_DATA_ENDPOINT,
        'POST',
        report,
        true,
        200,
        JSON.stringify(response)
      );

      hilog.info(DOMAIN, TAG, `Report uploaded successfully: ${JSON.stringify(response)}`);
      return true;

    } catch (error) {
      // Log failed API call
      const report = JSON.parse(reportJSON) as Object;
      this.apiLogger?.logAPICall(
        AppConfig.SYNC_DATA_ENDPOINT,
        'POST',
        report,
        false,
        undefined,
        undefined,
        String(error)
      );

      hilog.error(DOMAIN, TAG, `Failed to upload report: ${error}`);
      return false;
    }
  }

  /**
   * Upload heart rate report to Supabase function
   * Endpoint: POST /upload-heartrate
   * 
   * This sends 5 minutes of aggregated heart rate data (1 entry per minute)
   * Each minute includes tremor/activity data if available
   */
  public async uploadHeartRateReport(report: HeartRateReport): Promise<boolean> {
    // Transform report to match API format (including tremor data)
    const payload: HeartRateUploadPayload = {
      userId: report.userId,
      deviceId: report.deviceId,
      reportTimestamp: new Date(report.reportTimestamp).toISOString(),
      minuteData: report.minutes.map((minute): HeartRateMinuteData => {
        const tremorPayload: TremorDataPayload | null = minute.tremorData ? {
          status: minute.tremorData.status,
          magnitude: minute.tremorData.magnitude,
          frequency: minute.tremorData.frequency
        } : null;
        
        return {
          timestamp: new Date(minute.timestamp).toISOString(),
          avgBpm: minute.avgBpm,
          minBpm: minute.minBpm,
          maxBpm: minute.maxBpm,
          tremorData: tremorPayload
        };
      })
    };

    try {
      hilog.info(DOMAIN, TAG, `Uploading heart rate report with ${report.minutes.length} minutes of data`);
      
      const response = await this.sendHeartRateRequest(
        AppConfig.HEART_RATE_ENDPOINT,
        http.RequestMethod.POST,
        payload
      );

      // Log successful API call
      this.apiLogger?.logAPICall(
        AppConfig.HEART_RATE_ENDPOINT,
        'POST',
        payload,
        true,
        200,
        JSON.stringify(response)
      );

      hilog.info(DOMAIN, TAG, `Heart rate report uploaded successfully: ${JSON.stringify(response)}`);
      return true;

    } catch (error) {
      // Log failed API call
      this.apiLogger?.logAPICall(
        AppConfig.HEART_RATE_ENDPOINT,
        'POST',
        payload,
        false,
        undefined,
        undefined,
        String(error)
      );

      hilog.error(DOMAIN, TAG, `Failed to upload heart rate report: ${error}`);
      return false;
    }
  }

  /**
   * Record medication intake event
   * Endpoint: POST /medication-intake
   * 
   * Sends a timestamp when the user takes their medication
   */
  public async recordMedicationIntake(): Promise<boolean> {
    const payload: MedicationIntakePayload = {
      userId: this.userId,
      deviceId: this.deviceId,
      medicationTime: new Date().toISOString()
    };

    try {
      hilog.info(DOMAIN, TAG, 'Recording medication intake');
      
      const response = await this.sendHeartRateRequest(
        AppConfig.MEDICATION_INTAKE_ENDPOINT,
        http.RequestMethod.POST,
        payload
      );

      // Log successful API call
      this.apiLogger?.logAPICall(
        AppConfig.MEDICATION_INTAKE_ENDPOINT,
        'POST',
        payload,
        true,
        200,
        JSON.stringify(response)
      );

      hilog.info(DOMAIN, TAG, `Medication intake recorded successfully: ${JSON.stringify(response)}`);
      return true;

    } catch (error) {
      // Log failed API call
      this.apiLogger?.logAPICall(
        AppConfig.MEDICATION_INTAKE_ENDPOINT,
        'POST',
        payload,
        false,
        undefined,
        undefined,
        String(error)
      );

      hilog.error(DOMAIN, TAG, `Failed to record medication intake: ${error}`);
      return false;
    }
  }

  /**
   * Trigger emergency phone call via Supabase Edge Function
   * Endpoint: POST /call-me
   * 
   * @param incidentId - Unique incident identifier
   * @returns Promise<boolean> - Success status
   */
  public async sendEmergencyCall(incidentId: string): Promise<boolean> {
    const location: EmergencyCallLocation = {
      lat: AppConfig.EMERGENCY_LOCATION.lat,
      lng: AppConfig.EMERGENCY_LOCATION.lng
    };

    const payload: EmergencyCallPayload = {
      phone: AppConfig.EMERGENCY_PHONE_NUMBER,
      incident_id: incidentId,
      user_id: this.userId,
      severity: 0.85,
      confidence: 0.92,
      location: location
    };

    try {
      hilog.info(DOMAIN, TAG, `🚨 Triggering emergency call for incident: ${incidentId}`);
      hilog.info(DOMAIN, TAG, `Calling: ${payload.phone}`);

      const response = await this.sendHeartRateRequest(
        AppConfig.EMERGENCY_CALL_ENDPOINT,
        http.RequestMethod.POST,
        payload
      );

      // Log successful API call
      this.apiLogger?.logAPICall(
        AppConfig.EMERGENCY_CALL_ENDPOINT,
        'POST',
        payload,
        true,
        200,
        JSON.stringify(response)
      );

      hilog.info(DOMAIN, TAG, `✅ Emergency call triggered successfully: ${JSON.stringify(response)}`);
      return true;

    } catch (error) {
      // Log failed API call
      this.apiLogger?.logAPICall(
        AppConfig.EMERGENCY_CALL_ENDPOINT,
        'POST',
        payload,
        false,
        undefined,
        undefined,
        String(error)
      );

      hilog.error(DOMAIN, TAG, `❌ Failed to trigger emergency call: ${error}`);
      return false;
    }
  }

  /**
   * Sync all monitoring data to AWS Lambda for analysis (Legacy method)
   * Endpoint: POST /sync-data
   * 
   * Expected Lambda response:
   * {
   *   "success": boolean,
   *   "syncId": string,
   *   "message": string
   * }
   */
  public async syncData(
    sessionStart: number,
    sessionEnd: number,
    totalTremors: number,
    totalFreezes: number,
    tremors: TremorEvent[],
    predictions: FreezePrediction[]
  ): Promise<boolean> {
    const payload: SyncDataPayload = {
      userId: this.userId,
      deviceId: this.deviceId,
      sessionStart: sessionStart,
      sessionEnd: sessionEnd,
      totalTremors: totalTremors,
      totalFreezes: totalFreezes,
      data: {
        tremors: tremors,
        predictions: predictions
      }
    };

    try {
      hilog.info(DOMAIN, TAG, 'Syncing data to server');
      
      const response = await this.sendRequest(
        AppConfig.SYNC_DATA_ENDPOINT,
        http.RequestMethod.POST,
        payload
      );

      hilog.info(DOMAIN, TAG, `Data sync successful: ${JSON.stringify(response)}`);
      return true;

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to sync data: ${error}`);
      return false;
    }
  }

  /**
   * Specialized HTTP request handler for heart rate endpoint with custom headers
   */
  private async sendHeartRateRequest(
    url: string,
    method: http.RequestMethod,
    data?: Object
  ): Promise<HttpResponseData> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();

      const headers: HttpHeaders = {
        'Content-Type': 'application/json',
        'x-api-key': 'ParkinsonAtHackatum'
      };

      const requestOptions: http.HttpRequestOptions = {
        method: method,
        header: headers,
        extraData: data ? JSON.stringify(data) : undefined,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 10000
      };

      httpRequest.request(url, requestOptions, (err: Error, data: http.HttpResponse) => {
        if (err) {
          hilog.error(DOMAIN, TAG, `HTTP request failed: ${JSON.stringify(err)}`);
          httpRequest.destroy();
          reject(err);
          return;
        }

        if (data.responseCode !== 200) {
          const errorMsg = `HTTP ${data.responseCode}: ${data.result}`;
          hilog.error(DOMAIN, TAG, errorMsg);
          httpRequest.destroy();
          reject(new Error(errorMsg));
          return;
        }

        try {
          const response = JSON.parse(data.result as string) as HttpResponseData;
          httpRequest.destroy();
          resolve(response);
        } catch (parseError) {
          hilog.error(DOMAIN, TAG, `Failed to parse response: ${parseError}`);
          httpRequest.destroy();
          reject(parseError);
        }
      });
    });
  }

  /**
   * Generic HTTP request handler
   * TODO: Add authentication headers (JWT, API key, etc.)
   */
  private async sendRequest(
    url: string,
    method: http.RequestMethod,
    data?: TremorReportPayload | FreezeAlertPayload | SyncDataPayload | HeartRateReport | Object
  ): Promise<HttpResponseData> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();

      // TODO: Add authentication headers
      const headers: HttpHeaders = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
        // Add your authentication headers here
        // 'Authorization': `Bearer ${this.getAuthToken()}`,
        // 'X-API-Key': 'your-api-key',
      };

      const requestOptions: http.HttpRequestOptions = {
        method: method,
        header: headers,
        extraData: data ? JSON.stringify(data) : undefined,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 10000
      };

      httpRequest.request(url, requestOptions, (err: Error, data: http.HttpResponse) => {
        if (err) {
          hilog.error(DOMAIN, TAG, `HTTP request failed: ${JSON.stringify(err)}`);
          httpRequest.destroy();
          reject(err);
          return;
        }

        if (data.responseCode !== 200) {
          const errorMsg = `HTTP ${data.responseCode}: ${data.result}`;
          hilog.error(DOMAIN, TAG, errorMsg);
          httpRequest.destroy();
          reject(new Error(errorMsg));
          return;
        }

        try {
          const response = JSON.parse(data.result as string) as HttpResponseData;
          httpRequest.destroy();
          resolve(response);
        } catch (parseError) {
          hilog.error(DOMAIN, TAG, `Failed to parse response: ${parseError}`);
          httpRequest.destroy();
          reject(parseError);
        }
      });
    });
  }

  /**
   * Test connectivity to AWS endpoints
   * Useful for debugging and setup validation
   */
  public async testConnectivity(): Promise<ConnectivityResults> {
    const results: ConnectivityResults = {
      tremorReport: false,
      freezeAlert: false,
      syncData: false
    };

    // Test each endpoint
    const endpoints: EndpointMap = {
      tremorReport: AppConfig.TREMOR_REPORT_ENDPOINT,
      freezeAlert: AppConfig.FREEZE_ALERT_ENDPOINT,
      syncData: AppConfig.SYNC_DATA_ENDPOINT
    };

    try {
      await this.sendRequest(endpoints.tremorReport, http.RequestMethod.GET);
      results.tremorReport = true;
      hilog.info(DOMAIN, TAG, 'tremorReport endpoint is reachable');
    } catch (error) {
      results.tremorReport = false;
      hilog.warn(DOMAIN, TAG, `tremorReport endpoint is not reachable: ${error}`);
    }

    try {
      await this.sendRequest(endpoints.freezeAlert, http.RequestMethod.GET);
      results.freezeAlert = true;
      hilog.info(DOMAIN, TAG, 'freezeAlert endpoint is reachable');
    } catch (error) {
      results.freezeAlert = false;
      hilog.warn(DOMAIN, TAG, `freezeAlert endpoint is not reachable: ${error}`);
    }

    try {
      await this.sendRequest(endpoints.syncData, http.RequestMethod.GET);
      results.syncData = true;
      hilog.info(DOMAIN, TAG, 'syncData endpoint is reachable');
    } catch (error) {
      results.syncData = false;
      hilog.warn(DOMAIN, TAG, `syncData endpoint is not reachable: ${error}`);
    }

    return results;
  }

  /**
   * Update user ID (call after authentication)
   */
  public setUserId(userId: string): void {
    this.userId = userId;
    hilog.info(DOMAIN, TAG, `User ID updated: ${userId}`);
  }

  /**
   * Get API log file path
   */
  public getAPILogFilePath(): string | null {
    return this.apiLogger?.getLogFilePath() || null;
  }

  /**
   * Get API log statistics
   */
  public getAPILogStats(): APILogStats {
    if (!this.apiLogger) {
      const emptyStats: APILogStats = { total: 0, successful: 0, failed: 0 };
      return emptyStats;
    }
    return this.apiLogger.getStats();
  }
}
