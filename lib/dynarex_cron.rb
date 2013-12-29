#!/usr/bin/env ruby

# file: dynarex_cron.rb

require 'dynarex'
require 'chronic_cron'
require 'websocket-eventmachine-client'
require 'rscript'
require 'chronic_duration'
require 'logger'

DF = "%Y-%m-%d %H:%M"

class DynarexCron

  # options: e.g. sps_address: 'sps', sps_port: '59000'
  #
  def initialize(dynarex_file=nil, options={})
    
    opt = {sps_address: 'sps', sps_port: '59000', drb_port: nil, \
      log: nil, time_offset: 0}.merge options
    @logger = Logger.new(opt[:log],'weekly') if opt[:log]

    # time_offset: used for testing a cron entry without having to change 
    #              the time of each entry
    @time_offset = opt[:time_offset].to_i
    
    @cron_entries, @cron_events  = [], []
    
    @dynarex_file = dynarex_file
    load_entries() if @dynarex_file    
    load_events() if @include_url

    @sps_address, @sps_port = opt[:sps_address], opt[:sps_port]

    if opt[:drb_port] then

      Thread.new {
        
        # start up the DRb service
        DRb.start_service 'druby://:' + opt[:drb_port], self

        # wait for the DRb service to finish before exiting
        DRb.thread.join    
      }
    end    

  end

  def start

    @running = true
    puts '[' + (Time.now + @time_offset).strftime(DF) + '] DynarexCron started'
    params = {uri: "ws://%s:%s" % [@sps_address, @sps_port]}

    c = WebSocket::EventMachine::Client

    EventMachine.run do

      @ws = c.connect(params)

      EM.add_periodic_timer(60) do
        iterate @cron_entries
        iterate @cron_events
      end
    end

  end
  
  def stop()
    @running = false
    @ws.close
    EM.stop_event_loop
  end
  
  def load_entries()
    
    dynarex = @dynarex_file.is_a?(Dynarex) ? @dynarex_file : \
                                        Dynarex.new(@dynarex_file)
    
    @include_url = dynarex.summary[:include]
    @cron_entries = dynarex.to_h
    @cron_entries.each do |h| 
      h[:cron] = ChronicCron.new(h[:expression], Time.now + @time_offset)
    end
  end
  
  alias refresh_entries load_entries
  
  def load_events()
    
    de = DynarexEvents.new(@include_url)
    @cron_events = de.to_a
  end
  
  alias refresh_events load_events  

  private

  def iterate(cron_entries)
    
    cron_entries.each do |h|
      
      datetime = (Time.now + @time_offset).strftime(DF)

      if h[:cron].to_time.strftime(DF) == datetime then
        
        r = h[:job].match(/^pub(?:lish)?\s+([^:]+):(.*)/)

        next unless r

        begin

          topic, msg = r.captures
          @ws.send "%s: %s" % [topic, msg]
          h[:cron].next # advances the time

        rescue
          
          @logger.debug h.inspect ' : ' + ($!) if @logger
        end
        
      end
    end        
  end   
  
end

class DynarexEvents < DynarexCron

  attr_reader :to_a

  def initialize(dynarex_file=nil, options={})
    
    opt = {sps_address: nil, time_offset: 0}.merge options
    
    @time_offset = opt[:time_offset]
    @cron_events  = []
    
    @dynarex_file = dynarex_file
    load_events()

    @sps_address = opt[:sps_address]
    
  end    

  def load_events()
    
    dynarex = Dynarex.new @dynarex_file
    @entries = dynarex.to_h
    @cron_events = self.to_a
  end  
  
  alias refresh load_events
  
  def start

    @running = true
    puts '[' + Time.now.strftime(DF) + '] DynarexEvents started'
    params = {uri: "ws://%s:%s" % [@sps_address, @sps_port]}    

    c = WebSocket::EventMachine::Client

    EventMachine.run do

      @ws = c.connect(params)

      EM.add_periodic_timer(60) do
        iterate @cron_events
      end

    end
  end  
  
  def to_a()
    
    @entries.inject([]) do |r,h| 

      time = Time.now + @time_offset
      h[:cron] = ChronicCron.new(h[:date], time) 
      h[:job] = 'pub event: ' + h[:title]

      if h[:reminder].length > 0 then
        rmndr = {}
        rmndr[:cron] = ChronicCron.new((Chronic.parse(h[:date]) - 
                              ChronicDuration.parse(h[:reminder])).to_s, time)
        rmndr[:job] = 'pub event: reminder ' + h[:title]
        r << rmndr
      end

      r << h
    end
    
  end
end