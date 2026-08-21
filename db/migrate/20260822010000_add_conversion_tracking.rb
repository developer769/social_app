class AddConversionTracking < ActiveRecord::Migration[8.1]
  def change
    # The id of the pixel, tag or dataset that tells this platform about
    # purchases on the owner's website.
    #
    # Held per social account because that is how the ad APIs ask for it: a
    # metrics request carries the ad account and the dataset together. A
    # business running Instagram and a Facebook Page usually shares one Meta
    # pixel between them, so the same id legitimately appears twice, and that
    # is cheaper to live with than a shared table nothing else needs.
    #
    # Optional, and deliberately not part of the ads readiness checklist. A
    # shop with no website has nowhere to put a pixel and is not thereby less
    # ready to advertise; telling it otherwise would be wrong.
    add_column :social_accounts, :conversion_tracking_id, :string
    add_column :social_accounts, :conversion_tracking_added_at, :datetime

    add_check_constraint :social_accounts,
      "conversion_tracking_id IS NULL OR char_length(conversion_tracking_id) BETWEEN 3 AND 64",
      name: "social_accounts_conversion_tracking_id_length"
  end
end
