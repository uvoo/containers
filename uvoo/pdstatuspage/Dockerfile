# Use the official Python image from the Docker Hub
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY app.py /app
COPY index.html /app/templates

# Install any needed packages specified in requirements.txt
RUN pip install flask psycopg2-binary pymssql requests sqlalchemy

# Make port 80 available to the world outside this container
EXPOSE 8080

# Run app.py when the container launches
CMD ["python", "app.py"]
