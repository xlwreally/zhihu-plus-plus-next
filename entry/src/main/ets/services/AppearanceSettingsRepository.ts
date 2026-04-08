import common from '@ohos.app.ability.common';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const APPEARANCE_PREFERENCES_FILE: string = 'zhihu_appearance';
const THEME_MODE_KEY: string = 'theme_mode';
const THEME_MODE_STORAGE_KEY: string = 'themeMode';

export type AppearanceThemeMode = 'light' | 'dark' | 'system';
const DEFAULT_THEME_MODE: AppearanceThemeMode = 'system';

export class AppearanceSettingsRepository {
  private static initialized: boolean = false;
  private static themeMode: AppearanceThemeMode = DEFAULT_THEME_MODE;

  private static preferences(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, {
      name: APPEARANCE_PREFERENCES_FILE
    });
  }

  private static updateAppStorage(themeMode: AppearanceThemeMode): void {
    if (!AppStorage.set<AppearanceThemeMode>(THEME_MODE_STORAGE_KEY, themeMode)) {
      AppStorage.setOrCreate<AppearanceThemeMode>(THEME_MODE_STORAGE_KEY, themeMode);
    }
  }

  private static normalizeThemeMode(raw: Object | string): AppearanceThemeMode {
    if (typeof raw === 'string' && (raw === 'light' || raw === 'dark' || raw === 'system')) {
      return raw as AppearanceThemeMode;
    }
    return DEFAULT_THEME_MODE;
  }

  private static applyColorMode(context: common.Context, themeMode: AppearanceThemeMode): void {
    let mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (themeMode === 'light') {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (themeMode === 'dark') {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    context.getApplicationContext().setColorMode(mode);
  }

  static load(context: common.Context): AppearanceThemeMode {
    if (!this.initialized) {
      const store = this.preferences(context);
      this.themeMode = this.normalizeThemeMode(store.getSync(THEME_MODE_KEY, DEFAULT_THEME_MODE));
      this.initialized = true;
    }
    this.updateAppStorage(this.themeMode);
    this.applyColorMode(context, this.themeMode);
    return this.themeMode;
  }

  static currentThemeMode(context?: common.Context): AppearanceThemeMode {
    if (context !== undefined) {
      this.load(context);
    }
    return this.themeMode;
  }

  static setThemeMode(context: common.Context, themeMode: AppearanceThemeMode): AppearanceThemeMode {
    this.themeMode = this.normalizeThemeMode(themeMode);
    this.initialized = true;
    const store = this.preferences(context);
    store.putSync(THEME_MODE_KEY, this.themeMode);
    store.flushSync();
    this.updateAppStorage(this.themeMode);
    this.applyColorMode(context, this.themeMode);
    return this.themeMode;
  }
}
