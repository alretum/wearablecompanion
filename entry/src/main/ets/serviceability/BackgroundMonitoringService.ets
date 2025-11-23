/**
 * BackgroundMonitoringService - Service Extension for continuous background monitoring
 * 
 * This service runs independently of the UI and keeps monitoring active even when
 * the app is closed. It handles:
 * - Tremor detection
 * - Freeze prediction
 * - API synchronization
 * - Heart rate monitoring
 */

import { ServiceExtensionAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { rpc } from '@kit.IPCKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { MonitoringService } from '../services/MonitoringService';

const DOMAIN = 0x0009;
const TAG = 'BackgroundMonitoringService';

class MonitoringServiceStub extends rpc.RemoteObject {
  constructor(des: string) {
    super(des);
  }

  onRemoteMessageRequest(code: number, data: rpc.MessageSequence, reply: rpc.MessageSequence,
    option: rpc.MessageOption): boolean | Promise<boolean> {
    hilog.info(DOMAIN, TAG, 'onRemoteMessageRequest called, code: ' + code);
    
    if (code === 1) {
      // Start monitoring command
      hilog.info(DOMAIN, TAG, 'Start monitoring command received');
      reply.writeInt(1); // Success
    } else if (code === 2) {
      // Stop monitoring command
      hilog.info(DOMAIN, TAG, 'Stop monitoring command received');
      reply.writeInt(1); // Success
    }
    
    return true;
  }
}

export default class BackgroundMonitoringService extends ServiceExtensionAbility {
  private monitoringService: MonitoringService | null = null;
  private stub: MonitoringServiceStub | null = null;

  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'BackgroundMonitoringService onCreate');
    
    // Create stub for IPC communication
    this.stub = new MonitoringServiceStub('BackgroundMonitoringService');
    
    // Initialize monitoring service with service context
    this.monitoringService = MonitoringService.getInstance();
    this.monitoringService.initialize(this.context);
    
    // Start continuous background task
    this.startContinuousBackgroundTask();
    
    hilog.info(DOMAIN, TAG, 'BackgroundMonitoringService initialized');
  }

  onConnect(want: Want): rpc.RemoteObject | null {
    hilog.info(DOMAIN, TAG, 'BackgroundMonitoringService onConnect');
    
    // Auto-start monitoring when connected
    if (this.monitoringService !== null) {
      this.monitoringService.startMonitoring().then(() => {
        hilog.info(DOMAIN, TAG, 'Monitoring started via background service');
      }).catch((err) => {
        hilog.error(DOMAIN, TAG, 'Failed to start monitoring: ' + JSON.stringify(err));
      });
    }
    
    return this.stub;
  }

  onDisconnect(want: Want): void {
    hilog.info(DOMAIN, TAG, 'BackgroundMonitoringService onDisconnect');
    // Don't stop monitoring on disconnect - keep running in background
  }

  onRequest(want: Want, startId: number): void {
    hilog.info(DOMAIN, TAG, 'BackgroundMonitoringService onRequest, startId: ' + startId);
    
    // Start monitoring if not already started
    if (this.monitoringService !== null) {
      const state = this.monitoringService.getState();
      if (state.monitoringStartTime === 0) {
        this.monitoringService.startMonitoring().then(() => {
          hilog.info(DOMAIN, TAG, 'Monitoring started via onRequest');
        }).catch((err) => {
          hilog.error(DOMAIN, TAG, 'Failed to start monitoring: ' + JSON.stringify(err));
        });
      }
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'BackgroundMonitoringService onDestroy');
    
    // Stop monitoring and cleanup
    if (this.monitoringService !== null) {
      this.monitoringService.stopMonitoring();
    }
    
    // Stop background task
    this.stopContinuousBackgroundTask();
    
    hilog.info(DOMAIN, TAG, 'BackgroundMonitoringService destroyed');
  }

  /**
   * Start continuous background task to keep service running
   */
  private async startContinuousBackgroundTask(): Promise<void> {
    try {
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.DATA_TRANSFER,
        {
          wantAgent: undefined
        }
      );
      hilog.info(DOMAIN, TAG, 'Continuous background task started for service');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start continuous background task: ' + JSON.stringify(error));
    }
  }

  /**
   * Stop continuous background task
   */
  private stopContinuousBackgroundTask(): void {
    try {
      backgroundTaskManager.stopBackgroundRunning(this.context);
      hilog.info(DOMAIN, TAG, 'Continuous background task stopped');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to stop continuous background task: ' + JSON.stringify(error));
    }
  }
}
