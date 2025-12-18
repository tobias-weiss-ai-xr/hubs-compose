from flask import Flask, request
import os

app = Flask(__name__)

@app.route('/') # Fixed the route
def hello():
    port = os.getenv('PORT', '5000')
    hostname = request.headers.get('Host', 'localhost')
    return f"Hello from {hostname}:{port}"

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
