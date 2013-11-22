# Introducing the Dynarex Cron gem

    require 'dynarex_cron'

    crontab =<<CRON
    <?dynarex schema="entries[title]/entry(expression, job, description)" format_mask="[!expression][.,] [!job] # [!description]"?>
    title: A Sample Dynarex Cron file

    at 10:54pm every day, pub aida: set light off
    every 2 minutes. publish magic: testing 123 simplepubsub
    9:00-18:00 every day, pub fortina: pips # play the hourly pips
    CRON

    dc = DynarexCron.new(Dynarex.parse crontab)
    dc.start

The above example runs a scheduler which checks for jobs to run every minute.

## Resources

* [jrobertson/dynarex_cron](https://github.com/jrobertson/dynarex_cron)

dynarexcron gem crontab cron
