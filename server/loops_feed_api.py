#!/usr/bin/env python3
"""Simple video feed API for the Flutter Loops tab.
Returns videos in LoopVideo.fromJson format."""
import json, os, mysql.connector, subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

# Get DB connection from 110 server via SSH tunnel
DB_CONFIG = {
    'host': '185.55.240.110',
    'port': 3306,
    'user': 'loops_admin',
    'password': 'loops_admin_pass_2026',
    'database': 'loops_server',
}

SSH_PASS = 'Zu4rtnfsv'

def query_videos(limit=20):
    """Query videos via SSH tunnel to MySQL on 110 server"""
    import subprocess, json
    
    sql = f"""SELECT id, vid, caption, uri, thumbnail, thumbnail_path, 
                     duration, size_kb, views, likes, comments, shares,
                     profile_id, width, height, created_at
              FROM videos 
              WHERE status = 2 AND visibility = 1
              ORDER BY created_at DESC, views DESC
              LIMIT {limit}"""
    
    # Escape the SQL for shell
    escaped_sql = sql.replace('"', '\\"').replace("'", "\\'").replace('$', '\\$')
    
    cmd = f"""sshpass -p '{SSH_PASS}' ssh -o StrictHostKeyChecking=no root@185.55.240.110 \
              "docker exec -i loops-db mysql -u loops_admin -p'loops_admin_pass_2026' loops_server -e \\"{escaped_sql}\\" 2>/dev/null" """
    
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
    
    videos = []
    lines = result.stdout.strip().split('\n')
    if len(lines) < 2:
        return videos
    
    headers = [h.strip() for h in lines[0].split('\t')]
    for line in lines[1:]:
        if not line.strip():
            continue
        vals = line.split('\t')
        row = dict(zip(headers, vals))
        
        vid_url = f"https://185.55.240.110:8080/storage/{row.get('uri', '')}" if row.get('uri') else ""
        thumb_url = f"https://185.55.240.110:8080/storage/{row.get('thumbnail', '')}" if row.get('thumbnail') else ""
        
        videos.append({
            'id': row.get('vid', ''),
            'title': row.get('caption', '')[:50] if row.get('caption') else 'Untitled',
            'description': row.get('caption', '')[:100] if row.get('caption') else '',
            'video_url': vid_url,
            'thumbnail_url': thumb_url,
            'view_count': int(row.get('views', 0) or 0),
            'reward_points': int(row.get('likes', 0) or 0) * 10,
            'creator': 'Admin',
        })
    
    return videos

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        
        if path == '/loops/feed':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            try:
                vids = query_videos(30)
                self.wfile.write(json.dumps({'data': vids}).encode())
            except Exception as e:
                self.wfile.write(json.dumps({'error': str(e), 'data': []}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, fmt, *a):
        pass

if __name__ == '__main__':
    port = 8766
    server = HTTPServer(('127.0.0.1', port), Handler)
    print(f'Loops Feed API on port {port}')
    server.serve_forever()
