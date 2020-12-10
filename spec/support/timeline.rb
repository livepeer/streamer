class Timeline
  attr_reader :events
  attr_reader :position

  def initialize
    @events = []

    @position = 0
    @buffer = 0
  end

  def add(event)
    @events << [ @buffer, event ]

    self
  end

  def add_many(event, count: 1, separation: 1.second)
    count.times do
      add(event)
      fwd(separation)
    end

    self
  end

  def fwd(time)
    @buffer = @buffer + time

    self
  end

  def play(monitor=nil, &block)
    @start ||= Time.now

    events.drop(@position).each do |time, event|
      Timecop.freeze(@start + time)

      if monitor.present?
        monitor.record(event)
      else
        block.call(event)
      end

      @position += 1
    end

    self
  end

  def return
    @position = 0
    @start ||= Time.now
    @buffer ||= @start

    Timecop.return

    self
  end
end
