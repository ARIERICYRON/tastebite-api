namespace :demo_accounts do
  desc "Rotate original demo-account credentials and invalidate their sessions without deleting data"
  task secure: :environment do
    # SQL debug logs can include password digests. Emit only the completion count.
    logger = ActiveRecord::Base.logger
    if logger.respond_to?(:silence)
      count = logger.silence { DemoAccountSecurity.call }
    else
      count = DemoAccountSecurity.call
    end
    puts "Secured #{count} demo account(s). Existing users and content were preserved."
  end
end

