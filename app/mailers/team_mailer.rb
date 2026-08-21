class TeamMailer < ApplicationMailer
  # The raw token is passed in rather than read from the record, because only
  # its digest is stored and the raw value exists for one moment in memory.
  def invitation(membership, raw_token)
    @membership = membership
    @workspace = membership.workspace
    @invited_by = membership.invited_by
    @accept_url = invitation_url(token: raw_token)
    @expires_on = membership.expires_at&.to_date

    mail(
      to: membership.invitation_email,
      subject: "#{@invited_by&.name || 'Someone'} invited you to #{@workspace.name} on Prachar"
    )
  end
end
