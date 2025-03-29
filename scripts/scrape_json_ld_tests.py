#!/usr/bin/python3

import json
import os.path
import re
import requests
from bs4 import BeautifulSoup as bs

JCS_TESTS = [
  '#tjs09',
  '#tjs10',
  '#tjs11',
  '#tjs12',
  '#tjs13'
]

def get_page_contents(url):
  headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36'
  }
  page = requests.get(url, headers=headers)
  if page.status_code == 200:
    # This is SUPER important. requests likes to use ISO-8859-1
    page.encoding = 'utf-8'
    return page.text

  return None

def get_test_entries(page_contents):
  soup = bs(page_contents, 'html.parser')
  return soup.find_all('dl', class_='entry')

def parse_test(entry):
  dts = entry.find_all('dt')
  dds = entry.find_all('dd')
  count = len(dts)
  id = None
  purpose = None
  input_url = None
  output_url = None
  for i in range(count):
    dt = dts[i].text.lower()
    dd = dds[i]
    if dt == 'id':
      id = dd.text
      if id not in JCS_TESTS:
        return None
    elif dt == 'purpose':
      purpose = dd.text
    elif dt == 'input':
      link = dd.find('a', href=True)
      if link:
        input_url = link['href']
    elif dt == 'expect':
      link = dd.find('a', href=True)
      if link:
        output_url = link['href']

  if id and purpose and input_url and output_url:
    print(f'parsed test {id}: {purpose}')
    entry = {'id': id, 'description': purpose, 'input_url': input_url, 'output_url': output_url}
    return entry

  return None

def download_tjs_tests(base_url, relative_url):
  nq_pattern = ' "(.+)"' + re.escape('^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#JSON')
  page_contents = get_page_contents(base_url + relative_url)
  entries = get_test_entries(page_contents)
  for entry in entries:
    test = parse_test(entry)
    if test:
      input_file_name = 't' + os.path.basename(test['input_url']).replace('-in.jsonld', '.json')
      input_json = get_page_contents(base_url + test['input_url'])
      e = json.loads(input_json)['e']
      f = open(f'../test/fixtures/input/{input_file_name}', 'w', encoding='utf-8')
      json.dump(e, f, ensure_ascii=False, indent=2)
      f.write("\n")
      f.close()

      output_file_name = 't' + os.path.basename(test['output_url']).replace('-out.nq', '.json')
      output_nq = get_page_contents(base_url + test['output_url'])
      m = re.search(nq_pattern, output_nq)
      if m:
        output_json = m[1].replace('\\"', '"').replace('\\\\', '\\')
        f = open(f'../test/fixtures/output/{output_file_name}', 'w', encoding='utf-8')
        f.write(output_json)
        f.close()

if __name__ == '__main__':
  download_tjs_tests('https://w3c.github.io/json-ld-api/tests/', 'toRdf-manifest')