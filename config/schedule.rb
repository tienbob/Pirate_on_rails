every 1.day, at: '2:00 am' do
  runner "StripeSyncJob.perform_later"
end