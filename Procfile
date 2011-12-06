web: bundle exec thin start -R config.ru -p $PORT -e $RACK_ENV
worker: VERBOSE=1 QUEUE=* bundle exec rake queue:work
