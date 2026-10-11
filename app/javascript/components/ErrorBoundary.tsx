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
      <div role="alert" className="paper mx-auto mt-16 max-w-[480px] rounded-[28px] p-8 text-center">
        <h1 className="display text-[30px]">Something went wrong</h1>
        <p className="mt-2 text-muted">This page could not be displayed. Your data has not been changed.</p>
        <button type="button" onClick={() => window.location.reload()} className="btn btn-primary mt-6">
          Reload the page
        </button>
      </div>
    )
  }
}
