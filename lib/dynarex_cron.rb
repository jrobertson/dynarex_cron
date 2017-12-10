#!/usr/bin/env ruby

# file: dynarex_cron.rb

require 'dynarex'
require 'chronic_cron'
require 'sps-pub'


DF = "%Y-%m-%d %H:%M"

class DynarexCron

  # options: e.g. sps_address: 'sps', sps_port: '59000'
  #
  def initialize(dxfile=nil, sps_address: 'sps', sps_port: '59000',  \
      log: nil, time_offset: 0)
    

    @dxfile, @sps_address, @sps_port, @log = dxfile, sps_address, sps_port, log

    # time_offset: used for testing a cron entry without having to change 
    #              the time of each entry
    @time_offset = time_offset.to_i
    
    @cron_entries = []
    

    if @dxfile then

      dynarex = load_doc dxfile
      load_entries(dynarex)
    end 

    @pub = SPSPub.new address: sps_address, port: sps_port
    
  end

  def start

    @running = true
    
    if @log then
      @log.info 'DynarexCron/start: Time.now: ' \
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
          buffer, _ = RXFHelper.read(@dxfile)
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
  

  def iterate(cron_entries)
    
    cron_entries.each do |h|
      
      datetime = (Time.now + @time_offset).strftime(DF)
      @log.info 'DynarexCron/iterate: datetime: ' + datetime if @log
      @log.info 'DynarexCron/iterate: cron.to_time: ' + h[:cron].to_time.strftime(DF) if @log
      
      if h[:cron].to_time.strftime(DF) == datetime then

        begin

          if h[:fqm].empty? and @log then
            @log.debug 'DynarexCron/iterate: no h[:fqw] found ' + h.inspect
          end
          
          msg = h[:fqm].gsub('!Time',Time.now.strftime("%H:%M"))

          @pub.notice msg

        rescue
          
          if @log then
            @log.debug 'DynarexCron/iterate: cron: ' + h[:cron].inspect
            @log.debug 'DynarexCron/iterate: h: ' + h.inspect + ' : ' \
                + ($!).inspect
          end
          
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
