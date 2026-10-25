import os

# Matches the other apps on the EC2 server: one worker keeps memory low on the
# small instance, threads handle concurrent requests.
workers = 1
threads = 4
preload_app = True

# Render sets PORT and needs a public bind; on the EC2 box nginx proxies to
# a local-only port instead.
bind = f"0.0.0.0:{os.environ['PORT']}" if os.environ.get("PORT") else "127.0.0.1:3005"
