#!/usr/bin/env ruby

# file: dynarex_cron.rb

require 'dynarex'
require 'chronic_cron'
require 'simplepubsub'
require 'rscript'
require 'chronic_duration'
require 'logger'

DF = "%Y-%m-%d %H:%M"

class DynarexCron

  # options: e.g. sps_address, 'sps', drb_server: 57000
  #
  def initialize(dynarex_file=nil, options={})
    
    opt = {sps_address: nil, drb_server: nil, log: nil}.merge options
    @logger = Logger.new(opt[:log],'weekly') if opt[:log]
    
    @cron_entries, @cron_events  = [], []
    
    @dynarex_file = dynarex_file
    load_entries() if @dynarex_file    
    load_events() if @include_url

    @sps_address = opt[:sps_address]
    
    if opt[:drb_server] then
      
      Thread.new {
        
        # start up the DRb service
        DRb.start_service 'druby://:' + opt[:drb_server], self

        # wait for the DRb service to finish before exiting
        DRb.thread.join    
      }
    end
  end

  def start
    @running = true
    puts '[' + Time.now.strftime(DF) + '] DynarexCron started'
    
    while @running == true

      iterate @cron_entries
      iterate @cron_events
      sleep 60 # wait for 60 seconds
    end
  end
  
  def stop()
    @running = false
  end
  
  def load_entries()
    
    dynarex = Dynarex.new @dynarex_file
    
    @include_url = dynarex.summary[:include]
    @cron_entries = dynarex.to_h
    @cron_entries.each {|h| h[:cron] = ChronicCron.new(h[:expression]) }    
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
      
      if h[:cron].to_time.strftime(DF) == Time.now.strftime(DF) then
        
        Thread.new { run(h[:job]) }
        begin
          h[:cron].next # advances the time
        rescue
          
          @logger.debug h.inspect ' : ' + ($!) if @logger
        end
        
      end
    end        
  end  
  
  def run(job)

    case job

      when /^(run )/
        code2, args = RScript.new.read ($').scan(/[^'"]+/).map(&:strip)
        eval code2

      when /^(pub\s*(?:lish)?\s+)/

        return unless @sps_address
        SimplePubSub::Client.connect(@sps_address) do |client|
          topic, msg = ($').split(/:\s*/,2)
          client.publish(topic, msg)
        end

      when /^`([^`]+)/
        `#{$1}`

      when %r{http://}
        open(s, 'UserAgent' => 'DynarexCron v0.1')

      else
        eval(s)
    end

  end

end


class DynarexEvents < DynarexCron

  attr_reader :to_a

  # options: e.g. sps_address, 'sps', drb_server: 58000
  #
  def initialize(dynarex_file=nil, options={})
    
    opt = {sps_address: nil, drb_server: nil}.merge options
    
    @entries, @cron_events  = [], []

    @dynarex_file = dynarex_file
    load_events()

    @sps_address = opt[:sps_address]
    
    if opt[:drb_server] then

      Thread.new {
        
        # start up the DRb service
        DRb.start_service 'druby://:' + opt[:drb_server], self

        # wait for the DRb service to finish before exiting
        DRb.thread.join    
      }
    end
  end    

  def add_entry(h)
    # if the entry already exists delete it
    @entries.delete @entries.find {|x| x[:job] == h[:job]}
    @entries << h
  end

  def load_events()
    
    dynarex = Dynarex.new @dynarex_file
    @entries = dynarex.to_h || @entries
    @cron_events = self.to_a if @entries
    'events loaded and refreshed'
  end  
  
  alias refresh load_events
  
  def start
    @running = true
    puts '[' + Time.now.strftime(DF) + '] DynarexEvents started'
    
    while @running == true
      iterate @cron_events
      sleep 60 # wait for 60 seconds
    end
  end  
  
  def to_a()

    return unless @entries

    @entries.inject([]) do |r,h| 

      h[:cron] = ChronicCron.new(h[:date] + ' ' + h[:recurring].to_s ) 
      h[:job] ||= 'pub event: ' + h[:title]

      if h[:reminder].to_s.length > 0 then
        rmndr = {}
        rmndr[:cron] = ChronicCron.new((Chronic.parse(h[:date]) - ChronicDuration.parse(h[:reminder])).to_s)
        rmndr[:job] = 'pub event: reminder ' + h[:title]
        r << rmndr
      end

      r << h
    end
    
  end
end