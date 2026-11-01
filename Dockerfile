FROM python:3.13-slim

WORKDIR /app

# Install dependencies first so Docker can cache this layer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/app.py .

#documentation
EXPOSE 5000
 
CMD ["python", "app.py"]
