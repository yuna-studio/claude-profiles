export type Account = { n: number; id: string; isThis: boolean; text: string }

declare module 'claude-code' {
  interface PluginState {
    ccp: { accounts: Account[]; hint: string }
  }
}
