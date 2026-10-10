export type SafeguardCard = { task: string; title: string; points: string[] }

export type SafeguardsProps = {
  cards: SafeguardCard[]
  log_example: { before: string; after: string }
}
