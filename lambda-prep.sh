#!/bin/bash

# Prep Code for fill_queue_priority Lambda
pip3 install -r ./fill_queue/requirements.txt -t fill_queue_build
cp -r fill_queue/* fill_queue_build
cd fill_queue_build; zip -r ../fill_queue_build.zip *
cd ..

# Prep Code for ping Lambda
pip3 install -r ./ping/requirements.txt -t ping_build
cp -r ./ping/* ping_build
cd ping_build; zip -r ../ping_build.zip *
cd ..