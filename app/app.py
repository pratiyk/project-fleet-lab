from flask import Flask, request, send_from_directory, render_template_string
import os
import requests

app = Flask(__name__)

@app.route('/')
def index():
    return render_template_string('''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>ProjectFleet CI/CD Dashboard</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    </head>
    <body class="bg-light">
        <div class="container mt-5">
            <div class="card shadow">
                <div class="card-body">
                    <h1 class="card-title text-primary">ProjectFleet CI/CD Dashboard</h1>
                    <p class="card-text">Monitor your fleet, view build status, and manage deployments.</p>
                    <hr>
                    <ul class="list-group">
                        <li class="list-group-item">Build Status: <span class="badge bg-success">Passing</span></li>
                        <li class="list-group-item">Last Deployment: <span class="badge bg-info">2026-02-24 14:00 UTC</span></li>
                        <li class="list-group-item">Fleet Monitor: <span class="badge bg-warning text-dark">Active</span></li>
                    </ul>
                    <div class="mt-4">
                        <a href="/ssrf" class="btn btn-outline-danger">Test SSRF Endpoint</a>
                        <a href="/static/docs/README.md" class="btn btn-outline-secondary">View Documentation</a>
                    </div>
                </div>
            </div>
        </div>
    </body>
    </html>
    '' )

@app.route('/ssrf', methods=['GET', 'POST'])
def ssrf():
    if request.method == 'POST':
        url = request.form.get('url')
        try:
            r = requests.get(url, timeout=2)
            return f'<pre>{r.text}</pre>'
        except Exception as e:
            return f'Error: {e}'
    return '''<form method="post">URL: <input name="url"><input type="submit"></form>'''

@app.route('/static/docs/<path:filename>')
def serve_docs(filename):
    return send_from_directory('../static/docs', filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
