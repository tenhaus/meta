namespace :metrics do
  namespace :asm do
    def active_user(type, user, at)
      puts "#{type} #{at.iso8601} – #{user.username}"
      Workers::AsmTrackUniqueWorker.new.perform 'user.active', user.id, at
    end

    # run this hourly, track actives in PST
    task :store_daily_actives => :environment do
      pst = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      at = pst.now

      start_at = (at - 1.hour).beginning_of_day.utc
      end_at = (at - 1.hour).end_of_day.utc

      daily_actives = Metrics::DailyActives.where(created_at: end_at).first_or_initialize
      daily_actives.count = User.where('last_request_at > ?', start_at).count
      daily_actives.save!
    end

    task :rebuild => :environment do
      ActiveRecord::Base.logger = nil
      Product.find_by(slug: 'asm').metrics.find_by(name: 'user.active').uniques.delete_all

      [Product, Wip, Event, Vote].each do |klass|
        klass.joins(:user).where('is_staff is not true').find_each do |o|
          active_user klass, o.user, o.created_at
        end
      end

      User.where('is_staff is not true').find_each do |o|
        active_user User, o, o.created_at
      end
    end
  end
  
  
  task :mau => :environment do
    mau = User.where("created_at <= ? AND last_request_at >= ? AND last_request_at <= ?", 4.days.ago, 31.days.ago, 2.days.ago).count
    puts "Total MAU: #{mau}"
    puts "Total %: #{(mau.to_f / User.count.to_f)}"
    User.where("created_at <= ?", 4.days.ago).count
  end
  
  desc "Monthly Active Contributors - People who created wips and comment"
  task :mac => :environment do
    data = by_month do |date|
      total =  Event.joins(:user).where('users.is_staff is false').where("events.created_at >= date(?) and events.created_at <= date(?)", date.beginning_of_month, date.end_of_month).group('events.user_id').count.keys.size
      total = total + Wip.joins(:user).where('users.is_staff is false').where("wips.created_at >= date(?) and wips.created_at <= date(?)", date.beginning_of_month, date.end_of_month).group('wips.user_id').count.keys.size
      [Date::MONTHNAMES[date.month], total]
    end
    data.each do |month, total|
      puts "#{month}: #{total} Monthly Active Contributors"
    end
  end
  
  desc "Monthly Total Contributions - create wips and add comments"
  task :mtc => :environment do
    data = by_month do |date|
      total =  Event.joins(:user).where('users.is_staff is false').where("events.created_at >= date(?) and events.created_at <= date(?)", date.beginning_of_month, date.end_of_month).size
      total = total + Wip.joins(:user).where('users.is_staff is false').where("wips.created_at >= date(?) and wips.created_at <= date(?)", date.beginning_of_month, date.end_of_month).size
      [Date::MONTHNAMES[date.month], total]
    end
    data.each do |month, total|
      puts "#{month}: #{total} Monthly Total Contributions"
    end
  end
  
  desc "Monthly Active Partners - People who won tasks"
  task :map => :environment do
    data = by_month do |date|
      total = Task.joins(winning_event: :user).where('users.is_staff is false').where("closed_at >= date(?) and closed_at <= date(?)", date.beginning_of_month, date.end_of_month).won.map{|t| t.winning_event.user.username }.uniq.size
      [Date::MONTHNAMES[date.month], total]
    end
    data.each do |month, total|
      puts "#{month}: #{total} Monthly Active Partners"
    end
  end
  
  desc "Monthly Total Winnings - Actual work accepted & won"
  task :mtw => :environment do
    data = by_month do |date|
      total = Task.joins(winning_event: :user).where('users.is_staff is false').where("closed_at >= date(?) and closed_at <= date(?)", date.beginning_of_month, date.end_of_month).won.size
      [Date::MONTHNAMES[date.month], total]
    end
    data.each do |month, total|
      puts "#{month}: #{total} Monthly Total Winnings"
    end    
  end
  
  desc "Monthly Products Developed - Products being worked on"
  task :mpd => :environment do
    data = by_month do |date|
      total = Task.joins(winning_event: :user).where('users.is_staff is false').where("closed_at >= date(?) and closed_at <= date(?)", date.beginning_of_month, date.end_of_month).won.collect(&:product_id).uniq.size
      [Date::MONTHNAMES[date.month], total]
    end
    data.each do |month, total|
      puts "#{month}: #{total} Monthly Products Developed"
    end
  end
  
  desc "Monthly Products Started"
  task :mps => :environment do
    data = by_month do |date|
      total = Product.where("created_at >= date(?) and created_at <= date(?)", date.beginning_of_month, date.end_of_month).size
      [Date::MONTHNAMES[date.month], total]
    end
    data.each do |month, total|
      puts "#{month}: #{total} Products Started"
    end
  end
  
  def by_month
    data = []
    ["1-nov-2013", "1-dec-2013", "1-jan-2014", "1-feb-2014", "1-mar-2014"].each do |month|
      data << yield(Date.parse(month))
    end
    data
  end  
end