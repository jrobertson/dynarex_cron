# Introducing the Dynarex Cron gem

    require 'dynarex_cron'

    crontab =<<CRON
    <?dynarex schema="entries[title]/entry(expression, job, description)" format_mask="[!expression][.,] [!job] # [!description]"?>
    title: A Sample Dynarex Cron file

    at 10:30pm on every Monday. Time.now.to_s
    at 10:30pm on every Friday. %(fun ) + Time.now.to_s
    every 10 minutes. `date > /home/james/hello`
    every 2 minutes. publish magic: testing 123 simplepubsub
    */5 * * * *. `/usr/bin/ruby /home/james/ruby/network_check.rb`
    on 8th August at 10:30am, run //job:download_rss_enclosure http://a0.jamesrobertson.eu/qbx/r/audio.rsf http://feed.nashownotes.com/rss.xml na
    CRON

    dc = DynarexCron.new(Dynarex.parse crontab)
    dc.start

The above example runs a scheduler which checks for jobs to run every minute.

dynarexcron gem crontab cron

