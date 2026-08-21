class ApplicationMailer < ActionMailer::Base
  # Rails ships with "from@example.com", which would be rejected by receiving
  # servers as an unverified sender and would look like spam to anyone it did
  # reach. The real address comes from the environment, so production uses the
  # domain that actually has SPF and DKIM records.
  default from: ENV.fetch("MAIL_FROM", "Prachar <no-reply@prachar.test>"),
          reply_to: ENV.fetch("MAIL_REPLY_TO", "Prachar support <support@prachar.test>")

  layout "mailer"
end
