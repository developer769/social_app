module AnalysisHelper
  def analysis_headline(analysis)
    case analysis.status
    when "analyzing" then "Analysing your account"
    when "complete" then "Analysis complete"
    when "partially_complete" then "Analysed what we could"
    when "failed" then "The analysis could not be completed"
    else "Ready to analyse"
    end
  end
end
