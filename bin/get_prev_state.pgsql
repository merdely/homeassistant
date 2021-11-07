#!/usr/bin/env python3

import os
import psycopg2
import re
import sys

secrets = os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0]))) + '/secrets.yaml'
with open(secrets, 'r') as file:
    for line in file.readlines():
        m = re.search(r'pgsql_uri: postgresql://([^:]+):([^@]+)@([^/]+)/(.+)$', line)
        if m:
            sqlusername = m.group(1)
            sqlpassword = m.group(2)
            sqlhostname = m.group(3)
            sqldatabase = m.group(4)
file.close()

if len(sys.argv) < 3:
    print('Usage: ' + sys.argv[0] + ' entity_id current_state')
    quit()
else:
    entity_id = sys.argv[1]
    current_state = sys.argv[2]

try:
   conn = psycopg2.connect(user=sqlusername,
                           password=sqlpassword,
                           host=sqlhostname,
                           port="5432",
                           database=sqldatabase)
   cursor = conn.cursor()
   query = "SELECT state FROM states WHERE entity_id = '{}' AND states.last_updated = (SELECT MAX(states2.last_updated) FROM states AS states2 WHERE states2.entity_id = states.entity_id AND state != '{}');".format(entity_id, current_state)

   cursor.execute(query)
   rows = cursor.fetchall() 
   if len(rows) > 0:
       prev_location = rows[0][0]

except (Exception, psycopg2.Error) as error :
    print ("Error while fetching data from PostgreSQL", error)

finally:
    #closing database connection.
    if(conn):
        cursor.close()
        conn.close()

try:
    print(prev_location)
except:
    print(current_state)

