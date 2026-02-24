import time
while True:
    with open('/tmp/fleet-monitor.log', 'a') as f:
        f.write('Fleet monitor running...\n')
    time.sleep(60)
