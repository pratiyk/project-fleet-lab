from flask import Flask, jsonify
import os

mock_metadata = Flask(__name__)

@mock_metadata.route('/latest/meta-data/iam/security-credentials/')
def creds():
    return 'projectfleet-role\n'

@mock_metadata.route('/latest/meta-data/iam/security-credentials/projectfleet-role')
def role():
    return jsonify({
        "AccessKeyId": "AKIA5UBC_TEMP_789",
        "SecretAccessKey": "t3mp_s3cr3t_vlu3_xyz123",
        "Token": "FAKETOKEN",
        "Expiration": "2026-12-31T23:59:59Z"
    })

if __name__ == '__main__':
    mock_metadata.run(host='0.0.0.0', port=8000)
