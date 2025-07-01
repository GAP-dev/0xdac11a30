import os
import time
import configparser
import requests
import json
import threading
import pickle

TMP_FILE = '.seen_files.tmp'

# Load previous state
def load_seen_files():
    if os.path.exists(TMP_FILE):
        with open(TMP_FILE, 'rb') as f:
            return pickle.load(f)
    return {}

# Save current state
def save_seen_files(seen_files):
    with open(TMP_FILE, 'wb') as f:
        pickle.dump(seen_files, f)
# Send webhook message with file attachment
def send_webhook(webhook_url, label, file_path):
    filename = os.path.basename(file_path)
    content = f"💥 **Crash found!**\n**Label**: {label}\n**File**: `{filename}`"
    
    try:
        with open(file_path, 'rb') as f:
            files = {
                'file': (filename, f)
            }
            data = {
                'content': content
            }
            response = requests.post(webhook_url, data=data, files=files)
            if response.status_code not in (200, 204):
                print(f"❌ Failed to send webhook for {file_path}: {response.status_code} - {response.text}")
            else:
                print(f"✅ File sent: {filename}")
    except Exception as e:
        print(f"⚠️ Error sending webhook with file: {e}")

# Watch a single directory
def watch_directory(path, label, webhook_url, seen_files, lock, interval):
    print(f"🔍 Watching: {path} [{label}]")
    while True:
        try:
            current_files = set(os.listdir(path))
            with lock:
                previous_files = seen_files.get(path, set())

            new_files = current_files - previous_files

            for file in new_files:
                full_path = os.path.join(path, file)
                if os.path.isfile(full_path):
                    send_webhook(webhook_url, label, full_path)

            with lock:
                seen_files[path] = current_files
                save_seen_files(seen_files)

        except Exception as e:
            print(f"Error watching {path}: {e}")

        time.sleep(interval)

# Main
def main():
    config = configparser.ConfigParser()
    config.read('config.ini')

    interval = int(config['DEFAULT'].get('interval', 5))

    seen_files = load_seen_files()
    lock = threading.Lock()

    threads = []
    for section in config.sections():
        path = config[section]['path']
        label = config[section]['label']
        webhook = config[section]['webhook']

        if not os.path.exists(path):
            print(f"⚠️ Path does not exist: {path}")
            continue

        t = threading.Thread(target=watch_directory, args=(path, label, webhook, seen_files, lock, interval))
        t.daemon = True
        threads.append(t)
        t.start()

    # Keep alive
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("🛑 Exiting...")

if __name__ == '__main__':
    main()