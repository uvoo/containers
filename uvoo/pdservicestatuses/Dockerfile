FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt /app
COPY app.py /app
COPY index.html /app/templates/index.html

RUN pip install --no-cache-dir -r requirements.txt

RUN groupadd -g 1001 app
RUN useradd -u 1001 -g 1001 -ms /bin/bash app
RUN chown 1001:1001 /app
USER app

# ENV FLASK_ENV=development
EXPOSE 8080

# CMD ["python", "app.py"]
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "--preload", "app:app"]
