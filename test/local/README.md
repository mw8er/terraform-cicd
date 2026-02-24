# Test cases

## plan and apply

```bash
export WORKDIR="changes"
devbox run --env-file $WORKDIR/config/.env_missing plan
```

```bash
export WORKDIR="changes"
devbox run --env-file $WORKDIR/config/.env plan
devbox run --env-file $WORKDIR/config/.env apply
devbox run --env-file $WORKDIR/config/.env plan-and-apply
```

```bash
export WORKDIR="../nochanges"
devbox run --env-file $WORKDIR/config/.env plan
devbox run --env-file $WORKDIR/config/.env apply
devbox run --env-file $WORKDIR/config/.env plan-and-apply
```

```bash
export WORKDIR="../noconfig"
devbox run --env-file $WORKDIR/config/.env plan
# devbox run --env-file $WORKDIR/config/.env apply
# devbox run --env-file $WORKDIR/config/.env plan-and-apply
```

```bash
export WORKDIR="../noterraform"
devbox run --env-file $WORKDIR/config/.env plan
# devbox run --env-file $WORKDIR/config/.env apply
devbox run --env-file $WORKDIR/config/.env plan-and-apply
```

## code quality

```bash
export WORKDIR="../badformat"
devbox run check-quality
```
