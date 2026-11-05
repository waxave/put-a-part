require "digest"

module SingleUserAccess
  def self.valid?(username, password)
    expected_user = ENV["APP_USERNAME"].to_s
    expected_password = ENV["APP_PASSWORD"].to_s
    return false if expected_user.empty? || expected_password.empty?

    user_match = ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(username.to_s), Digest::SHA256.hexdigest(expected_user))
    password_match = ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(password.to_s), Digest::SHA256.hexdigest(expected_password))
    user_match & password_match
  end
end
