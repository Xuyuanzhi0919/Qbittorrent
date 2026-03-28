import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { PreferencesStore } from '../store/PreferencesStore';
import { resourceManager } from '@kit.LocalizationKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode: %{public}s', JSON.stringify(err));
    }
    PreferencesStore.getInstance().init(this.context);
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    this.mainWindow = windowStage.getMainWindowSync();
    this.enableImmersiveLayout();
    this.updateSystemBarColor();

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }

  onConfigurationChange(newConfig: Configuration): void {
    this.updateSystemBarColor();
  }

  private updateSystemBarColor(): void {
    if (this.mainWindow === null) {
      return;
    }
    const config: resourceManager.Configuration = this.context.resourceManager.getConfigurationSync();
    const colorMode: number = config.colorMode;
    const isDark: boolean = colorMode === resourceManager.ColorMode.DARK;
    const bgColor: string = '#00000000';
    const contentColor: string = isDark ? '#E5E5E5' : '#182431';
    const sysBarProps: window.SystemBarProperties = {
      statusBarColor: bgColor,
      statusBarContentColor: contentColor,
      navigationBarColor: bgColor,
      navigationBarContentColor: contentColor,
    };
    try {
      this.mainWindow.setWindowSystemBarProperties(sysBarProps);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'setWindowSystemBarProperties failed: %{public}s', JSON.stringify(err));
    }
  }

  private enableImmersiveLayout(): void {
    if (this.mainWindow === null) {
      return;
    }
    try {
      this.mainWindow.setWindowLayoutFullScreen(true);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(err));
    }
  }
}
