# 09 - Jobs and CronJobs

## Job
A **Job** runs pods **to completion**: batch work, migrations, backups, reports.
The Job controller retries failed pods until `completions` successes or `backoffLimit` failures.

| Field | Meaning |
|-------|---------|
| `completions` | How many successful pods are needed (default 1) |
| `parallelism` | How many run at once (default 1) |
| `backoffLimit` | Retries before marking the Job Failed (default 6) |
| `activeDeadlineSeconds` | Hard timeout for the whole Job |
| `ttlSecondsAfterFinished` | Auto-delete the Job and its pods after it finishes |
| `completionMode: Indexed` | Each pod gets `JOB_COMPLETION_INDEX` (0..N-1) for sharded work |
| `podFailurePolicy` | Fail fast or ignore based on exit codes or conditions |
| `suspend` | Pause the Job |

`restartPolicy` must be `OnFailure` (restart the container in the same pod) or `Never` (create a new pod).

### Job patterns
- **Single run**: completions=1, parallelism=1
- **Fixed completion count**: completions=N, parallelism=M
- **Work queue**: parallelism=M, completions unset. Pods pull from a queue and exit when it's empty.
- **Indexed**: each index processes its own shard.

## CronJob
A **CronJob** creates Jobs on a schedule (cron syntax, in the controller's timezone unless `timeZone` is set).

```
┌───────── minute (0-59)
│ ┌─────── hour (0-23)
│ │ ┌───── day of month (1-31)
│ │ │ ┌─── month (1-12)
│ │ │ │ ┌─ day of week (0-6, Sun=0)
* * * * *
*/5 * * * *   every 5 minutes
0 2 * * *     2am daily
```

| Field | Meaning |
|-------|---------|
| `concurrencyPolicy` | `Allow` (default), `Forbid` (skip if the previous run is still going), `Replace` |
| `startingDeadlineSeconds` | Skip a run if it can't start within N seconds of its scheduled time |
| `successfulJobsHistoryLimit` / `failedJobsHistoryLimit` | Defaults 3 and 1 |
| `suspend` | Pause the schedule |
| `timeZone` | e.g. `Asia/Kolkata` |

> Make jobs **idempotent**. CronJobs can occasionally run twice or skip a run.

## Commands
```bash
kubectl apply -f job.yaml
kubectl get jobs,pods
kubectl logs job/pi
kubectl wait --for=condition=complete job/pi --timeout=120s
kubectl create job manual-run --from=cronjob/hello     # trigger a CronJob now
kubectl get cronjobs
kubectl patch cronjob hello -p '{"spec":{"suspend":true}}'
```
