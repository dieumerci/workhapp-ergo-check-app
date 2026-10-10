// Everything the app keeps in localStorage is a "Preferences" convenience, so it is
// remembered only with that cookie choice and wiped when the choice is withdrawn.
export const RELEASE_STEPS_KEY = 'ergocheck.releasePlan.done'

export function clearPreferenceStorage(): void {
  try {
    window.localStorage.removeItem(RELEASE_STEPS_KEY)
  } catch {
    // Storage unavailable: there is nothing to clear.
  }
}
