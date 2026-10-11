import { useState } from 'react'
import { router, usePage } from '@inertiajs/react'
import Dialog from '@/components/Dialog'
import { CompanyLock, Notice, SheetHeader } from '@/components/ui'
import { cx } from '@/lib/cx'
import type { StatusValue } from '@/types'
import type { EmployeeOption } from '@/types/assessments'

type Props = {
  open: boolean
  // undefined until the page has loaded them (a partial reload when the dialog opens).
  employees: EmployeeOption[] | undefined
  onClose: () => void
}

const NEW_EMPLOYEE = 'new'
const NAME_LIMIT = 120
const DEPARTMENT_LIMIT = 80

const isScore = (value: string) => /^\d{1,3}$/.test(value) && Number(value) <= 100

export default function NewAssessmentDialog({ open, employees, onClose }: Props) {
  return (
    <Dialog open={open} onClose={onClose} labelledBy="new-assessment-title">
      <Form key={String(open)} employees={employees} onClose={onClose} />
    </Dialog>
  )
}

function Form({ employees, onClose }: Omit<Props, 'open'>) {
  const { status_options, score_sections, errors } = usePage().props
  const [employeeId, setEmployeeId] = useState('')
  const [name, setName] = useState('')
  const [department, setDepartment] = useState('')
  const [status, setStatus] = useState<StatusValue>('pending')
  const [scores, setScores] = useState<Record<string, string>>({})
  const [submitting, setSubmitting] = useState(false)

  const creating = employeeId === NEW_EMPLOYEE
  const scored = status_options.find((option) => option.value === status)?.scored ?? false
  const entered = score_sections.map((section) => scores[section.key] ?? '').filter((value) => value !== '')
  const scoresProblem =
    !scored || entered.length === 0
      ? null
      : entered.length < score_sections.length
        ? 'Fill in all four section scores, or leave them all empty.'
        : entered.every(isScore)
          ? null
          : 'Section scores are whole numbers from 0 to 100.'
  const ready = employeeId !== '' && (!creating || name.trim() !== '') && scoresProblem === null
  const departments = Array.from(new Set((employees ?? []).map((employee) => employee.department).filter(Boolean))) as string[]

  const submit = () => {
    if (!ready || submitting) return
    setSubmitting(true)
    router.post(
      '/assessments',
      {
        employee_id: employeeId,
        ...(creating ? { employee_name: name, department } : {}),
        status,
        ...(scored && entered.length > 0 ? { scores } : {}),
      },
      {
        preserveScroll: true,
        preserveState: true,
        onSuccess: onClose,
        onFinish: () => setSubmitting(false),
      },
    )
  }

  return (
    <form
      className="flex flex-col gap-6"
      onSubmit={(event) => {
        event.preventDefault()
        submit()
      }}
    >
      <SheetHeader id="new-assessment-title" title="New assessment" subtitle="Record an assessment for one of your employees." onClose={onClose} />

      <CompanyLock prefix="Saved to" />

      <label className="field">
        <span className="eyebrow">Employee</span>
        <select value={employeeId} onChange={(event) => setEmployeeId(event.target.value)} disabled={employees === undefined} className="input">
          <option value="" disabled>
            {employees === undefined ? 'Loading employees…' : 'Choose an employee…'}
          </option>
          {(employees ?? []).map((employee) => (
            <option key={employee.id} value={employee.id}>
              {employee.name}
              {employee.department ? ` · ${employee.department}` : ''}
            </option>
          ))}
          <option value={NEW_EMPLOYEE}>+ Add a new employee…</option>
        </select>
      </label>

      {creating && (
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="field">
            <span className="eyebrow">Name</span>
            <input type="text" value={name} maxLength={NAME_LIMIT} onChange={(event) => setName(event.target.value)} autoComplete="off" className="input" />
          </label>
          <label className="field">
            <span className="eyebrow">Department</span>
            <input type="text" value={department} maxLength={DEPARTMENT_LIMIT} list="department-options" onChange={(event) => setDepartment(event.target.value)} autoComplete="off" className="input" />
            <datalist id="department-options">
              {departments.map((option) => (
                <option key={option} value={option} />
              ))}
            </datalist>
          </label>
        </div>
      )}

      <label className="field">
        <span className="eyebrow">Status</span>
        <select value={status} onChange={(event) => setStatus(event.target.value as StatusValue)} className="input">
          {status_options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

      <fieldset className="flex flex-col gap-3.5 border-l-[3px] border-line pl-4 disabled:opacity-70" disabled={!scored}>
        <legend className="eyebrow float-left mb-3.5 w-full">Section scores (0–100)</legend>
        <div className="grid gap-4 sm:grid-cols-2">
          {score_sections.map((section) => (
            <label key={section.key} className="field">
              <span className="text-[13px] font-medium text-ink-2">{section.label}</span>
              <input
                type="number"
                inputMode="numeric"
                min={0}
                max={100}
                step={1}
                value={scores[section.key] ?? ''}
                onChange={(event) => setScores({ ...scores, [section.key]: event.target.value })}
                className="input tabular-nums"
              />
            </label>
          ))}
        </div>
        <div className={cx('text-[13px]', scoresProblem ? 'font-semibold text-danger' : 'text-muted')} role={scoresProblem ? 'alert' : undefined}>
          {scoresProblem ??
            (scored
              ? 'Optional. The ergonomic score is the rounded average of the four sections.'
              : 'Scores are recorded once an assessment is completed, so these stay empty for now.')}
        </div>
      </fieldset>

      {errors.assessment && (
        <Notice tone="danger" role="alert">
          {errors.assessment.map((problem) => (
            <div key={problem}>{problem}</div>
          ))}
        </Notice>
      )}

      <div className="flex justify-end gap-2.5">
        <button type="button" onClick={onClose} className="btn btn-quiet">
          Cancel
        </button>
        <button type="submit" disabled={!ready || submitting} className="btn btn-primary">
          {submitting ? 'Creating…' : 'Create assessment'}
        </button>
      </div>
    </form>
  )
}
