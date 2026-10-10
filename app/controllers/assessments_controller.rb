# Landing page after sign-in. The dashboard itself is built out in the
# "Task 2" work; for now this proves the tenant comes from the session.
class AssessmentsController < InertiaController
  def index
    render inertia: {}
  end
end
