#!/usr/bin/env python3
import os
import requests
import sqlite3
from flask import Flask, render_template, jsonify
from datetime import datetime, timedelta

app = Flask(__name__)

PAGERDUTY_API_TOKEN = os.getenv('PAGERDUTY_API_TOKEN')
PAGERDUTY_SERVICES = os.getenv('PAGERDUTY_SERVICES').split(',')

def fetch_incidents(service_id):
    url = "https://api.pagerduty.com/incidents"
    headers = {
        "Authorization": f"Token token={PAGERDUTY_API_TOKEN}",
        "Accept": "application/vnd.pagerduty+json;version=2"
    }
    params = {
        "service_ids[]": service_id,
        "statuses[]": ["triggered", "acknowledged", "resolved"]
    }
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    return response.json().get('incidents', [])

def init_db():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS incidents (
            id TEXT NOT NULL PRIMARY KEY,
            incident_number INTEGER,
            title TEXT,
            description TEXT,
            created_at DATETIME,
            updated_at DATETIME,
            status TEXT,
            incident_key TEXT,
            service_id TEXT,
            service_summary TEXT,
            assigned_via TEXT,
            last_status_change_at DATETIME,
            resolved_at DATETIME,
            first_trigger_log_entry_id TEXT,
            first_trigger_log_entry_summary TEXT,
            alert_counts_all INTEGER,
            alert_counts_triggered INTEGER,
            alert_counts_resolved INTEGER,
            is_mergeable BOOLEAN,
            urgency TEXT,
            self TEXT,
            html_url TEXT
        )
    ''')
    conn.commit()
    return conn

def sync_incidents():
    conn = init_db()
    cursor = conn.cursor()
    for service_id in PAGERDUTY_SERVICES:
        incidents = fetch_incidents(service_id)
        for incident in incidents:
            cursor.execute('''
                INSERT OR REPLACE INTO incidents (
                    id, incident_number, title, description, created_at, updated_at, status, incident_key, service_id, service_summary,
                    assigned_via, last_status_change_at, resolved_at, first_trigger_log_entry_id, first_trigger_log_entry_summary,
                    alert_counts_all, alert_counts_triggered, alert_counts_resolved, is_mergeable, urgency, self, html_url
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                incident['id'],
                incident['incident_number'],
                incident['title'],
                incident.get('description', ''),
                incident['created_at'],
                incident['updated_at'],
                incident['status'],
                incident.get('incident_key', ''),
                incident['service']['id'],
                incident['service']['summary'],
                incident.get('assigned_via', ''),
                incident['last_status_change_at'],
                incident.get('resolved_at', None),
                incident['first_trigger_log_entry']['id'],
                incident['first_trigger_log_entry']['summary'],
                incident['alert_counts']['all'],
                incident['alert_counts']['triggered'],
                incident['alert_counts']['resolved'],
                incident['is_mergeable'],
                incident['urgency'],
                incident['self'],
                incident['html_url']
            ))
    conn.commit()
    conn.close()

def calculate_availability():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()

    cursor.execute('SELECT created_at, resolved_at FROM incidents WHERE status != "resolved"')
    incidents = cursor.fetchall()

    total_downtime = 0
    total_time = 0

    for incident in incidents:
        created_at = datetime.strptime(incident[0], '%Y-%m-%dT%H:%M:%SZ')
        resolved_at = datetime.strptime(incident[1], '%Y-%m-%dT%H:%M:%SZ') if incident[1] else datetime.utcnow()
        downtime = (resolved_at - created_at).total_seconds()
        total_downtime += downtime

    total_time = 30 * 24 * 60 * 60  # 30 days in seconds

    availability = ((total_time - total_downtime) / total_time) * 100

    conn.close()
    return availability

sync_incidents()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/incidents')
def api_incidents():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('SELECT created_at, COUNT(*) FROM incidents GROUP BY created_at')
    data = cursor.fetchall()
    conn.close()
    return jsonify(data)

@app.route('/api/availability')
def api_availability():
    availability = calculate_availability()
    return jsonify({"availability": availability})


@app.route('/o2api/incident_status')
def o2api_incident_status():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('SELECT service_id, created_at, resolved_at, status FROM incidents')
    incidents = cursor.fetchall()
    conn.close()

    service_status = {}
    for incident in incidents:
        service_id, created_at, resolved_at, status = incident
        if service_id not in service_status:
            service_status[service_id] = []
        service_status[service_id].append({
            'created_at': created_at,
            'resolved_at': resolved_at,
            'status': status
        })

    return jsonify(service_status)

@app.route('/api/incident_status')
def api_incident_status():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('SELECT service_id, service_summary, id, created_at, resolved_at, status FROM incidents')
    # cursor.execute('SELECT service_id, title, id, created_at, resolved_at, status FROM incidents')
    incidents = cursor.fetchall()
    conn.close()

    service_status = {}
    for incident in incidents:
        # service_id, service_title, incident_id, created_at, resolved_at, status = incident
        service_id, service_summary, incident_id, created_at, resolved_at, status = incident
        if service_id not in service_status:
            service_status[service_id] = {
                # 'title': service_title,
                'title': service_summary,
                'incidents': []
            }
        service_status[service_id]['incidents'].append({
            'id': incident_id,
            'created_at': created_at,
            'resolved_at': resolved_at,
            'status': status
        })

    return jsonify(service_status)


@app.route('/o3api/incident_status')
def o3api_incident_status():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('SELECT service_id, id, created_at, resolved_at, status FROM incidents')
    incidents = cursor.fetchall()
    conn.close()

    service_status = {}
    for incident in incidents:
        service_id, incident_id, created_at, resolved_at, status = incident
        if service_id not in service_status:
            service_status[service_id] = []
        service_status[service_id].append({
            'id': incident_id,
            'created_at': created_at,
            'resolved_at': resolved_at,
            'status': status
        })

    return jsonify(service_status)



from datetime import datetime, timedelta


from datetime import datetime, timedelta

@app.route('/api/incident_status_by_day')
def api_incident_status_by_day():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('SELECT service_id, service_summary, created_at, status FROM incidents')
    incidents = cursor.fetchall()
    conn.close()

    service_status_by_day = {}
    today = datetime.today()
    ninety_days_ago = today - timedelta(days=90)

    for incident in incidents:
        service_id, service_title, created_at, status = incident
        date = created_at.split('T')[0]
        incident_date = datetime.strptime(date, '%Y-%m-%d')
        if incident_date < ninety_days_ago:
            continue

        if service_id not in service_status_by_day:
            service_status_by_day[service_id] = {
                'title': service_title,
                'dates': {}
            }
        if date not in service_status_by_day[service_id]['dates']:
            service_status_by_day[service_id]['dates'][date] = 0
        # if status != 'resolved':
        if status in ['open', 'acknowledged', 'resolved']:
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


@app.route('/o5api/incident_status_by_day')
def o5api_incident_status_by_day():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('SELECT service_id, service_summary, created_at, status FROM incidents')
    incidents = cursor.fetchall()
    conn.close()

    service_status_by_day = {}
    for incident in incidents:
        service_id, service_title, created_at, status = incident
        date = created_at.split('T')[0]
        if service_id not in service_status_by_day:
            service_status_by_day[service_id] = {
                'title': service_title,
                'dates': {}
            }
        if date not in service_status_by_day[service_id]['dates']:
            service_status_by_day[service_id]['dates'][date] = 0
        if status != 'resolved':
            service_status_by_day[service_id]['dates'][date] = 1

    for service_id in service_status_by_day:
        dates = service_status_by_day[service_id]['dates']
        if dates:
            min_date = datetime.strptime(min(dates.keys()), '%Y-%m-%d')
            max_date = datetime.strptime(max(dates.keys()), '%Y-%m-%d')
            current_date = min_date
            while current_date <= max_date:
                date_str = current_date.strftime('%Y-%m-%d')
                if date_str not in dates:
                    dates[date_str] = 0
                current_date += timedelta(days=1)

    return jsonify(service_status_by_day)

@app.route('/o4api/incident_status_by_day')
def o4api_incident_status_by_day():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('SELECT service_id, service_summary, created_at, status FROM incidents')
    incidents = cursor.fetchall()
    conn.close()

    service_status_by_day = {}
    for incident in incidents:
        service_id, service_title, created_at, status = incident
        date = created_at.split('T')[0]
        if service_id not in service_status_by_day:
            service_status_by_day[service_id] = {
                'title': service_title,
                'dates': {}
            }
        if date not in service_status_by_day[service_id]['dates']:
            service_status_by_day[service_id]['dates'][date] = 0
        if status != 'resolved':
            service_status_by_day[service_id]['dates'][date] = 1

    return jsonify(service_status_by_day)


@app.route('/oapi/incident_status_by_day')
def oapi_incident_status_by_day():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('SELECT service_id, created_at, status FROM incidents')
    incidents = cursor.fetchall()
    conn.close()

    service_status_by_day = {}
    for incident in incidents:
        service_id, created_at, status = incident
        date = created_at.split('T')[0]
        if service_id not in service_status_by_day:
            service_status_by_day[service_id] = {}
        if date not in service_status_by_day[service_id]:
            service_status_by_day[service_id][date] = {'open': 0, 'resolved': 0}
        if status == 'resolved':
            service_status_by_day[service_id][date]['resolved'] += 1
        else:
            service_status_by_day[service_id][date]['open'] += 1

    return jsonify(service_status_by_day)


@app.route('/o2api/incident_status_by_day')
def o2api_incident_status_by_day():
    conn = sqlite3.connect('incidents.db')
    cursor = conn.cursor()
    cursor.execute('SELECT service_id, created_at, resolved_at, status FROM incidents')
    incidents = cursor.fetchall()
    conn.close()

    service_status_by_day = {}
    for incident in incidents:
        service_id, created_at, resolved_at, status = incident
        date = created_at.split('T')[0]
        if service_id not in service_status_by_day:
            service_status_by_day[service_id] = {}
        if date not in service_status_by_day[service_id]:
            service_status_by_day[service_id][date] = {'open': 0, 'resolved': 0}
        if status == 'resolved':
            service_status_by_day[service_id][date]['resolved'] += 1
        else:
            service_status_by_day[service_id][date]['open'] += 1

    return jsonify(service_status_by_day)


if __name__ == '__main__':
    app.run(debug=True)
