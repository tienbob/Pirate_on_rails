class CacheWarmupJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting cache warmup..."
    
    begin
      # Warm up payment statistics
      warm_payment_stats
      
      # Warm up series statistics
      warm_series_stats
      
      # Warm up user statistics  
      warm_user_stats
      
      # Warm up first page of critical data
      warm_critical_pages
      
      Rails.logger.info "Cache warmup completed successfully"
    rescue => e
      Rails.logger.error "Cache warmup failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  private

  def warm_payment_stats
    Rails.cache.fetch("payment_stats_v1", expires_in: 5.minutes) do
      stats = Payment.group(:status).count
      completed_revenue = Payment.where(status: 'completed').sum(:amount) || 0
      
      {
        total: Payment.count,
        completed_revenue: completed_revenue,
        pending_count: stats['pending'] || 0,
        failed_count: stats['failed'] || 0,
        completed_count: stats['completed'] || 0
      }
    end
    Rails.logger.info "Warmed payment stats"
  end

  def warm_series_stats
    Rails.cache.fetch("series_total_count", expires_in: 30.minutes) do
      Series.count
    end
    Rails.logger.info "Warmed series stats"
  end

  def warm_user_stats
    %w[total admin pro free].each do |type|
      count = case type
      when 'total'
        User.count
      when 'admin'
        User.where(role: 'admin').count
      when 'pro'
        User.where(role: 'pro').count
      when 'free'
        User.where(role: 'free').count
      end
      
      Rails.cache.write("users_#{type}_count", count, expires_in: 3.minutes)
    end
    Rails.logger.info "Warmed user stats"
  end

  def warm_critical_pages
    # Warm first page of series
    Rails.cache.fetch("series_index_page_1", expires_in: 10.minutes) do
      Series.includes(:tags).order(updated_at: :desc).limit(8).to_a
    end
    
    # Warm first page of tags
    Rails.cache.fetch("tags_data_page_1", expires_in: 5.minutes) do
      total_count = Tag.count
      tags_data = Tag.select(:id, :name, :description, :created_at, :updated_at)
                     .order(:name, :id)
                     .limit(5)
                     .map do |tag|
        {
          id: tag.id,
          name: tag.name,
          description: tag.description,
          created_at: tag.created_at,
          updated_at: tag.updated_at
        }
      end
      
      { 
        tags: tags_data, 
        total_count: total_count, 
        page: 1, 
        per_page: 5 
      }
    end
    
    Rails.logger.info "Warmed critical pages"
  end
end
