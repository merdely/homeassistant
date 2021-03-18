#!/usr/bin/env python3
from datetime import datetime
from OpenSSL import crypto

pem = open('/ssl/fullchain.pem', 'rt').read()
cert = crypto.load_certificate(crypto.FILETYPE_PEM, pem)

print(datetime.strptime(cert.get_notAfter().decode('utf-8'), "%Y%m%d%H%M%SZ").strftime("%F %T"))