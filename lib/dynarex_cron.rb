#!/usr/bin/env ruby

# file: dynarex_cron.rb

require 'dynarex'
require 'chronic_cron'
require 'sps-pub'
require 'logger'


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
    
    @cron_entries = []
    
    @dynarex_file = dynarex_file

    if @dynarex_file then

      dynarex = load_doc dynarex_file
      load_entries(dynarex)
    end 

    @sps_address, @sps_port = opt[:sps_address], opt[:sps_port]
    @pub = SPSPub.new address: @sps_address, port: @sps_port
    
  end

  def start

    @running = true
    puts '[' + (Time.now + @time_offset).strftime(DF) + '] DynarexCron started'
    params = {uri: "ws://%s:%s" % [@sps_address, @sps_port]}
    

    sleep 1 until Time.now.sec == 0

    # the following loop runs every minute
    while true do

      iterate @cron_entries

      if @dynarex_file.is_a? String then

        # What happens if the @dynarex_file is a URL and the web server is 
        # temporarily unavailable? i.e. 503 Service Temporarily Unavailable
        begin
          buffer, _ = RXFHelper.read(@dynarex_file)
          reload_entries buffer if @buffer != buffer          
        rescue
          puts 'dynarex_cron: warning: ' + ($!).inspect           
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
      @buffer, _ = RXFHelper.read(dynarex_file)
      Dynarex.new @buffer
    end
        
  end

  def load_entries(dynarex)
    
    if dynarex.summary[:sps_address] then
      @sps_address, @sps_port = dynarex.summary[:sps_address]\
                                                    .split(':',2) << '59000'
    end
    
    @cron_entries = dynarex.to_h
    @cron_entries.each do |h| 
      h[:cron] = ChronicCron.new(h[:expression], Time.now + @time_offset)
    end
  end  
  
  def log(s, method_name=:debug)
    return unless @logger
    @logger.method(method_name).call s
  end

  def iterate(cron_entries)
    
    cron_entries.each do |h|
      
      datetime = (Time.now + @time_offset).strftime(DF)
      
      if h[:cron].to_time.strftime(DF) == datetime then

        begin

          @pub.notice h[:fqm].gsub('!Time',Time.now.strftime("%H:%M"))          

        rescue
          log 'cron ' + h[:cron].inspect, :info
          log h.inspect + ' : ' + ($!).inspect

        end
        
        h[:cron].next # advances the time
            
      end

    end
  end

  def reload_entries(buffer)    

    load_entries Dynarex.new(buffer)
    @buffer = buffer
  end   
  
end