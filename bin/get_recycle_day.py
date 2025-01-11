#!/usr/bin/env python3

import requests
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
import json
import os
import re
import sys

secrets = os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0]))) + '/secrets.yaml'
with open(secrets, 'r') as file:
    for line in file.readlines():
        m = re.search(r"^recycle_(default_day|street_number|street_name|street_type): '?([^']+)'?$", line)
        if m and m.group(1) == 'default_day':
            default_day = m.group(2).strip()
        elif m and m.group(1) == 'street_number':
            street_number = m.group(2).strip()
        elif m and m.group(1) == 'street_name':
            street_name = m.group(2).strip()
        elif m and m.group(1) == 'street_type':
            street_type = m.group(2).strip()
file.close()

collection_day_url = "https://www2.montgomerycountymd.gov/depcollectionday/default.aspx"
holiday_url = "https://www.montgomerycountymd.gov/dep/trash-recycling/holidays.html"

debug = False

moco_code = holidays_code = exception_code = 0
moco_address = ""
is_holiday = False
has_exception = False

weekday_mapping = {
    "Monday": 0,
    "Tuesday": 1,
    "Wednesday": 2,
    "Thursday": 3,
    "Friday": 4,
    "Saturday": 5,
    "Sunday": 6
}

def days_string(num_days):
    if num_days == 0:
        return "Today"
    elif num_days == 1:
        return "Tomorrow"
    else:
        return f"{num_days} days"

def add_days(weekday, num_days):
    global weekday_mapping

    reverse_mapping = {v: k for k, v in weekday_mapping.items()}

    # Get the integer value of the starting weekday
    start_day_index = weekday_mapping[weekday]

    # Add the number of days and calculate the resulting weekday index
    resulting_day_index = (start_day_index + num_days) % 7

    # Get the resulting weekday name
    resulting_day = reverse_mapping[resulting_day_index]

    return resulting_day

def get_weekday(date):
    date_obj = datetime.strptime(date, "%Y-%m-%d")
    return date_obj.strftime("%A")

def get_weekday_num(date):
    date_obj = datetime.strptime(date, "%Y-%m-%d")
    return date_obj.weekday()

def next_weekday(weekday):
    global weekday_mapping

    # Get today's date
    today = datetime.today()
    if today.strftime("%A") == weekday:
        return today.strftime("%Y-%m-%d")

    # Convert the input weekday to an integer (0=Monday, ..., 6=Sunday)
    target_weekday = weekday_mapping[weekday]

    # Calculate the number of days to add to get to the next occurrence
    days_to_next = (target_weekday - today.weekday() + 7) % 7
    if days_to_next == 0:  # If today is the target day, go to the next week
        days_to_next = 7

    # Calculate the next occurrence
    next_date = today + timedelta(days=days_to_next)

    return next_date.strftime("%Y-%m-%d")  # Format the date as YYYY-MM-DD

def days_between(date_str):
    # Define today's date
    today = datetime.strptime("2025-01-10", "%Y-%m-%d")  # Replace with `datetime.today()` for dynamic today

    # Convert the input date string to a datetime object
    input_date = datetime.strptime(date_str, "%Y-%m-%d")

    # Calculate the difference in days
    delta = (input_date - today).days

    return delta

def get_recycle_day(default_day, street_number, street_name, street_type):
    global collection_day_url
    #params2 = {
    #        "__EVENTTARGET": "",
    #        "__EVENTARGUMENT": "",
    #        "__VIEWSTATEGENERATOR": "23FD2674",
    #        "ctl00_MainContent_ScriptManager1_HiddenField": ";;AjaxControlToolkit,+Version=3.5.7.429,+Culture=neutral,+PublicKeyToken=28f01b0e84b6d53e:en-US:776e8b41-f645-445e-b0a0-73e096383cec:f2c8e708:de1feab2:720a52bf:f9cec9bc:589eaa30:698129cf:7a92f56c",
    #        "hiddenInputToUpdateATBuffer_CommonToolkitScripts": 0,
    #        }
    params = {
            "__VIEWSTATE": "/wEPDwUKLTc2NTM3NDM5OWQYAQUVY3RsMDAkTWFpbkNvbnRlbnQkZ3JkD2dk5XLs8wPLP1gyIgKbcYV7CduFiws=",
            "__EVENTVALIDATION": "/wEWJALB0ureBQLliZf0AwLr0My5DgKAuJmLBAKc4sQ6ApDkoY8FAvqJiKgHAo217/sLAuzc6OQGAo7k1eQLAt3Xw/sIAo21k/oLAt3Xy/sIAtzX+/sIApOjvtAGAvHK4+UCAtWCy80PAoq16/kFAqXi6DoCpZGhzgEC5Ner+wgC89y4igkCmqPGzgUCn5GJ3AoCk/iHuQkCp6PW3gwC8Nej+wgCyPvizQoC7teD+wgC4sPy5A0C7df/+wgC7dfD+wgCnLXf+wsCqpGlzgECpuLQOgLT8MqYCPXFTuNiLbRK1JHXgzCZj0oXSuqy",
            "ctl00$MainContent$txtStreetNumber": street_number,
            "ctl00$MainContent$txtStreet": street_name,
            "ctl00$MainContent$DropDownList1": street_type,
            "ctl00$MainContent$Button1": "Search",
            }
    response = requests.get(collection_day_url, params=params)
    if response.status_code == 200:
        soup = BeautifulSoup(response.text, "html.parser")

        moco_address = ""
        found = False
        # Search <h1> tags for address
        h1_tags = soup.find_all('h1')
        for h1_tag in h1_tags:
            moco_address = h1_tag.get_text(strip=True)
            if street_name.lower() in moco_address.lower():
                found = True
                break

        if not found:
            #print(f"Warning: Could not find recycle day for {street_number} {street_name} {street_type}")
            return (default_day, moco_address, response.status_code)

        # Find all rows
        rows = soup.select('tbody tr')

        for row in rows:
            # Find the "Service" cell containing "Recycling"
            service_cell = row.find('td', {'data-title': 'Service'})
            if service_cell and 'Recycling' in service_cell.get_text():
                # Find the corresponding "Day" cell
                day_cell = row.find('td', {'data-title': 'Day'})
                if day_cell:
                    # Extract the day value
                    return (day_cell.get_text(strip=True), moco_address, response.status_code)
    else:
        #print(f"Warning: Could not get recycle day ({response.status_code})")
        return (default_day, moco_address, response.status_code)

def get_exception(pickup_day):
    global holiday_url
    response = requests.get(holiday_url)
    if response.status_code == 200:
        soup = BeautifulSoup(response.text, "html.parser")
        script_tags = soup.find_all('script')
        for script_tag in script_tags:
            script_content = script_tag.string
            if script_content:
                match = re.search(r'\.load\("([^"]*(?:alert|warning)[^"]*)"\)', script_content, re.IGNORECASE)
                if match:
                    #print(f"Matched alert URL: {match.group(1)}")
                    alert_response = requests.get(match.group(1))
                    if alert_response.status_code == 200:
                        alert_soup = BeautifulSoup(alert_response.text, "html.parser")
                        paragraphs = alert_soup.find_all('p') #, string='this week') #re.compile('this', re.IGNORECASE))
                        for paragraph in paragraphs:
                            match = re.search(r'this week', paragraph.text)
                            if match:
                                #match = re.search(rf'{pickup_day}.*slide.*((?:Sun|Mon|Tues|Wed|Thurs|Fri|Satur)day(?:, \w+ \d{1,2}))', paragraph.text)
                                match = re.search(r'%s.*slide.*((?:Sun|Mon|Tues|Wed|Thurs|Fri|Satur)day(?:, \w+ \d{1,2}))' % pickup_day, paragraph.text, re.IGNORECASE)
                                if match:
                                    match2 = re.match(r"\w+, \w+ \d{1,2}", match.group(1), re.IGNORECASE)
                                    if match2:
                                        #print(f"{match.group(1)}, {datetime.now().strftime('%Y')}")
                                        return (datetime.strptime(f"{match.group(1)}, {datetime.now().strftime('%Y')}", f"%A, %B %d, %Y").strftime("%F"), True, alert_response.status_code)
                                    else:
                                        return (next_weekday(match.group(1)), True, alert_response.status_code)
                    else:
                        return (next_weekday(pickup_day), False, alert_response.status_code)
    return (next_weekday(pickup_day), False, 0)

def get_holidays():
    global holiday_url
    holidays = {}
    count = found = 0
    response = requests.get(holiday_url)
    if response.status_code == 200:
        soup = BeautifulSoup(response.text, "html.parser")
        h3_tags = soup.find_all('h3')
        for h3_tag in h3_tags:
            txt = h3_tag.get_text(strip=True)
            count += 1
            match = re.match(r"^(.*), (\w+, \w+ \d{1,2}, \d{4})$", txt, re.IGNORECASE)
            if match:
                try:
                    date_obj = datetime.strptime(match.group(2), "%A, %B %d, %Y")
                except:
                    print(f"Warning: Could not read date string: {match.group(2)}")
                    date_obj = None
                holidays[match.group(1)] = {
                        "date_string": match.group(2),
                        "date_obj": date_obj,
                        "year": date_obj.year,
                        "dow": date_obj.strftime("%A"),
                        "dom": date_obj.day,
                        "woy": date_obj.isocalendar()[1],
                        }
                found += 1
        #print(f"count={count}, found={found}")
        return (holidays, response.status_code)

def holiday_slide(pickup_day):
    day = pickup_day
    change = False
    holidays, holidays_code = get_holidays()
    for holiday in holidays:
        if holidays[holiday]["woy"] == datetime.now().isocalendar()[1]:
            day = add_days(pickup_day, 1)
            change = True
            break
    return (day, change, holidays_code)

# Run code here
recycle_day = default_day
recycle_date = next_weekday(recycle_day)
recycle_days = days_between(recycle_date)
if debug:
    print(f"Default day is {recycle_day}")
    print(f"Default date is {recycle_date} ({recycle_days})")
    print()

moco_day, moco_address, moco_code = get_recycle_day(default_day, street_number, street_name, street_type)
recycle_day = moco_day
recycle_date = next_weekday(recycle_day)
recycle_days = days_between(recycle_date)
if debug:
    print(f"Recycle day is {recycle_day}")
    print(f"Recycle date is {recycle_date} ({recycle_days})")
    print()

holiday_day, is_holiday, holidays_code = holiday_slide(recycle_day)
recycle_day = holiday_day
recycle_date = next_weekday(recycle_day)
recycle_days = days_between(recycle_date)
if debug:
    print(f"Holiday adjusted day is {recycle_day}")
    print(f"Holiday adjusted date is {recycle_date} ({recycle_days})")
    print()

recycle_date, has_exception, exception_code = get_exception(recycle_day)
recycle_day = get_weekday(recycle_date)
recycle_days = days_between(recycle_date)
if debug:
    print(f"Exception adjusted day is {recycle_day}")
    print(f"Exception adjusted day is {recycle_date} ({recycle_days})")

    print()

print(json.dumps({
    "default_day": default_day,
    "moco_day": moco_day,
    "holiday_day": holiday_day,
    "exception_day": recycle_day,
    "recycle_day": recycle_day,
    "recycle_day_num": get_weekday_num(recycle_date),
    "recycle_date": recycle_date,
    "recycle_days": recycle_days,
    "days_string": days_string(recycle_days),
    "is_holiday": is_holiday,
    "has_exception": has_exception,
    "address": f"{street_number} {street_name} {street_type.title()}",
    "moco_address": moco_address,
    "moco_code": moco_code,
    "holidays_code": holidays_code,
    "exception_code": exception_code,
    }))
