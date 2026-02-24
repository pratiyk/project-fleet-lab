This directory simulates a public docs folder with a .git repo. The .git history will leak AWS credentials.

## Lab Note
The file `aws-creds.txt` is committed in the repo and contains fake AWS credentials for exploitation. The `.git` directory is intentionally left exposed for enumeration and git-dumper attacks.