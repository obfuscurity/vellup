web: bundle exec thin start -R config-web.ru -p $PORT -e $RACK_ENV
api: bundle exec thin start -R config-api.ru -p $PORT -e $RACK_ENV
worker: VERBOSE=1 QUEUE=* bundle exec rake queue:work
