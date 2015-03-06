#!/usr/bin/env ruby

# file: dynarex_cron.rb

require 'dynarex'
require 'chronic_cron'
require 'rscript'
require 'chronic_duration'
require 'logger'
require 'run_every'
require 'sps-pub'


DF = "%Y-%m-%d %H:%M"

class DynarexCron

  # options: e.g. sps_address: 'sps', sps_port: '59000'
  #
  def initialize(dynarex_file=nil, options={})
    
    opt = {sps_address: 'sps', sps_port: '59000',  \
      log: nil, time_offset: 0}.merge options
    @logger = Logger.new(opt[:log],'weekly') if opt[:log]

    # time_offset: used for testing a cron entry without having to change 
    #              the time of each entry
    @time_offset = opt[:time_offset].to_i
    
    @cron_entries, @cron_events  = [], []
    
    @dynarex_file = dynarex_file

    if @dynarex_file then

      dynarex = load_doc dynarex_file
      load_entries(dynarex)
    end 

    load_events() if @include_url and @include_url.length > 0

    @sps_address, @sps_port = opt[:sps_address], opt[:sps_port]


  end

  def start

    @running = true
    puts '[' + (Time.now + @time_offset).strftime(DF) + '] DynarexCron started'
    params = {uri: "ws://%s:%s" % [@sps_address, @sps_port]}

    RunEvery.new(seconds: 60) do

      iterate @cron_entries
      iterate @cron_events

      if @dynarex_file.is_a? String then

        # What happens is the @dynarex_file is a URL and the web server is 
        # temporarily unavailable? i.e. 503 Service Temporarily Unavailable
        begin
          buffer, _ = RXFHelper.read(@dynarex_file)
        rescue
          puts 'dynarex_cron: warning: ' + ($!).inspect           
        end
        
        reload_entries buffer if @buffer != buffer

      end

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
      @buffer, _ = RXFHelper.read(dynarex_file)
      Dynarex.new @buffer
    end
        
  end

  def load_entries(dynarex)

    @include_url = dynarex.summary[:include]
    
    if dynarex.summary[:sps_address] then
      @sps_address, @sps_port = dynarex.summary[:sps_address]\
                                                    .split(':',2) << '59000'
    end
    
    @cron_entries = dynarex.to_h
    @cron_entries.each do |h| 
      h[:cron] = ChronicCron.new(h[:expression], Time.now + @time_offset)
    end
  end  
  
  def load_events()
    
    de = DynarexEvents.new(@include_url)
    @cron_events = de.to_a
  end  

  def log(s, method_name=:debug)
    return unless @logger
    @logger.method(method_name).call s
  end

  def iterate(cron_entries)
    
    cron_entries.each do |h|
      
      datetime = (Time.now + @time_offset).strftime(DF)
      log "datetime: %s; h: %s" % [datetime, h.inspect]
      
      if h[:cron].to_time.strftime(DF) == datetime then

        r = h[:job].match(/^pub(?:lish)?\s+([^:]+):(.*)/)

        next unless r
          
          topic, msg = r.captures

          log "sps_Address: %s sps_port: %s topic: %s message: %s" % \
                                        [@sps_address, @sps_port, topic, msg]
        begin
          
          SPSPub.notice "%s: %s" % \
                          [topic, msg], address: @sps_address, port:@sps_port
          log 'before cron next', :info
          h[:cron].next # advances the time
        rescue
            
          log h.inspect ' : ' + ($!).inspect
        end
            
      end
              
    end
  end

  def reload_entries(buffer)    

    load_entries Dynarex.new(buffer)
    @buffer = buffer
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

    RunEvery.new(seconds: 60) { iterate @cron_events }
    
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