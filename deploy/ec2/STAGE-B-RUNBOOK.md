# Stage B — staging dress-rehearsal on a restored prod snapshot (in-VPC)

Validates the full 2.25.7 stack against a **copy of prod data**, end-to-end, before the
real cutover. Also absorbs the old standalone Phase-4 DB rehearsal (folded here 2026-06-12
because both need the same in-VPC temp host). Treat this run **as if it were prod** — that's
the point: it validates the runbook, not just the software.

> **The single most dangerous step is §6.** A restored snapshot contains the 21 ACTIVE prod
> workflows. If n8n boots before they're deactivated, their Schedule/Cron/Poll triggers fire
> against **real external systems** (risk R10). §6 runs the deactivate-all SQL *before* any
> n8n boot and is non-negotiable.

All commands are `us-east-1`, account `132880019009`. Run from a laptop with the `eric-luna`
creds unless a step says "on the EC2 (SSM)". `$` lines are shell; copy in order.

---

## 0. Verified environment (captured 2026-06-12)

| Thing | Value |
|---|---|
| VPC | `vpc-07470c34e31549396` |
| Prod RDS (source) | `flowdb` — postgres 17.9, db.t3.small, **private** |
| Latest snapshot | `rds:flowdb-2026-06-12-03-53` (re-check for a newer one at run time) |
| RDS security group | `sg-06235fad31cfc972d` — inbound 5432 only from itself + `sg-0dcf72d4bc3184b99` |
| SG that can reach RDS | `sg-0dcf72d4bc3184b99` (`torqnlp-flowise-staging`, same VPC) — attach to the temp EC2 |
| Temp EC2 subnet | `subnet-0acaaf8c82ff338a4` (us-east-1d, same as prod EC2 — has ECR egress) |
| AMI (AL2023 x86_64) | `ami-0152204c1a187337c` (re-fetch latest at run time, see below) |
| ECR repo | `132880019009.dkr.ecr.us-east-1.amazonaws.com/flow` |
| Encryption key | Secrets Manager `flow/n8n-encryption-key` (plain string) |
| DB credential | RDS-**managed** master secret `rds!db-4bf41722-252e-46ab-89fc-72ac72f7ffd8` — **JSON** `{"username","password",...}`, encrypted with KMS key `6b7b64a9-de91-4a27-bba5-2dc6380160e6`. Master user **is** `workforce` (same as the app), so this one secret covers both the app connection and the safety SQL. |
| DB user / db | `workforce` / `flowdb` |
| Image tag to test | `flow:2.25.7-f2134a29` (the flow-2.x HEAD at writing) |
| Community nodes to verify | `n8n-nodes-torqdata@0.1.67`, `n8n-nodes-generate-report@0.1.0` |
| Scale (expect after restore) | 105 workflows / 21 active / ~31 executions → migration is fast |

```bash
export AWS_DEFAULT_REGION=us-east-1
SNAP=$(aws rds describe-db-snapshots --db-instance-identifier flowdb --snapshot-type automated \
  --query 'reverse(sort_by(DBSnapshots,&SnapshotCreateTime))[0].DBSnapshotIdentifier' --output text)
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
ECR=132880019009.dkr.ecr.us-east-1.amazonaws.com
echo "snapshot=$SNAP ami=$AMI"
```

---

## 1. Push the tested image to ECR (from the laptop where it was built)

The image `flow:2.25.7-<sha>` was built and boot-tested locally (Phase 3). Push it so the
temp EC2 can pull it. If the local image is gone, rebuild per `deploy/ec2/README.md` first.

```bash
SHA=f2134a29   # flow-2.x HEAD short sha used at build time
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR
docker tag flow:2.25.7-localtest $ECR/flow:2.25.7-$SHA
docker push $ECR/flow:2.25.7-$SHA
```

---

## 2. Restore the snapshot to a scratch instance

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier flowdb-stageb \
  --db-snapshot-identifier "$SNAP" \
  --db-instance-class db.t3.small \
  --db-subnet-group-name rds-subnet-group-staging \
  --vpc-security-group-ids sg-06235fad31cfc972d \
  --no-publicly-accessible \
  --no-multi-az \
  --tags Key=purpose,Value=stage-b-rehearsal Key=ephemeral,Value=true

# wait ~10-15 min, then capture the endpoint
aws rds wait db-instance-available --db-instance-identifier flowdb-stageb
STAGEB_DB=$(aws rds describe-db-instances --db-instance-identifier flowdb-stageb \
  --query 'DBInstances[0].Endpoint.Address' --output text)
echo "restored DB: $STAGEB_DB"
```

The restored instance keeps the **same master credential as prod** (it's a snapshot), so the
managed secret `rds!db-4bf41722-...` is the right credential. It stores JSON, so every fetch
below extracts `.password` with python3 (present on AL2023; `jq` is not).

---

## 3. IAM role + instance profile for the temp EC2

No SSM-capable instance profile exists in the account, so create a minimal one (SSM for
remote control + ECR pull + read the two secrets). Delete it at teardown.

```bash
cat > /tmp/ec2-trust.json <<'JSON'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}
JSON
aws iam create-role --role-name flow-stageb-ec2 --assume-role-policy-document file:///tmp/ec2-trust.json
aws iam attach-role-policy --role-name flow-stageb-ec2 --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam attach-role-policy --role-name flow-stageb-ec2 --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
cat > /tmp/sm-read.json <<'JSON'
{"Version":"2012-10-17","Statement":[
  {"Effect":"Allow","Action":"secretsmanager:GetSecretValue","Resource":[
    "arn:aws:secretsmanager:us-east-1:132880019009:secret:flow/n8n-encryption-key*",
    "arn:aws:secretsmanager:us-east-1:132880019009:secret:rds!db-4bf41722-252e-46ab-89fc-72ac72f7ffd8*"]},
  {"Effect":"Allow","Action":"kms:Decrypt","Resource":"arn:aws:kms:us-east-1:132880019009:key/6b7b64a9-de91-4a27-bba5-2dc6380160e6"}
]}
JSON
aws iam put-role-policy --role-name flow-stageb-ec2 --policy-name sm-read --policy-document file:///tmp/sm-read.json
# kms:Decrypt is required because the RDS-managed secret is encrypted with that CMK.
aws iam create-instance-profile --instance-profile-name flow-stageb-ec2
aws iam add-role-to-instance-profile --instance-profile-name flow-stageb-ec2 --role-name flow-stageb-ec2
sleep 10   # let the instance profile propagate
```

---

## 4. Launch the temp EC2 (in-VPC, can reach RDS)

The instance carries `sg-0dcf72d4bc3184b99` (already allowed into RDS) so **no change to the
prod RDS security group is needed**. t3.large is plenty for a rehearsal.

```bash
EC2_ID=$(aws ec2 run-instances \
  --image-id "$AMI" --instance-type t3.large \
  --subnet-id subnet-0acaaf8c82ff338a4 \
  --security-group-ids sg-0dcf72d4bc3184b99 \
  --iam-instance-profile Name=flow-stageb-ec2 \
  --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":40,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=flow-stageb},{Key=ephemeral,Value=true}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "EC2: $EC2_ID"
aws ec2 wait instance-status-ok --instance-ids "$EC2_ID"
# confirm SSM picked it up (give the agent a minute)
aws ssm describe-instance-information --filters Key=InstanceIds,Values=$EC2_ID --query 'InstanceInformationList[0].PingStatus' --output text
```

Helper to run a command on the box and wait for output:

```bash
ssm() { # ssm "<shell>"
  local cid; cid=$(aws ssm send-command --instance-ids "$EC2_ID" \
    --document-name AWS-RunShellScript --parameters "commands=[$1]" \
    --query Command.CommandId --output text)
  aws ssm wait command-executed --command-id "$cid" --instance-id "$EC2_ID" 2>/dev/null
  aws ssm get-command-invocation --command-id "$cid" --instance-id "$EC2_ID" \
    --query '[StandardOutputContent,StandardErrorContent]' --output text
}
```

> **Escaping tip.** The `send-command` JSON arrays below (especially the `.env` heredoc and
> the `psql` blocks) are escape-heavy. If a command misbehaves, drop into an interactive
> shell instead — `aws ssm start-session --target "$EC2_ID"` then `sudo su - ec2-user` — and
> paste the *inner* command verbatim with no `\"` escaping. Same effect, far less fiddly.
> The password never leaves the box either way.

---

## 5. Provision the box: docker, compose file, env

```bash
ssm '"dnf -y install docker postgresql15 && systemctl enable --now docker && usermod -aG docker ec2-user","curl -sSL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose && docker compose version || /usr/local/bin/docker-compose version"'
```

Copy the prod-faithful compose to the box and write `/opt/flow/.env`. The compose is
`deploy/ec2/docker-compose.yml` from this branch. Transfer it via SSM (base64) or `aws s3`:

```bash
B64=$(base64 -i deploy/ec2/docker-compose.yml)
ssm "\"mkdir -p /opt/flow\",\"echo $B64 | base64 -d > /opt/flow/docker-compose.yml\""
```

Build the `.env` **on the box** so secrets come straight from Secrets Manager and never
touch the laptop. `OPENSEARCH_HOST` is fetched too — if it was rotated, store the new value
in a secret first and read it here; otherwise the torqdata embedder test in §8 will fail
auth (acceptable — note it and move on).

```bash
ssm "\"cd /opt/flow\",\"KEY=\$(aws secretsmanager get-secret-value --region us-east-1 --secret-id flow/n8n-encryption-key --query SecretString --output text)\",\"DBPW=\$(aws secretsmanager get-secret-value --region us-east-1 --secret-id 'rds!db-4bf41722-252e-46ab-89fc-72ac72f7ffd8' --query SecretString --output text | python3 -c 'import json,sys;print(json.load(sys.stdin)[\\\"password\\\"])')\",\"cat > /opt/flow/.env <<EOF
ECR_REGISTRY=$ECR
FLOW_IMAGE_TAG=2.25.7-$SHA
N8N_VERSION=2.25.7
DB_POSTGRESDB_HOST=$STAGEB_DB
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=flowdb
DB_POSTGRESDB_USER=workforce
DB_POSTGRESDB_PASSWORD=\$DBPW
N8N_ENCRYPTION_KEY=\$KEY
N8N_HOST=flow-stageb.local
GENERIC_TIMEZONE=UTC
N8N_RUNNERS_AUTH_TOKEN=\$(openssl rand -hex 32)
OPENSEARCH_HOST=\$(aws secretsmanager get-secret-value --region us-east-1 --secret-id flow/opensearch-host --query SecretString --output text 2>/dev/null || echo unused)
EOF\",\"chmod 600 /opt/flow/.env\""
```

---

## 6. ⚠️ SAFETY GATE — deactivate all workflows BEFORE booting n8n

Run this against the **restored** DB and confirm `0` active before anything boots. This is
the R10 mitigation; do not skip, do not reorder.

```bash
# reuse the password already fetched into /opt/flow/.env (§5) — no re-fetch
ssm "\"cd /opt/flow\",\". ./.env\",\"PGPASSWORD=\$DB_POSTGRESDB_PASSWORD psql 'host=$STAGEB_DB port=5432 dbname=flowdb user=workforce sslmode=require' -c 'UPDATE workflow_entity SET active = false;'\",\"PGPASSWORD=\$DB_POSTGRESDB_PASSWORD psql 'host=$STAGEB_DB port=5432 dbname=flowdb user=workforce sslmode=require' -tAc 'SELECT count(*) AS still_active FROM workflow_entity WHERE active;'\""
```

**Expected last line: `0`. If it is not 0, STOP — do not boot n8n.**

---

## 7. Boot the stack + measure the migration

```bash
ssm "\"cd /opt/flow\",\"aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR\",\"docker compose up -d\""

# Poll until healthz is up, then derive timing + migration count from the logs.
ssm "\"cd /opt/flow\",\"for i in \$(seq 1 60); do curl -sf http://localhost:5678/healthz >/dev/null && break; sleep 5; done\",\"echo healthz=\$(curl -s -o /dev/null -w %{http_code} http://localhost:5678/healthz)\",\"echo migrations_run=\$(docker compose logs n8n 2>&1 | grep -c 'Finished migration')\""

# Migration wall-clock = timestamp delta between the first 'Starting migration' and the
# last 'Finished migration' (docker logs are timestamped):
ssm "\"cd /opt/flow\",\"docker compose logs -t n8n 2>&1 | grep -E 'Starting migration|Finished migration' | sed -n '1p;\$p'\""
```

Record: migration count, the two timestamps' delta (this sets the cutover maintenance-window
length), any errors. With ~31 executions this should be well under a couple of minutes.

---

## 8. Validation checklist (the go/no-go evidence)

```bash
# counts unchanged vs the snapshot
ssm "\"cd /opt/flow\",\". ./.env\",\"PGPASSWORD=\$DB_POSTGRESDB_PASSWORD psql 'host=$STAGEB_DB port=5432 dbname=flowdb user=workforce sslmode=require' -tAc \\\"SELECT (SELECT count(*) FROM workflow_entity) wf, (SELECT count(*) FROM credentials_entity) creds, (SELECT count(*) FROM execution_entity) execs, (SELECT count(*) FROM installed_packages) pkgs\\\"\""
```

- [ ] **Workflow / credential / execution counts** match the pre-migration snapshot (≈105 / N / ≈31).
- [ ] **Credentials decrypt** — log in to the editor (port-forward via SSM, below) and open
      3–4 credentials; they must render, not error. **A decrypt failure = wrong encryption
      key = hard stop** (and a hard rollback trigger at real cutover).
- [ ] **Publish/active mapping** — note what happened to the 21 previously-active workflows
      (upstream doesn't document the active→published mapping; write down what you observe —
      it feeds the Phase 7 comms).
- [ ] **Community nodes reinstalled** — `installed_packages` still lists `n8n-nodes-torqdata`
      and `n8n-nodes-generate-report`; confirm both load (no "unrecognized node" on open).
      Reactivate one torqdata workflow **with test/staging credentials**, run it once.
- [ ] **`n8n-nodes-generate-report@0.1.0` (third-party)** — load a workflow that uses it; if
      it errors on 2.x, that's a Phase-5 finding (pin/patch/replace), not a cutover blocker
      unless an active workflow depends on it.
- [ ] **Code node via runner** — reactivate (or create) a JS Code-node workflow, execute it,
      confirm it runs through the runner sidecar (proves the external-runner wiring on real data).

Reach the editor from the laptop through SSM port-forwarding:

```bash
aws ssm start-session --target "$EC2_ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["5678"],"localPortNumber":["5678"]}'
# then open http://localhost:5678
```

---

## 9. Rollback rehearsal (do it once, here)

Prove the cutover rollback works before trusting it in prod: stop the 2.x stack and boot the
**old 1.90 image** against the same restored snapshot.

```bash
ssm "\"cd /opt/flow\",\"docker compose down\""
# boot old image (replace with the real 1.90 ECR tag — the prod image digest)
ssm "\"docker run -d --name flow-rollback -p 5678:5678 --env-file /opt/flow/.env $ECR/flow:<OLD-1.90-TAG>\""
ssm "\"sleep 30\",\"curl -s -o /dev/null -w 'rollback healthz=%{http_code}\\n' http://localhost:5678/healthz\",\"docker rm -f flow-rollback\""
```

> The 1.90→2.25 migrations are one-way; rolling **back the schema** isn't possible. This step
> only proves the **old binary boots against a snapshot restore** — which is the real cutover
> rollback (restore snapshot + start old container), not `db:revert`.

---

## 10. Go / no-go to production

Proceed to the Stage-C prod cutover only if **all** hold:
- Runbook executed start-to-finish **without improvisation** (gaps here = fix the runbook first).
- Counts match; **all opened credentials decrypted**; migration timing within the agreed window.
- Code-node-via-runner and at least one torqdata workflow ran green on real data.
- Rollback (§9) booted the old image healthy.
- The active→published mapping is documented for Phase 7 comms.

---

## 11. Teardown (always run, even on failure)

```bash
ssm "\"cd /opt/flow\",\"docker compose down -v\"" 2>/dev/null
aws ec2 terminate-instances --instance-ids "$EC2_ID"
aws ec2 wait instance-terminated --instance-ids "$EC2_ID"
aws rds delete-db-instance --db-instance-identifier flowdb-stageb --skip-final-snapshot --delete-automated-backups
aws iam remove-role-from-instance-profile --instance-profile-name flow-stageb-ec2 --role-name flow-stageb-ec2
aws iam delete-instance-profile --instance-profile-name flow-stageb-ec2
aws iam delete-role-policy --role-name flow-stageb-ec2 --policy-name sm-read
aws iam detach-role-policy --role-name flow-stageb-ec2 --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam detach-role-policy --role-name flow-stageb-ec2 --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam delete-role --role-name flow-stageb-ec2
```

Nothing here touches prod: the temp EC2 reused an existing SG (no RDS SG change), the scratch
RDS is independent, and the IAM role is dedicated. Confirm `flowdb-stageb` is gone and no
`flow-stageb` instance remains.
```
