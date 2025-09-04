module PaymentHelper
  def status_badge_class(status)
    case status.to_s
    when "completed"
      "bg-success"
    when "pending"
      "bg-warning text-dark"
    when "processing"
      "bg-info"
    when "failed"
      "bg-danger"
    when "refunded"
      "bg-secondary"
    when "cancelled"
      "bg-dark"
    else
      "bg-secondary"
    end
  end

  def format_payment_amount(payment)
    "#{payment.currency.upcase} #{sprintf('%.2f', payment.amount)}"
  end

  def payment_status_icon(status)
    case status.to_s
    when "completed"
      '<i class="fas fa-check-circle text-success"></i>'.html_safe
    when "pending"
      '<i class="fas fa-clock text-warning"></i>'.html_safe
    when "processing"
      '<i class="fas fa-spinner fa-spin text-info"></i>'.html_safe
    when "failed"
      '<i class="fas fa-times-circle text-danger"></i>'.html_safe
    when "refunded"
      '<i class="fas fa-undo text-secondary"></i>'.html_safe
    when "cancelled"
      '<i class="fas fa-ban text-dark"></i>'.html_safe
    else
      '<i class="fas fa-question-circle text-muted"></i>'.html_safe
    end
  end
end
