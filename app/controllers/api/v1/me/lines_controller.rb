# Unlinking LINE from your account, only if you can still sign in with email (ADR 0024).
class Api::V1::Me::LinesController < Api::V1::BaseController
  def destroy
    user = Current.user

    if !user.line_user_id?
      render_problem :not_found, status: :not_found
    elsif !user.can_unlink_line?
      render_problem :cannot_unlink, status: :conflict
    else
      user.update!(line_user_id: nil)
      head :no_content
    end
  end
end
