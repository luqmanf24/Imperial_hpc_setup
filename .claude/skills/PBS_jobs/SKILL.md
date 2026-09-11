---
name: PBS_jobs
description: Writing, sizing and monitoring PBS Pro jobs on Imperial College RCS (CX3 / HX1). Use when the user asks to write or edit a .pbs script, pick a queue or core count, check why a job is queued, or estimate walltime.
---

# PBS_jobs

## Header shape

```
#PBS -l walltime=08:00:00
#PBS -l select=1:ncpus=8:mem=32gb
#PBS -N short_name
#PBS -j oe                       # merge stdout/stderr (optional)

cd "$PBS_O_WORKDIR"
module load ...
```

`select` is nodes; `ncpus`/`mem` are **per node**. Multi-node MPI:
`select=4:ncpus=128:mem=200gb:mpiprocs=128`.

## Sizing rules that avoid long queue waits

- **Never request the top of a queue class's core range.** RCS routes jobs to
  a class by the resources requested, and the boundary values are the ones
  everyone asks for. Ask for one step below.
- Check the current class table before quoting numbers — it changes:
  https://icl-rcs-user-guide.readthedocs.io/en/latest/hpc/queues/
- Memory is a hard limit: a job that exceeds `mem` is killed with no useful
  message in the job's own output. Look in the `.e<jobid>` / `.o<jobid>` files
  in the submit directory and at `qstat -xf <jobid> | grep -i resources_used`.

## Monitoring

```
qstat -u $USER            # alias: qs
qstat -f <jobid>          # full detail; job_state, exec_host, comment
qstat -xf <jobid>         # finished jobs too
qdel <jobid>
```

`comment` in `qstat -f` usually says *why* a job is still queued.

## Interactive vs batch

`qsub -I` dies with the terminal that launched it. If that terminal is inside a
VS Code tunnel, one dropped connection takes out both. For anything that must
outlive the session, submit a batch job — this is why `qvsc` exists
(`pbs/tunnel_job.pbs`).

## Don'ts

- Do not scan the filesystem with `find /` or an unscoped `find` on `/rds` —
  it is a shared network filesystem and this gets sessions killed by ICT.
  Always scope `find` to a specific directory.
- Do not run heavy Python/MATLAB post-processing on a login node; use the
  Jupyter-on-demand session or a batch job.
