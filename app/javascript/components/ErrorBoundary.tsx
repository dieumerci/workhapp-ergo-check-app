import { Component, type ErrorInfo, type ReactNode } from 'react'

type State = { failed: boolean }

// Without this, an error while rendering any component blanks the whole app.
// It shows a plain, recoverable message and logs only the error's name:
// messages and component stacks can contain the data being rendered, and this
// app's data is health-related.
export default class ErrorBoundary extends Component<{ children: ReactNode }, State> {
  state: State = { failed: false }

  static getDerivedStateFromError(): State {
    return { failed: true }
  }

  componentDidCatch(error: Error, _info: ErrorInfo) {
    console.error(`Render error: ${error.name}`)
  }

  render() {
    if (!this.state.failed) return this.props.children

    return (
      <div role="alert" className="mx-auto mt-16 max-w-[460px] rounded-2xl border border-line bg-white p-6 text-center shadow-sm">
        <h1 className="text-lg font-bold">Something went wrong</h1>
        <p className="mt-1.5 text-muted">This page could not be displayed. Your data has not been changed.</p>
        <button
          type="button"
          onClick={() => window.location.reload()}
          className="mt-4 rounded-[9px] bg-brand px-4 py-2 font-semibold text-white hover:bg-brand-dark"
        >
          Reload the page
        </button>
      </div>
    )
  }
}
