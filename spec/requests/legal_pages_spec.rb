require "rails_helper"

# Meta will not grant publishing permissions without a privacy policy and a
# data deletion URL that both resolve -- a reviewer clicks them. India's DPDP
# Act 2023 requires the same pages and a named grievance officer.
RSpec.describe "The legal pages" do
  def body_text = response.body.gsub(/\s+/, " ")

  # The people who need these most are not signed in: somebody deciding
  # whether to trust the product, a customer whose message was collected, and
  # the platform reviewer checking the URL before granting access.
  describe "reachable without an account" do
    %w[/privacy /terms /data-deletion].each do |path|
      it "serves #{path} to a signed-out visitor" do
        get path

        expect(response).to have_http_status(:ok)
      end
    end

    # The page discusses workspaces, so the test is that it RENDERS without one
    # resolved -- not that it avoids the word.
    it "renders without a workspace being resolved" do
      get "/privacy"

      expect(response).to have_http_status(:ok)
      expect(response).not_to redirect_to(login_path)
      expect(body_text).to include("Privacy Policy")
    end
  end

  describe "the privacy policy" do
    before { get "/privacy" }

    # The inventory was built from the schema, so it has to keep matching it.
    it "names what the app actually stores" do
      expect(body_text).to include("IP address").and include("browser")
      expect(body_text).to include("access token")
      expect(body_text).to include("timezone")
    end

    # The finding that changed this document: Prachar stores personal data of
    # people who never signed up for it.
    it "explains that it holds data about people who never signed up" do
      expect(body_text).to include("People who contacted a business through a social platform")
      expect(body_text).to include("You did not give us anything")
    end

    it "tells those people what to do about it" do
      expect(body_text).to include("If you messaged a business and did not sign up")
    end

    it "states plainly what is never done with the data" do
      expect(body_text).to include("do not sell your data")
      expect(body_text).to include("do not use your content or your customers' messages to train models")
    end

    # DPDP Act 2023 rights.
    it "lists the rights the Act gives" do
      expect(body_text).to include("Digital Personal Data Protection Act, 2023")
      %w[Correct Erase Nominate Complain].each { |right| expect(body_text).to include(right) }
    end

    it "names a grievance officer and a response time" do
      expect(body_text).to include("Grievance Officer")
      expect(body_text).to include("Data Protection Board of India")
    end

    it "says how long things are kept, rather than only that they are" do
      expect(body_text).to include("30 days")
      expect(body_text).to include("two hours")
    end
  end

  describe "the deletion page" do
    before { get "/data-deletion" }

    it "explains how to delete an account" do
      expect(body_text).to include("Settings &rarr; Security").or include("Settings → Security")
    end

    # Meta requires the revocation path to be explained, not just implied.
    it "explains how to revoke access at the platform too" do
      expect(body_text).to include("Business integrations")
      expect(body_text).to include("Apps and websites")
    end

    it "is honest that a workspace somebody else owns is not deleted" do
      expect(body_text).to include("belong to somebody else")
    end
  end

  describe "the terms" do
    before { get "/terms" }

    it "says content stays with the customer" do
      expect(body_text).to include("You keep ownership")
      expect(body_text).to include("do not use your content to train models")
    end

    # The same promise the product makes everywhere else.
    it "repeats that the app says what it cannot do" do
      expect(body_text).to include("We tell you plainly what is not available")
    end

    it "warns that everyone invited gets the same access" do
      expect(body_text).to include("no restricted roles")
    end
  end

  # A placeholder reaching a published legal document is worse than an
  # incomplete one, because nobody notices.
  describe "unfilled company details" do
    it "warns on the page rather than shipping CHANGE_ME in a sentence" do
      allow(LegalDetails).to receive(:missing?).and_return(true)
      allow(LegalDetails).to receive(:missing_keys).and_return([ "entity_name" ])

      get "/privacy"

      expect(body_text).to include("This document is not ready to publish")
      expect(body_text).to include("entity_name")
    end

    it "says nothing once they are filled in" do
      allow(LegalDetails).to receive(:missing?).and_return(false)

      get "/privacy"

      expect(body_text).not_to include("not ready to publish")
    end
  end

  it "is findable from the sign-in page, where a reviewer starts" do
    get login_path

    expect(response.body).to include(privacy_path)
    expect(response.body).to include(terms_path)
  end
end
