#!/usr/bin/env python3
import os
import requests
from flask import Flask, render_template, jsonify
from datetime import datetime, timedelta
from sqlalchemy import create_engine, Column, String, Integer, DateTime, Boolean, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

app = Flask(__name__)

PAGERDUTY_API_TOKEN = os.getenv('PAGERDUTY_API_TOKEN')
PAGERDUTY_SERVICES = os.getenv('PAGERDUTY_SERVICES').split(',')
DATABASE_URL = os.getenv('DATABASE_URL')

engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)
Base = declarative_base()

class Incident(Base):
    __tablename__ = 'incidents'
    id = Column(String, primary_key=True)
    incident_number = Column(Integer)
    title = Column(String)
    description = Column(Text)
    created_at = Column(DateTime)
    updated_at = Column(DateTime)
    status = Column(String)
    incident_key = Column(String)
    service_id = Column(String)
    service_summary = Column(String)
    assigned_via = Column(String)
    last_status_change_at = Column(DateTime)
    resolved_at = Column(DateTime)
    first_trigger_log_entry_id = Column(String)
    first_trigger_log_entry_summary = Column(String)
    alert_counts_all = Column(Integer)
    alert_counts_triggered = Column(Integer)
    alert_counts_resolved = Column(Integer)
    is_mergeable = Column(Boolean)
    urgency = Column(String)
    self = Column(String)
    html_url = Column(String)

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
    Base.metadata.create_all(engine)

def sync_incidents():
    session = Session()
    for service_id in PAGERDUTY_SERVICES:
        incidents = fetch_incidents(service_id)
        for incident in incidents:
            session.merge(Incident(
                id=incident['id'],
                incident_number=incident['incident_number'],
                title=incident['title'],
                description=incident.get('description', ''),
                created_at=datetime.strptime(incident['created_at'], '%Y-%m-%dT%H:%M:%SZ'),
                updated_at=datetime.strptime(incident['updated_at'], '%Y-%m-%dT%H:%M:%SZ'),
                status=incident['status'],
                incident_key=incident.get('incident_key', ''),
                service_id=incident['service']['id'],
                service_summary=incident['service']['summary'],
                assigned_via=incident.get('assigned_via', ''),
                last_status_change_at=datetime.strptime(incident['last_status_change_at'], '%Y-%m-%dT%H:%M:%SZ'),
                resolved_at=datetime.strptime(incident['resolved_at'], '%Y-%m-%dT%H:%M:%SZ') if incident.get('resolved_at') else None,
                first_trigger_log_entry_id=incident['first_trigger_log_entry']['id'],
                first_trigger_log_entry_summary=incident['first_trigger_log_entry']['summary'],
                alert_counts_all=incident['alert_counts']['all'],
                alert_counts_triggered=incident['alert_counts']['triggered'],
                alert_counts_resolved=incident['alert_counts']['resolved'],
                is_mergeable=incident['is_mergeable'],
                urgency=incident['urgency'],
                self=incident['self'],
                html_url=incident['html_url']
            ))
    session.commit()
    session.close()

def calculate_availability():
    session = Session()
    incidents = session.query(Incident).filter(Incident.status != "resolved").all()

    total_downtime = 0
    total_time = 0

    for incident in incidents:
        created_at = incident.created_at
        resolved_at = incident.resolved_at if incident.resolved_at else datetime.utcnow()
        downtime = (resolved_at - created_at).total_seconds()
        total_downtime += downtime

    total_time = 30 * 24 * 60 * 60  # 30 days in seconds

    availability = ((total_time - total_downtime) / total_time) * 100

    session.close()
    return availability

sync_incidents()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/incidents')
def api_incidents():
    session = Session()
    data = session.query(Incident.created_at, func.count(Incident.id)).group_by(Incident.created_at).all()
    session.close()
    return jsonify(data)

@app.route('/api/availability')
def api_availability():
    availability = calculate_availability()
    return jsonify({"availability": availability})

@app.route('/api/incident_status')
def api_incident_status():
    session = Session()
    incidents = session.query(Incident.service_id, Incident.service_summary, Incident.id, Incident.created_at, Incident.resolved_at, Incident.status).all()
    session.close()

    service_status = {}
    for incident in incidents:
        service_id, service_summary, incident_id, created_at, resolved_at, status = incident
        if service_id not in service_status:
            service_status[service_id] = {
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

@app.route('/api/incident_status_by_day')
def api_incident_status_by_day():
    session = Session()
    incidents = session.query(Incident.service_id, Incident.service_summary, Incident.created_at, Incident.status).all()
    session.close()

    service_status_by_day = {}
    today = datetime.today()
    ninety_days_ago = today - timedelta(days=90)

    for incident in incidents:
        service_id, service_title, created_at, status = incident
        date = created_at.strftime('%Y-%m-%d')
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

if __name__ == '__main__':
    app.run(debug=True)
