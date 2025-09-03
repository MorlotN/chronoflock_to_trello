class LastProcessedStore
  def initialize
    @key = ENV.fetch('LAST_ORDER_ID_KEY', 'chronoflock:last_order_id')
    @redis_url = ENV['REDIS_URL']
    @file_path = File.join(Dir.tmpdir, 'chronoflock_last_order_id')
  end

  def get
    if redis_available?
      value = redis.get(@key)
      return value&.to_i
    end
    if File.exist?(@file_path)
      File.read(@file_path).to_i
    end
  end

  def set(id)
    if redis_available?
      return redis.set(@key, id.to_i)
    end
    File.write(@file_path, id.to_i.to_s)
  end

  private

  def redis_available?
    return false unless @redis_url
    begin
      redis.ping
      true
    rescue
      false
    end
  end

  def redis
    @redis ||= Redis.new(url: @redis_url)
  end
end


