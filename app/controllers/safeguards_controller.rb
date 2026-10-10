class SafeguardsController < InertiaController
  ops_only

  def show
    render inertia: "safeguards/index", props: {
      cards: Safeguards.cards.map(&:to_h),
      log_example: Safeguards.log_example
    }
  end
end
