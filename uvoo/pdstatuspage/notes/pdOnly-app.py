#!/usr/bin/env python3
import os
import requests
from flask import Flask, abort, jsonify, render_template, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from datetime import datetime, timedelta
import ipaddress

app = Flask(__name__)

PAGERDUTY_API_TOKEN = os.getenv('PAGERDUTY_API_TOKEN')
PAGERDUTY_SERVICES = os.getenv('PAGERDUTY_SERVICES').split(',')
LIMITER = os.getenv('LIMITER')
ALLOWED_CIDRS = os.getenv('ALLOWED_CIDRS')
if ALLOWED_CIDRS:
    ALLOWED_CIDRS_LIST = ALLOWED_CIDRS.split(',')

limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["200 per day", "50 per hour"]
)

def fetch_incidents(service_id):
    url = "https://api.pagerduty.com/incidents"
    headers = {
        "Authorization": f"Token token={PAGERDUTY_API_TOKEN}",
        "Accept": "application/vnd.pagerduty+json;version=2"
    }
    since = (datetime.utcnow() - timedelta(days=90)).strftime('%Y-%m-%dT%H:%M:%SZ')
    params = {
        "service_ids[]": service_id,
        "since": since,
        "statuses[]": ["triggered", "acknowledged", "resolved"]
    }
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    return response.json().get('incidents', [])

def calculate_availability(incidents):
    total_downtime = 0
    total_time = 90 * 24 * 60 * 60  # 90 days in seconds

    for incident in incidents:
        created_at = datetime.strptime(incident['created_at'], '%Y-%m-%dT%H:%M:%SZ')
        resolved_at = datetime.strptime(incident['resolved_at'], '%Y-%m-%dT%H:%M:%SZ') if incident.get('resolved_at') else datetime.utcnow()
        downtime = (resolved_at - created_at).total_seconds()
        total_downtime += downtime

    availability = ((total_time - total_downtime) / total_time) * 100
    return availability

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/incidents')
def api_incidents():
    all_incidents = []
    for service_id in PAGERDUTY_SERVICES:
        incidents = fetch_incidents(service_id)
        all_incidents.extend(incidents)
    return jsonify(all_incidents)

@app.route('/api/availability')
def api_availability():
    all_incidents = []
    for service_id in PAGERDUTY_SERVICES:
        incidents = fetch_incidents(service_id)
        all_incidents.extend(incidents)
    availability = calculate_availability(all_incidents)
    return jsonify({"availability": availability})

@app.route('/api/incident_status')
@limiter.limit(LIMITER)
def api_incident_status():
    client_ip = request.remote_addr
    if not any(ipaddress.ip_network(cidr).supernet_of(ipaddress.ip_network(client_ip)) for cidr in ALLOWED_CIDRS_LIST):
        abort(403)

    all_incidents = []
    for service_id in PAGERDUTY_SERVICES:
        incidents = fetch_incidents(service_id)
        all_incidents.extend(incidents)

    service_status = {}
    for incident in all_incidents:
        service_id = incident['service']['id']
        service_summary = incident['service']['summary']
        if service_id not in service_status:
            service_status[service_id] = {
                'title': service_summary,
                'incidents': []
            }
        service_status[service_id]['incidents'].append({
            'id': incident['id'],
            'created_at': incident['created_at'],
            'resolved_at': incident.get('resolved_at'),
            'status': incident['status']
        })

    return jsonify(service_status)

@app.route('/api/incident_status_by_day')
def api_incident_status_by_day():
    all_incidents = []
    for service_id in PAGERDUTY_SERVICES:
        incidents = fetch_incidents(service_id)
        all_incidents.extend(incidents)

    service_status_by_day = {}
    today = datetime.today()
    ninety_days_ago = today - timedelta(days=90)

    for incident in all_incidents:
        service_id = incident['service']['id']
        service_summary = incident['service']['summary']
        date = incident['created_at'].split('T')[0]
        incident_date = datetime.strptime(date, '%Y-%m-%d')
        if incident_date < ninety_days_ago:
            continue

        if service_id not in service_status_by_day:
            service_status_by_day[service_id] = {
                'title': service_summary,
                'dates': {}
            }
        if date not in service_status_by_day[service_id]['dates']:
            service_status_by_day[service_id]['dates'][date] = 0
        if incident['status'] in ['triggered', 'acknowledged', 'resolved']:
            service_status_by_day[service_id]['dates'][date] = 1

    for service_id in service_status_by_day:
        dates = service_status_by_day[service_id]['dates']
        current_date = ninety_days_ago
        while current_date <= today:
            date_str = current_date.strftime('%Y-%m-%d')
            if date_str not in dates:
                dates[date_str] = 0
            current_date += timedelta(days=1)

    return jsonify(service_status_by_day)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8080)
