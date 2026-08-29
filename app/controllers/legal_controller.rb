# The public legal pages.
#
# Reachable without signing in and without a workspace, because the people who
# need them most are not signed in: somebody deciding whether to trust the
# product, a customer whose message was collected, and the platform reviewers
# who click the URL before granting API access.
class LegalController < ApplicationController
  allow_unauthenticated_access

  layout "public"

  def privacy; end
  def terms; end

  # Meta requires a reachable URL explaining how data is deleted, separately
  # from the privacy policy. India's DPDP Act requires the same right.
  def data_deletion; end
end
