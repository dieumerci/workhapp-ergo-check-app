import { useState } from 'react'
import { router, usePage } from '@inertiajs/react'
import Dialog from '@/components/Dialog'
import { CloseIcon, LockIcon } from '@/components/Icons'
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

const labelClass = 'flex flex-col gap-1.5 text-xs font-semibold tracking-wider text-muted uppercase'
const controlClass =
  'rounded-[9px] border border-control bg-white px-2.5 py-[9px] text-sm font-normal tracking-normal text-ink normal-case disabled:bg-canvas disabled:text-subtle'
const ghostButton = 'rounded-[9px] border border-control bg-white px-3.5 py-[9px] font-semibold hover:bg-hover'
const primaryButton = 'rounded-[9px] bg-brand px-4 py-[9px] font-semibold text-white hover:bg-brand-dark'

const isScore = (value: string) => /^\d{1,3}$/.test(value) && Number(value) <= 100

export default function NewAssessmentDialog({ open, employees, onClose }: Props) {
  return (
    <Dialog open={open} onClose={onClose} labelledBy="new-assessment-title">
      <Form key={String(open)} employees={employees} onClose={onClose} />
    </Dialog>
  )
}

function Form({ employees, onClose }: Omit<Props, 'open'>) {
  const { auth, status_options, score_sections, errors } = usePage().props
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
      className="flex flex-col gap-5"
      onSubmit={(event) => {
        event.preventDefault()
        submit()
      }}
    >
      <div className="flex items-start justify-between">
        <div>
          <h2 id="new-assessment-title" className="text-xl font-bold tracking-tight">
            New assessment
          </h2>
          <div className="mt-0.5 text-muted">Record an assessment for one of your employees.</div>
        </div>
        <button type="button" onClick={onClose} aria-label="Close" className="grid size-8 flex-none place-items-center rounded-lg bg-canvas hover:bg-hover">
          <CloseIcon size={14} />
        </button>
      </div>

      <div className="flex items-center gap-2.5 rounded-[10px] bg-brand-tint px-3 py-2.5 text-[13px] text-brand-dark">
        <LockIcon size={15} className="flex-none" />
        <div>
          Saved to <strong>{auth.company?.name}</strong> only — set by your account, not editable.
        </div>
      </div>

      <label className={labelClass}>
        Employee
        <select value={employeeId} onChange={(event) => setEmployeeId(event.target.value)} disabled={employees === undefined} className={controlClass}>
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
        <div className="grid grid-cols-2 gap-3">
          <label className={labelClass}>
            Name
            <input type="text" value={name} maxLength={NAME_LIMIT} onChange={(event) => setName(event.target.value)} autoComplete="off" className={controlClass} />
          </label>
          <label className={labelClass}>
            Department
            <input type="text" value={department} maxLength={DEPARTMENT_LIMIT} list="department-options" onChange={(event) => setDepartment(event.target.value)} autoComplete="off" className={controlClass} />
            <datalist id="department-options">
              {departments.map((option) => (
                <option key={option} value={option} />
              ))}
            </datalist>
          </label>
        </div>
      )}

      <label className={labelClass}>
        Status
        <select value={status} onChange={(event) => setStatus(event.target.value as StatusValue)} className={controlClass}>
          {status_options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

      <fieldset className="flex flex-col gap-2.5 rounded-xl border border-line p-3.5" disabled={!scored}>
        <legend className="px-1 text-[13px] font-semibold">Section scores (0–100)</legend>
        <div className="grid grid-cols-2 gap-3">
          {score_sections.map((section) => (
            <label key={section.key} className={labelClass}>
              {section.label}
              <input
                type="number"
                inputMode="numeric"
                min={0}
                max={100}
                step={1}
                value={scores[section.key] ?? ''}
                onChange={(event) => setScores({ ...scores, [section.key]: event.target.value })}
                className={controlClass}
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
        <div role="alert" className="rounded-[10px] bg-danger-tint px-3 py-2.5 text-[13px] font-medium text-danger">
          {errors.assessment.map((problem) => (
            <div key={problem}>{problem}</div>
          ))}
        </div>
      )}

      <div className="flex justify-end gap-2">
        <button type="button" onClick={onClose} className={ghostButton}>
          Cancel
        </button>
        <button type="submit" disabled={!ready || submitting} className={cx(primaryButton, (!ready || submitting) && 'opacity-40')}>
          {submitting ? 'Creating…' : 'Create assessment'}
        </button>
      </div>
    </form>
  )
}
