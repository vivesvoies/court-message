module ErrorsHelper
  def error_type_from_status(status)
    case status.to_i
    when 403 then :forbidden
    when 404 then :not_found
    when 422 then :unprocessable
    when 500 then :internal_server
    else :unknown
    end
  end
end
