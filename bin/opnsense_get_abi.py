#!/usr/bin/env python3
import requests
from bs4 import BeautifulSoup

# URL of the webpage
url = 'https://opnsense.org/download/'

# Download the webpage
response = requests.get(url)

# Check if the request was successful
if response.status_code == 200:
    # Parse the HTML content
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Find the select element with id="type"
    select_element = soup.find('select', id='type')
    
    # Extract the data-version attribute
    if select_element and select_element.has_attr('data-version'):
        version = select_element['data-version']
        print(version)
    else:
        print("Select element with id='type' or data-version attribute not found")
else:
    print(f"Failed to retrieve the webpage. Status code: {response.status_code}")
