class Current < ActiveSupport::CurrentAttributes
  attribute :admin, :admin_session

  # The tenant for the whole request. It comes from the authenticated admin,
  # so no client-supplied identifier can ever widen what a request can reach.
  def company
    admin&.company
  end
end
