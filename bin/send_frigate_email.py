#!/usr/bin/env python3

from datetime import datetime
from email.message import EmailMessage
from email.utils import make_msgid
from PIL import Image
import os
import re
import smtplib
import sys
import time

progname = "send_frigate_email"
camera = eventid = smtp_username = smtp_password = frigate_from = frigate_to = ""

if len(sys.argv) < 4:
    print('Usage: ' + sys.argv[0] + ' detected_object camera eventid')
    quit()
else:
    detected_object = sys.argv[1]
    camera = sys.argv[2]
    eventid = sys.argv[3]

t = datetime.now()
print(f"{t.strftime('%F %T.000')} INFO (shell_command) [{progname}] starting up for {camera}")
# camera = "Front_Door_2"
# eventid = "1679583332.565713-8tz0fo"
# detected_object = "Person"

MAXWAIT = 30
port = 465
image = f"/media/frigate/clips/{camera}-{eventid}.jpg"
camtitle = camera.replace("_", " ")

secrets = os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0]))) + '/secrets.yaml'
with open(secrets, 'r') as file:
    for line in file.readlines():
        m = re.search(r'^([a-zA-Z0-9_]+): (.*)$', line)
        if m and m.group(1) == "smtp_server":
            smtp_server = m.group(2)
        if m and m.group(1) == "smtp_username":
            smtp_username = m.group(2)
        if m and m.group(1) == "smtp_password":
            smtp_password = m.group(2)
        if m and m.group(1) == "frigate_from":
            frigate_from = m.group(2)
        if m and m.group(1) == "frigate_to":
            frigate_to = m.group(2)
file.close()

if smtp_username == "" or smtp_password == "" or frigate_from == "" or frigate_to == "":
    t = datetime.now()
    print(f"{t.strftime('%F %T.000')} ERROR (shell_command) [{progname}] smtp_username or smtp_password not set")
    sys.exit(1)

# Wait up to MAXWAIT seconds for file to exist
waited = 0
while not os.path.exists(image):
    time.sleep(1)
    waited += 1
    if waited >= MAXWAIT:
        t = datetime.now()
        print(f"{t.strftime('%F %T.000')} ERROR (shell_command) [{progname}] Waited for {image} to exist for {waited} seconds")
        sys.exit(1)

message = EmailMessage()
message['Subject'] = f"{camtitle} Camera"
message['From'] = frigate_from
message['To'] = frigate_to
message.set_content(f"{detected_object.title()} detected\nImages from {camtitle} Camera\n")
figure_id = make_msgid()
message.add_alternative("""\
<html>
<head></head>
<body>
<p>{detected_object} detected<br />
Images from {camtitle} Camera</p>
</body>
</html>""".format(detected_object=detected_object.title(), camtitle=camtitle), subtype="html")

with open(image, "rb") as img:
    image_data = img.read()
with Image.open(image) as pilimg:
    image_type = pilimg.format.lower()
message.add_attachment(image_data, maintype="image", subtype=image_type, filename=os.path.basename(img.name))
img.close()

# Attach any newer images too
for file in os.listdir(os.path.dirname(image)):
    if re.search("^" + camera + r"-.*\.jpg", file):
        if os.path.getmtime(os.path.dirname(image) + "/" + file) > os.path.getmtime(image):
            with open(os.path.dirname(image) + "/" + file, "rb") as img:
                image_data = img.read()
            with Image.open(os.path.dirname(image) + "/" + file) as pilimg:
                image_type = pilimg.format.lower()
            message.add_attachment(image_data, maintype="image", subtype=image_type, filename=os.path.basename(img.name))
            img.close()

## Include in email to embed image inline
#<img src="cid:{figure_id}" />
#.format(..., figure_id=figure_id[1:-1], ...)
#with open(image, "rb") as img:
#    message.get_payload()[1].add_related(img.read(), 'image', 'jpeg', cid=figure_id)

with smtplib.SMTP_SSL(smtp_server, port) as smtp:
    smtp.connect(smtp_server, port)
    smtp.login(smtp_username, smtp_password)
    smtp.send_message(message)

