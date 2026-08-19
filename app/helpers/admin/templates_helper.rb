module Admin
  module TemplatesHelper
    def empty_state_title(format, scope)
      noun = (format == "video") ? "video styles" : "photo styles"

      case scope
      when "drafts" then "No #{noun} in progress"
      when "retired" then "No retired #{noun}"
      else "No #{noun} published yet"
      end
    end

    def empty_state_body(format, scope)
      noun = (format == "video") ? "video style" : "photo style"

      case scope
      when "drafts" then "Anything you save but have not published will wait here."
      when "retired" then "Retired styles leave the gallery but keep working for posts already made with them."
      else "Add a #{noun} and publish it to put it in every business's gallery."
      end
    end
  end
end
