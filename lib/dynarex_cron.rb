#!/usr/bin/env ruby

# file: dynarex_cron.rb

require 'dynarex'
require 'chronic_cron'
require 'sps-pub'
require 'rxfreader'


DF = "%Y-%m-%d %H:%M"

class DynarexCron
  using ColouredText

  # options: e.g. sps_address: 'sps', sps_port: '59000'
  #
  def initialize(dxfile=nil, sps_address: 'sps', sps_port: '59000',  \
      log: nil, time_offset: 0, logtopic: 'DynarexCron', debug: false)


    @dxfile, @sps_address, @sps_port, @log = dxfile, sps_address, sps_port, log

    # time_offset: used for testing a cron entry without having to change
    #              the time of each entry
    @time_offset = time_offset.to_i

    @cron_entries = []
    @logtopic = logtopic


    if @dxfile then

      dynarex,_ = load_doc dxfile
      load_entries(dynarex)
    end

    @pub = SPSPub.new address: sps_address, port: sps_port

  end

  def start

    @running = true

    if @log then
      @log.info @logtopic + '/start: Time.now: ' \
          + (Time.now + @time_offset).strftime(DF)
    end


    sleep 1 until Time.now.sec == 0

    # the following loop runs every minute
    while true do

      iterate @cron_entries

      if @dxfile.is_a? String then

        # What happens if the @dxfile is a URL and the web server is
        # temporarily unavailable? i.e. 503 Service Temporarily Unavailable
        begin

          dx, buffer = load_doc(@dxfile)
          load_entries dx if @buffer != buffer
          @buffer = buffer

        rescue
          @log.debug @logtopic + '/start: warning: ' + ($!).inspect if @log
        end

      end

      min = Time.now.min
      sleep 1
      sleep 1 until Time.now.sec < 10 and Time.now.min != min
    end

  end

  def stop()
    @running = false
  end

  private

  def load_doc(dynarex_file)

    if dynarex_file.is_a?(Dynarex) then
      dynarex_file
    else

      buffer, _ = RXFReader.read(dynarex_file)
      dx = buffer =~ /<\?dynarex/ ? Dynarex.new.import(buffer) : \
          Dynarex.new(buffer)

      [dx, buffer]
    end

  end

  def load_entries(dx)

    if dx.summary[:sps_address] then
      @sps_address, @sps_port = dx.summary[:sps_address]\
                                                    .split(':',2) << '59000'
    end

    @cron_entries = dx.to_a
    @cron_entries.each do |h|
      h[:cron] = ChronicCron.new(h[:expression], Time.now + @time_offset)
    end
  end


  def iterate(cron_entries)

    puts ('h:' +  h.inspect).debug if @debug
    cron_entries.each do |h|

      datetime = (Time.now + @time_offset).strftime(DF)

      if @log then
        @log.info @logtopic + '/iterate: datetime: ' + datetime
        @log.info @logtopic + '/iterate: cron.to_time: ' \
            + h[:cron].to_time.strftime(DF)
      end

      if h[:cron].to_time.strftime(DF) == datetime then

        begin

          if h[:fqm].empty? and @log then
            @log.debug @logtopic + '/iterate: no h[:fqw] found ' + h.inspect
          end

          msg = h[:fqm].gsub('!Time',Time.now.strftime("%H:%M"))

          @pub.notice msg

        rescue

          if @log then
            @log.debug @logtopic + '/iterate: cron: ' + h[:cron].inspect
            @log.debug @logtopic + '/iterate: h: ' + h.inspect + ' : ' \
                + ($!).inspect
          end

        end

        h[:cron].next # advances the time

      end

    end
  end

end
