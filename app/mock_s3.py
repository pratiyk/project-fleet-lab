from flask import Flask, send_from_directory, abort
import os

mock_s3 = Flask(__name__)

BUCKET_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '../s3-bucket'))

@mock_s3.route('/<path:filename>')
def bucket_file(filename):
    # Support both /bucket/filename and /filename
    if filename.startswith('bucket/'):
        filename = filename[7:]
    
    file_path = os.path.join(BUCKET_PATH, filename)
    if os.path.isfile(file_path):
        return send_from_directory(BUCKET_PATH, filename)
    else:
        return f"Error: NoSuchKey (path tried: {file_path})", 404

if __name__ == '__main__':
    mock_s3.run(host='0.0.0.0', port=9000)
