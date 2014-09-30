#!/bin/bash
# this is to give supervisor time to start mongo because graylog2-server
# does not retry connections (yet)
sleep 30 && /usr/bin/java -jar /usr/share/graylog2-server/graylog2-server.jar
