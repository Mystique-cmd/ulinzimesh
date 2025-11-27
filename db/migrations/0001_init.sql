CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE hosts (
    host_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hostname TEXT NOT NULL,
    platform TEXT CHECK (platform IN ('linux','windows','macos')),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ux_hosts_hostname ON hosts(hostname);

CREATE TABLE network_flows (
    flow_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    host_id UUID NOT NULL REFERENCES hosts(host_id) ON DELETE CASCADE,
    ts TIMESTAMPTZ NOT NULL DEFAULT now(),
    src_ip INET NOT NULL,
    src_port INT,
    dst_ip INET NOT NULL,
    dst_port INT,
    protocol TEXT,
    direction TEXT CHECK (direction IN ('ingress','egress')),
    bytes_tx BIGINT DEFAULT 0,
    bytes_rx BIGINT DEFAULT 0
);

CREATE INDEX idx_flows_ts ON network_flows(ts);
CREATE INDEX idx_flows_dst ON network_flows(dst_ip, dst_port);

CREATE TABLE indicators (
    indicator_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT CHECK (type IN ('ip', 'domain', 'hash','url','ja3','user-agent')),
    value TEXT NOT NULL,
    first_seen TIMESTAMPTZ DEFAULT now(),
    last_seen TIMESTAMPTZ DEFAULT now(),
    confidence INT CHECK (confidence BETWEEN 0 AND 100),
    sources JSONB DEFAULT '[]' :: JSONB,
    UNIQUE(type, value)
);

CREATE INDEX idx_ind_value ON indicators(value);

CREATE TABLE findings (
    finding_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    severity TEXT CHECK (severity IN ( 'low','medium','high','critical')) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_findings_created ON findings(created_at);
CREATE INDEX idx_findings_severity ON findings(severity);

CREATE TABLE decoys (
    decoy_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT CHECK(type IN ('port','service','web','credential','file')),
    label TEXT,
    location TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE decoy_interactions (
    interaction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    decoy_id UUID REFERENCES decoys(decoy_id) ON DELETE SET NULL,
    ts TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor_ip INET,
    user_agent TEXT,
    ja3 TEXT,
    details JSONB DEFAULT '{}' :: JSONB
);

CREATE INDEX idx_decoy_interactions_ts ON decoy_interactions(ts);
CREATE INDEX idx_actor_ip ON decoy_interactions(actor_ip);

CREATE TABLE playbooks(
    playbook_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    yaml_spec TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE playbook_runs(
    run_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    playbook_id UUID NOT NULL REFERENCES playbooks(playbook_id) ON DELETE CASCADE,
    status TEXT CHECK (status IN ('queued','running','succeeded','failed','canceled')),
    started_at TIMESTAMPTZ DEFAULT now(),
    finished_at TIMESTAMPTZ,
    inputs JSONB,
    decisions JSONB,
    artifacts JSONB
);

CREATE INDEX idx_playbook_runs_status ON playbook_runs(status);
CREATE INDEX idx_playbook_runs_started ON playbook_runs(started_at);

CREATE TABLE nodes (
    node_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    type TEXT
);

CREATE TABLE edges (
    edge_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    src_id UUID NOT NULL REFERENCES nodes(node_id) ON DELETE CASCADE,
    dst_id UUID NOT NULL REFERENCES nodes(node_id) ON DELETE CASCADE,
    relation TEXT NOT NULL,
    confidence INT CHECK (confidence BETWEEN 0 AND 100) DEFAULT 100,
    created_by TEXT,
    valid_from TIMESTAMPTZ DEFAULT now(),
    valid_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_edges_rel ON edges (relation);
CREATE INDEX idx_edges_src ON edges(src_id);
CREATE INDEX idx_edges_dst ON edges(dst_id);