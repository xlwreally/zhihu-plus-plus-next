import { FeedMode, SessionSnapshot } from '../models/ZhihuModels';

const DEFAULT_SESSION: SessionSnapshot = {
  accountName: '未登录',
  loggedIn: false,
  cookieCount: 0,
  feedMode: 'mixed',
  hasSigningBridge: false,
  hasWebReadingShell: false,
  hasPersistentStorage: false
};

class PreferenceStore {
  private session: SessionSnapshot = DEFAULT_SESSION;

  snapshot(): SessionSnapshot {
    return this.session;
  }

  updateFeedMode(feedMode: FeedMode): SessionSnapshot {
    this.session = {
      ...this.session,
      feedMode
    };
    return this.session;
  }

  markCapability(
    capability: 'hasSigningBridge' | 'hasWebReadingShell' | 'hasPersistentStorage',
    enabled: boolean
  ): SessionSnapshot {
    this.session = {
      ...this.session,
      [capability]: enabled
    };
    return this.session;
  }

  reset(): SessionSnapshot {
    this.session = DEFAULT_SESSION;
    return this.session;
  }
}

export const preferenceStore = new PreferenceStore();
