# Internal ops page for the status normalization release (plan only).
class ReleasePlansController < InertiaController
  ops_only

  MAX_PROBE_LENGTH = 100

  def show
    render inertia: "release_plan/index", props: {
      mapping: ReleasePlan.mapping,
      steps: ReleasePlan.steps.map(&:to_h),
      rollback: ReleasePlan.rollback,
      samples: ReleasePlan::SAMPLES
    }
  end

  # Runs a value through the real Status rules, for the page's tester.
  def normalize
    render json: ReleasePlan.normalize(params[:value].to_s.first(MAX_PROBE_LENGTH))
  end
end
