#!/bin/bash -ex
sleep 5
cd /vagrant
mongo --port 45452 < setup_db.js
npm install
npm install -g grunt-cli mocha
grunt deployTest