from flask import Flask, request, send_from_directory, render_template, redirect, url_for
import os
import requests

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/ssrf', methods=['GET', 'POST'])
def ssrf():
    result = None
    if request.method == 'POST':
        url = request.form.get('url')
        try:
            r = requests.get(url, timeout=2)
            result = r.text
        except Exception as e:
            result = f'Error: {e}'
    return render_template('ssrf.html', result=result)

@app.route('/static/docs/<path:filename>')
def serve_docs(filename):
    return send_from_directory(os.path.abspath(os.path.join(os.path.dirname(__file__), '../static/docs')), filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
