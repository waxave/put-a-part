# Processing issue uniqueness rollout

Migration `20261104065047` adds a partial unique index on `(processing_record_id, stage, code)` for record-level issues. It uses PostgreSQL's concurrent index creation and does not backfill or delete data. Deploy the migration before code that relies on the index.

Before applying it to an existing database, check for duplicates:

```sql
SELECT processing_record_id, stage, code, COUNT(*)
FROM processing_issues
WHERE processing_record_id IS NOT NULL
GROUP BY processing_record_id, stage, code
HAVING COUNT(*) > 1;
```

If this returns rows, stop and reconcile them separately; the migration intentionally does not delete or merge issues. A concurrent build avoids a table rewrite and the long write-blocking lock of a normal index build, but still performs scans, uses resources, takes brief catalog locks, and can wait for old transactions. Duplicate writes during the build can cause it to fail.

If the build fails, inspect PostgreSQL's index state before retrying: a failed concurrent build can leave an invalid index with the same name. An operator should review and remove that invalid index concurrently before rerunning the migration. Rolling back the migration drops the index; do so only after confirming writers no longer rely on its uniqueness. No column rename or type change is involved.
