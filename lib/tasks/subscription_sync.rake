namespace :subscriptions do
  desc "Sync all user roles with their Stripe subscription status"
  task sync_all: :environment do
    puts "Starting subscription sync for all users..."

    User.find_each do |user|
      begin
        sync_user_with_stripe(user)
        puts "✓ Synced user: #{user.email}"
      rescue => e
        puts "✗ Error syncing user #{user.email}: #{e.message}"
      end

      # Small delay to avoid hitting Stripe rate limits
      sleep(0.1)
    end

    puts "Subscription sync completed."
  end

  desc "Check for orphaned subscriptions (Stripe subscriptions without matching users)"
  task check_orphaned: :environment do
    puts "Checking for orphaned Stripe subscriptions..."

    # Get all active Stripe subscriptions
    subscriptions = Stripe::Subscription.list({
      status: "active",
      limit: 100
    })

    orphaned_count = 0

    subscriptions.auto_paging_each do |subscription|
      customer = Stripe::Customer.retrieve(subscription.customer)
      user = User.find_by(email: customer.email)

      if user.nil?
        puts "Orphaned subscription found: #{subscription.id} for email: #{customer.email}"
        orphaned_count += 1
      end
    end

    puts "Found #{orphaned_count} orphaned subscriptions."
  end

  desc "Generate subscription status report"
  task report: :environment do
    puts "Generating subscription status report..."

    total_users = User.count
    pro_users = User.where(role: "pro").count
    free_users = User.where(role: "free").count
    admin_users = User.where(role: "admin").count

    puts "User Statistics:"
    puts "  Total users: #{total_users}"
    puts "  Pro users: #{pro_users}"
    puts "  Free users: #{free_users}"
    puts "  Admin users: #{admin_users}"

    # Check Stripe subscription count
    begin
      active_subscriptions = Stripe::Subscription.list({
        status: "active",
        limit: 1
      })

      puts "Stripe Statistics:"
      puts "  Active subscriptions: #{active_subscriptions.total_count}"

      if pro_users != active_subscriptions.total_count
        puts "⚠️  WARNING: Mismatch between pro users (#{pro_users}) and active Stripe subscriptions (#{active_subscriptions.total_count})"
        puts "   Consider running: rake subscriptions:sync_all"
      else
        puts "✓ User roles match Stripe subscription count"
      end

    rescue Stripe::StripeError => e
      puts "Error checking Stripe subscriptions: #{e.message}"
    end
  end

  private

  def sync_user_with_stripe(user)
    return unless user

    ActiveRecord::Base.transaction do
      customer_search = Stripe::Customer.search({ query: "email:'#{user.email}'" })

      if customer_search.data.empty?
        # No Stripe customer found, ensure user is free
        user.update!(role: "free") if user.pro?
        return
      end

      customer = customer_search.data.first
      subscriptions = Stripe::Subscription.list({
        customer: customer.id,
        status: "all",
        limit: 10
      })

      # Find active subscription
      active_subscription = subscriptions.data.find_by { |sub| %w[active trialing].include?(sub.status) }

      if active_subscription
        # User has active subscription, should be pro
        user.update!(role: "pro") unless user.pro?
      else
        # No active subscription, should be free
        user.update!(role: "free") if user.pro?
      end
    end
  rescue Stripe::StripeError => e
    raise "Error syncing user #{user.email} with Stripe: #{e.message}"
  end
end
