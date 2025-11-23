import { AbilityConstant, ConfigurationConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { MonitoringService } from '../services/MonitoringService';
import { AppConfig } from '../config/AppConfig';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private monitoringService: MonitoringService | null = null;
  private static currentInstance: EntryAbility | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    EntryAbility.currentInstance = this;
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
    // Monitoring continues via continuous task
  }

  // Background service functionality removed - using continuous tasks instead

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
    // Main window is destroyed, but keep monitoring in background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy - keeping monitoring active');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    
    // Ensure monitoring is active
    if (this.monitoringService !== null && AppConfig.AUTO_START_MONITORING) {
      const state = this.monitoringService.getState();
      if (state.monitoringStartTime === 0) {
        // Monitoring not started, start it now
        this.monitoringService.startMonitoring();
        hilog.info(DOMAIN, 'testTag', 'Started monitoring on foreground');
      } else {
        hilog.info(DOMAIN, 'testTag', 'Monitoring already active');
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