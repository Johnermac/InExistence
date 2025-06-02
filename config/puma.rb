# config/puma.rb

bind "tcp://127.0.0.1:3000"

environment ENV.fetch("RAILS_ENV") { "development" }

workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

preload_app!

plugin :tmp_restart
