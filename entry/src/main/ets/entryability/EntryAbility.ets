import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { MonitoringService } from '../services/MonitoringService';
import { AppConfig } from '../config/AppConfig';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private monitoringService: MonitoringService | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    
    // Initialize MonitoringService with context
    this.monitoringService = MonitoringService.getInstance();
    this.monitoringService.initialize(this.context);
    hilog.info(DOMAIN, 'testTag', 'MonitoringService initialized with context');
    
    // Auto-start monitoring if configured
    if (AppConfig.AUTO_START_MONITORING) {
      this.monitoringService.startMonitoring();
      hilog.info(DOMAIN, 'testTag', 'Auto-started monitoring');
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    
    // Cleanup MonitoringService
    if (this.monitoringService !== null) {
      this.monitoringService.destroy();
      this.monitoringService = null;
      hilog.info(DOMAIN, 'testTag', 'MonitoringService destroyed');
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    
    // Resume monitoring if it was active
    if (this.monitoringService !== null) {
      const state = this.monitoringService.getState();
      if (state.monitoringStartTime > 0 && !this.monitoringService.getState().status.includes('monitoring')) {
        // Monitoring was active but paused, resume it
        hilog.info(DOMAIN, 'testTag', 'Resuming monitoring on foreground');
      }
    }
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    
    // Keep monitoring in background (requires KEEP_BACKGROUND_RUNNING permission)
    // Monitoring continues to detect freezes and send alerts
    hilog.info(DOMAIN, 'testTag', 'Monitoring continues in background');
  }
}