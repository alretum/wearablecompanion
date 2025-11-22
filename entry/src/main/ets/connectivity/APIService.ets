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
import { AppConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0004;
const TAG = 'APIService';

interface HttpHeaders {
  'Content-Type': string;
  'Accept': string;
}

interface HttpResponseData {
  success?: boolean;
  reportId?: string;
  alertId?: string;
  syncId?: string;
  message?: string;
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

export class APIService {
  private deviceId: string;
  private userId: string; // TODO: Implement user authentication

  constructor() {
    // TODO: Get actual device ID and user ID from authentication system
    this.deviceId = 'DEVICE_' + Date.now(); // Placeholder
    this.userId = 'USER_PLACEHOLDER'; // Replace with actual user ID
    hilog.info(DOMAIN, TAG, 'APIService initialized');
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
   * Endpoint: POST /sync-data
   * 
   * This sends the entire report.json file containing all tremors and freeze predictions
   */
  public async syncReportFile(reportJSON: string): Promise<boolean> {
    try {
      const report = JSON.parse(reportJSON);
      hilog.info(DOMAIN, TAG, `Uploading report: ${report.tremors?.length || 0} tremors, ${report.freezePredictions?.length || 0} predictions`);
      
      const response = await this.sendRequest(
        AppConfig.SYNC_DATA_ENDPOINT,
        http.RequestMethod.POST,
        report
      );

      hilog.info(DOMAIN, TAG, `Report uploaded successfully: ${JSON.stringify(response)}`);
      return true;

    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to upload report: ${error}`);
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
   * Generic HTTP request handler
   * TODO: Add authentication headers (JWT, API key, etc.)
   */
  private async sendRequest(
    url: string,
    method: http.RequestMethod,
    data?: TremorReportPayload | FreezeAlertPayload | SyncDataPayload | Object
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
}
