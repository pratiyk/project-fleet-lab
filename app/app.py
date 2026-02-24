from flask import Flask, request, send_from_directory, render_template_string
import os
import requests

app = Flask(__name__)

@app.route('/')
def index():
    return '<h1>Welcome to ProjectFleet</h1><p>Internal CI/CD dashboard.</p>'

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
