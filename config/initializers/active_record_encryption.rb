# Keys for Active Record Encryption, which protects social provider tokens.
#
# Production must supply real keys through the environment or credentials.
# Development and test use fixed, well-known values so the stack boots without
# per-machine setup -- they protect nothing and must never be used for real
# tokens, which is why production refuses to start without its own.
DEVELOPMENT_ENCRYPTION_KEYS = {
  primary_key: "development_only_primary_key_not_secret_32",
  deterministic_key: "development_only_deterministic_key_not_32",
  key_derivation_salt: "development_only_key_derivation_salt_32ch"
}.freeze

Rails.application.configure do
  config.active_record.encryption.primary_key =
    ENV["AR_ENCRYPTION_PRIMARY_KEY"] ||
    Rails.application.credentials.dig(:active_record_encryption, :primary_key) ||
    (Rails.env.local? ? DEVELOPMENT_ENCRYPTION_KEYS[:primary_key] : nil)

  config.active_record.encryption.deterministic_key =
    ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"] ||
    Rails.application.credentials.dig(:active_record_encryption, :deterministic_key) ||
    (Rails.env.local? ? DEVELOPMENT_ENCRYPTION_KEYS[:deterministic_key] : nil)

  config.active_record.encryption.key_derivation_salt =
    ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"] ||
    Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt) ||
    (Rails.env.local? ? DEVELOPMENT_ENCRYPTION_KEYS[:key_derivation_salt] : nil)

  if config.active_record.encryption.primary_key.blank?
    raise "Active Record Encryption keys are missing. Set AR_ENCRYPTION_PRIMARY_KEY, " \
          "AR_ENCRYPTION_DETERMINISTIC_KEY and AR_ENCRYPTION_KEY_DERIVATION_SALT, " \
          "or add them to credentials under active_record_encryption."
  end
end
