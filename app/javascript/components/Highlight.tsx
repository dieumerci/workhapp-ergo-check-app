const escape = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

// Marks the parts of +text+ that match any of +terms+ (case-insensitive). Plain
// React text nodes, so nothing a person typed is ever treated as HTML.
export default function Highlight({ text, terms }: { text: string; terms: string[] }) {
  const useful = terms.filter((term) => term.length > 0)
  if (useful.length === 0) return <>{text}</>

  const pattern = new RegExp(`(${useful.map(escape).join('|')})`, 'gi')
  return (
    <>
      {text.split(pattern).map((part, index) =>
        index % 2 === 1 ? (
          <mark key={index} className="rounded-[3px] bg-brand-tint px-px text-inherit">
            {part}
          </mark>
        ) : (
          part
        ),
      )}
    </>
  )
}
