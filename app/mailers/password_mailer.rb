class PasswordMailer < ApplicationMailer
  def reset(user)
    token = user.generate_token_for(:password_reset)
    base = ENV.fetch("FRONTEND_URL", "https://tastebite-web.vercel.app").delete_suffix("/")
    url = "#{base}/reset-password?token=#{CGI.escape(token)}"
    mail(to: user.email, from: ENV.fetch("MAIL_FROM", "no-reply@tastebite.app"),
         subject: "Reset your TasteBite password", body: "Reset your password: #{url}\n\nThis link expires in 30 minutes. If you did not request it, you can ignore this email.", content_type: "text/plain")
  end
end
