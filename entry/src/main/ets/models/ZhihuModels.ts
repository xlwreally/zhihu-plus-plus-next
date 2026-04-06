export type FeedMode = 'web' | 'android' | 'local' | 'mixed';

export interface SessionSnapshot {
  readonly accountName: string;
  readonly loggedIn: boolean;
  readonly cookieCount: number;
  readonly feedMode: FeedMode;
  readonly hasSigningBridge: boolean;
  readonly hasWebReadingShell: boolean;
  readonly hasPersistentStorage: boolean;
}

export interface MigrationModule {
  readonly name: string;
  readonly status: 'planned' | 'in-progress' | 'blocked';
  readonly summary: string;
  readonly sourceArea: string;
}

export interface MigrationPhase {
  readonly title: string;
  readonly goal: string;
  readonly modules: string[];
}

export interface SettingHint {
  readonly title: string;
  readonly value: string;
}
