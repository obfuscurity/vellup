web: bundle exec thin start -R config.ru -p $PORT -e $RACK_ENV
worker: QUEUE=* bundle exec rake queue:work
