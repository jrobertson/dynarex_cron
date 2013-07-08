#!/usr/bin/env ruby

# file: dynarex_cron.rb

require 'run_every'
require 'dynarex'
require 'chronic_cron'

TF = "%Y-%m-%d %H:%M"

class DynarexCron

  def initialize(dynarex_file)
    @dynarex = Dynarex.new dynarex_file
    @dynarex.to_h.each {|h| h[:cron] = ChronicCron.new(h[:expression]) }
  end

  def start

    RunEvery.new.minute do
      @dynarex.to_h.each do |h|
        if h[:cron].to_time.strftime(TF) == Time.now.strftime(TF) then
          run(h[:job])
          h[:cron].next          
        end
      end
    end

  end

  private

  def run(job)
    puts eval job
  end

end
