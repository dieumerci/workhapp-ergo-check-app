# POST /assistant: one question in, filters (and perhaps an export proposal) out.
# 404 unless the assistant is configured. The question is typed by a person and can
# contain anything, so the `message` parameter is filtered from the logs and no
# error message ever carries it.
class AssistantsController < InertiaController
  before_action { head :not_found unless Assistant.enabled? }

  rate_limit to: 20, within: 1.minute, by: -> { Current.admin&.id || request.remote_ip }, name: "assistant", with: -> {
    render json: { error: "That is a lot of questions in a short time. Please wait a moment." }, status: :too_many_requests
  }

  def create
    result = Assistant::Agent.new(company: Current.company).call(params[:message])
    render json: result.to_h
  rescue Assistant::Agent::EmptyQuestion
    render json: { error: "Type a question first." }, status: :unprocessable_entity
  rescue Assistant::Unavailable => error
    Rails.logger.warn("assistant unavailable: #{error.class}")
    render json: { error: error.message }, status: :service_unavailable
  end
end
