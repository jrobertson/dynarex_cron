#!/usr/bin/env ruby

# file: dynarex_cron.rb

require 'dynarex'
require 'chronic_cron'
require 'simplepubsub'
require 'rscript'
require 'chronic_duration'

DF = "%Y-%m-%d %H:%M"

class DynarexCron

  def initialize(dynarex_file=nil, options={})
    
    opt = {sps_address: nil, drb_server: false}.merge options
    
    @cron_entries, @cron_events  = [], []
    
    @dynarex_file = dynarex_file
    load_entries() if @dynarex_file    
    load_events() if @include_url

    @sps_address = opt[:sps_address]
    
    if opt[:drb_server] == true then
      
      Thread.new {
        
        # start up the DRb service
        DRb.start_service 'druby://:57000', self

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
        h[:cron].next # advances the time
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

  def initialize(dynarex_file=nil, options={})
    
    opt = {sps_address: nil, drb_server: false}.merge options
    
    @cron_events  = []
    
    @dynarex_file = dynarex_file
    load_events()

    @sps_address = opt[:sps_address]
    
    if opt[:drb_server] == true then
      
      Thread.new {
        
        # start up the DRb service
        DRb.start_service 'druby://:57500', self

        # wait for the DRb service to finish before exiting
        DRb.thread.join    
      }
    end
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
    
    while @running == true
      iterate @cron_events
      sleep 60 # wait for 60 seconds
    end
  end  
  
  def to_a()
    
    @entries.inject([]) do |r,h| 

      h[:cron] = ChronicCron.new(h[:date]) 
      h[:job] = 'pub event: ' + h[:title]

      if h[:reminder].length > 0 then
        rmndr = {}
        rmndr[:cron] = ChronicCron.new((Chronic.parse(h[:date]) - ChronicDuration.parse(h[:reminder])).to_s)
        rmndr[:job] = 'pub event: reminder ' + h[:title]
        r << rmndr
      end

      r << h
    end
    
  end
end
