module GenerationHelper
  def generation_headline(request)
    case request.status
    when "ready" then "Pick the one you like"
    when "partially_ready" then "Pick from what we could make"
    when "failed" then "Nothing could be made"
    else "Your pictures"
    end
  end

  def generation_summary(request)
    total = request.creative_outputs.size

    case request.status
    when "ready"
      "#{total} versions of #{request.subject&.name || request.template&.name}."
    when "partially_ready"
      "#{request.ready_count} of #{total} came out. You can try again for more."
    when "failed"
      "Try again, choose another style, or use your own picture."
    else
      "#{request.finished_count} of #{total} done."
    end
  end
end
