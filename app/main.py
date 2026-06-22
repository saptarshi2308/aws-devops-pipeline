import sqlite3
from flask import Flask, jsonify

app = Flask(__name__)

def init_db():
    conn = sqlite3.connect('database.db')
    cursor = conn.cursor()
    cursor.execute('CREATE TABLE IF NOT EXISTS system_status (id INTEGER PRIMARY KEY, status TEXT)')
    cursor.execute('INSERT OR IGNORE INTO system_status (id, status) VALUES (1, "All Systems Operational")')
    conn.commit()
    conn.close()

@app.route('/api/health', methods=['GET'])
def health_check():
    # Fetching the status directly from the SQL database
    conn = sqlite3.connect('database.db')
    cursor = conn.cursor()
    cursor.execute('SELECT status FROM system_status WHERE id=1')
    result = cursor.fetchone()
    conn.close()
    
    return jsonify({"service": "python-backend", "database_status": result[0]})

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=8000)