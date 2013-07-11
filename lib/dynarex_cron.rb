#!/usr/bin/env ruby

# file: dynarex_cron.rb

require 'dynarex'
require 'chronic_cron'
require 'simplepubsub'
require 'rscript'

DF = "%Y-%m-%d %H:%M"

class DynarexCron

  def initialize(dynarex_file, sps_address=nil)
    @dynarex = Dynarex.new dynarex_file
    @dynarex.to_h.each {|h| puts 'h : ' + h.inspect; h[:cron] = ChronicCron.new(h[:expression]) }
    @sps_address = sps_address
  end

  def start
    puts '[' + Time.now.strftime(DF) + '] DynarexCron started'
    while true
      #puts Time.now.inspect
      @dynarex.to_h.each do |h|
        if h[:cron].to_time.strftime(TF) == Time.now.strftime(TF) then
          Thread.new { run(h[:job]) }
          t = h[:cron].next
          s2 = "next run time for job %s is %s" % [h[:job], t.strftime(TF)]
          puts s2
        end
      end
      sleep 60 # wait for 60 seconds
    end
  end

  private

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
