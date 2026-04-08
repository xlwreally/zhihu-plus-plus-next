import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppearanceSettingsRepository } from '../services/AppearanceSettingsRepository';

const DOMAIN = 0x0000;
const TAG = 'ZhihuPlusNext';
const TOP_SAFE_AREA_KEY = 'topSafeAreaVp';
const BOTTOM_SAFE_AREA_KEY = 'bottomSafeAreaVp';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      AppearanceSettingsRepository.load(this.context);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to set color mode: %{public}s', JSON.stringify(error));
    }
    hilog.info(DOMAIN, TAG, 'Ability created with want: %{public}s', JSON.stringify(want));
    hilog.info(DOMAIN, TAG, 'Launch param: %{public}s', JSON.stringify(launchParam));
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      const updateSafeArea = (type: window.AvoidAreaType, area: window.AvoidArea): void => {
        if (type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate<number>(TOP_SAFE_AREA_KEY, px2vp(area.topRect.height));
          return;
        }
        if (type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate<number>(BOTTOM_SAFE_AREA_KEY, px2vp(area.bottomRect.height));
        }
      };

      mainWindow.setWindowLayoutFullScreen(true)
        .then(() => {
          return mainWindow.setWindowSystemBarProperties({
            statusBarColor: '#00000000',
            navigationBarColor: '#00000000'
          });
        })
        .then(() => {
          updateSafeArea(window.AvoidAreaType.TYPE_SYSTEM, mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM));
          updateSafeArea(
            window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR,
            mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
          );
          mainWindow.on('avoidAreaChange', (data) => {
            updateSafeArea(data.type, data.area);
          });
          hilog.info(DOMAIN, TAG, 'Immersive window configured.');
        })
        .catch((error: Error) => {
          hilog.error(DOMAIN, TAG, 'Failed to configure immersive window: %{public}s', JSON.stringify(error));
        });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to access main window: %{public}s', JSON.stringify(error));
    }

    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(error));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Main page loaded.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Window stage destroyed.');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability enters foreground.');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability enters background.');
  }
}
