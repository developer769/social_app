class UserMailer < ApplicationMailer
  # Takes the token as an argument rather than reading it off the record.
  #
  # deliver_later serialises a record through GlobalID, so the mailer reloads
  # it from the database -- where only the DIGEST is kept. The raw token lives
  # in memory on the object that minted it and does not survive the queue, so
  # reading reset.raw_token here produced a link with no token in it at all.
  #
  # The trade is that the token sits in the job payload until the mail is sent.
  # It is single-use and lives two hours; the queue is internal and the
  # alternative -- delivering inline -- puts SMTP latency in the request path
  # of somebody already locked out.
  def password_reset(user, raw_token)
    @user = user
    @url = edit_password_reset_url(token: raw_token)
    @expires_in_hours = (PasswordReset::VALID_FOR / 1.hour).to_i

    mail(to: @user.email, subject: "Set a new Prachar password")
  end

  # Sent after the fact, to whoever owns the address. If they did not do this,
  # it is the only warning they will get.
  def password_changed(user)
    @user = user
    @when = Time.current

    mail(to: user.email, subject: "Your Prachar password was changed")
  end
end
