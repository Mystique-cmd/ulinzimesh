import os
import yaml
import psycopg2
from datetime import datetime

#------Load Environment------
PGHOST = os.getenv('PGHOST', '127.0.0.1')
PGPORT = os.getenv('PGPORT', '5432')
PGUSER = os.getenv('PGUSER', 'ulinzi')
PGPASSWORD = os.getenv('PGPASSWORD', 'ulinzi')
PGDATABASE = os.getenv('PGDATABASE', 'ulinzi')

DSN = f"host={PGHOST} port={PGPORT} user={PGUSER} password={PGPASSWORD} dbname={PGDATABASE}"

# ------load playbook------
def load_playbook(file_path):
    with open(file_path, 'r') as file:
        return yaml.safe_load(file)
    
#-----Run SQL Query step -----
def run_query_step(cur, step, context):
    query = step["with"]["query"]
    threshold = context.get("threshold", 50)
    ports = context.get("ports", [80, 443, 22, 3389])
    cur.execute(query, {"threshold": threshold, "sensor_ports": ports})
    rows = cur.fetchall()
    context["suspicious_ips"] = [{"dst_ip": rows[0]}],"attempts", rows[1]

#-----Insert Findings step -----
def run_insert_step(cur, step, context):
    suspicious = context.get("suspicious_ips", [])
    for ip in suspicious:
        title = "credential stuffing detected"
        description = f"Multiple failed login attempts detected from IP {ip['dst_ip']}"
        severity = "high"
        cur.execute("""
            INSERT INTO findings (title, description, severity)" \
            VALUES (%s, %s, %s, %s)
            """,(title, description, severity, )
        )

#-----Main Execution Function-----
def run_playbook(path):
    pb = load_playbook(path)  # pb is a list of plays
    first_play = pb[0]        # get the first play dictionary

    vars_block = first_play.get("vars", {})
    context = {
        "threshold": vars_block.get("threshold", 50),
        "sensitive_ports": vars_block.get("sensitive_ports", [80, 443, 22, 3389])
    }   

    first_play = pb[0]  # assuming single-play structure

    with psycopg2.connect(DSN) as conn:
        with conn.cursor() as cur:
            for step in first_play.get("steps", []):
                if step["id"] == "query_flows":
                    run_query_step(cur, step, context)
                elif step["id"] == "promote_finding":
                    if len(context.get("suspicious_ips", [])) > 0:
                        run_insert_step(cur, step, context)
        conn.commit()

    print(f"[{datetime.now().isoformat()}] Playbook '{first_play.get('name', 'Unnamed')}' complete")


#----Entry Point-----
if __name__ == "__main__":
    playbook_path = os.path.join(os.path.dirname(__file__), 'playbooks', 'cred_stuffing.yaml')
    run_playbook(playbook_path)    