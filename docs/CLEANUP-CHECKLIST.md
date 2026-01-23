# Docker Centralization - Manual Cleanup Checklist

## 📋 Overview

The Docker centralization to `platform/docker/` with subdirectories is complete, but some old files need to be manually deleted due to environment constraints.

## ✅ Completed

- [x] Created `platform/docker/go-service/` with Dockerfile, .dockerignore, and README.md
- [x] Created `platform/docker/devcontainer/` with all devcontainer files
- [x] Updated `.devcontainer/devcontainer.json` to point to new location
- [x] Updated `platform/scripts/build-go-service.sh` to use new Dockerfile path
- [x] Updated all documentation (README.md, platform/docker/README.md, etc.)
- [x] Created comprehensive documentation (INDEX.md, DOCKER-CENTRALIZATION.md)

## ❌ Pending Manual Cleanup

The following files need to be **manually deleted** as they are now duplicates or obsolete:

### 1. Duplicate Service Dockerfiles

These services now use the generic `platform/docker/go-service/Dockerfile`:

```bash
rm -f /workspace/services/booking/Dockerfile
rm -f /workspace/services/movie/Dockerfile
rm -f /workspace/services/payment/Dockerfile
rm -f /workspace/services/notification/Dockerfile
```

**Why**: All services now use the centralized generic Dockerfile with build args.

### 2. Old go-service Files

These have been moved to `platform/docker/go-service/` subdirectory:

```bash
rm -f /workspace/platform/docker/go-service.Dockerfile
rm -f /workspace/platform/docker/.dockerignore
```

**Why**: Files moved from `platform/docker/` root to `platform/docker/go-service/` subdirectory.

### 3. Old DevContainer Files

These have been moved to `platform/docker/devcontainer/`:

```bash
rm -f /workspace/.devcontainer/Dockerfile
rm -f /workspace/.devcontainer/docker-compose.yml
rm -f /workspace/.devcontainer/docker-compose.devcontainer.yml
```

**Keep these** in `.devcontainer/`:
- ✅ `devcontainer.json` - Points to `platform/docker/devcontainer/docker-compose.yml`
- ✅ `README.md` - Documentation explaining the pointer

**Why**: DevContainer files centralized in `platform/docker/devcontainer/`, only pointer config remains in `.devcontainer/`.

### 4. contrib Directory

Not used in the project:

```bash
rm -rf /workspace/contrib/
```

**Why**: Directory not referenced anywhere in the project.

## 🔍 Verification Commands

After manual cleanup, verify the structure:

```bash
# Should show NO Dockerfiles
ls -la /workspace/services/*/Dockerfile 2>/dev/null || echo "✅ No service Dockerfiles (correct)"

# Should show ONLY these files
ls -la /workspace/.devcontainer/
# Expected:
#   devcontainer.json
#   README.md

# Should show ONLY subdirectories
ls -la /workspace/platform/docker/
# Expected:
#   base/
#   devcontainer/
#   go-service/
#   mongodb/
#   webserver/
#   INDEX.md
#   README.md

# Should NOT exist
ls -la /workspace/contrib/ 2>/dev/null && echo "❌ contrib still exists" || echo "✅ contrib removed"
```

## 📊 File Inventory

### Before Cleanup

```
/workspace/
├── .devcontainer/
│   ├── devcontainer.json         ✅ KEEP (pointer)
│   ├── README.md                 ✅ KEEP (docs)
│   ├── Dockerfile                ❌ DELETE (duplicated in platform/docker/devcontainer/)
│   ├── docker-compose.yml        ❌ DELETE (duplicated)
│   └── docker-compose.devcontainer.yml  ❌ DELETE (duplicated)
├── contrib/
│   └── ...                       ❌ DELETE ALL (not used)
├── platform/docker/
│   ├── go-service.Dockerfile     ❌ DELETE (moved to go-service/Dockerfile)
│   ├── .dockerignore             ❌ DELETE (moved to go-service/.dockerignore)
│   ├── go-service/               ✅ NEW
│   ├── devcontainer/             ✅ NEW
│   └── ...
└── services/
    ├── booking/Dockerfile        ❌ DELETE (uses generic now)
    ├── movie/Dockerfile          ❌ DELETE (uses generic now)
    ├── payment/Dockerfile        ❌ DELETE (uses generic now)
    └── notification/Dockerfile   ❌ DELETE (uses generic now)
```

### After Cleanup (Target State)

```
/workspace/
├── .devcontainer/
│   ├── devcontainer.json         # Points to platform/docker/devcontainer/
│   └── README.md
├── platform/docker/
│   ├── go-service/
│   │   ├── Dockerfile
│   │   ├── .dockerignore
│   │   └── README.md
│   ├── devcontainer/
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   ├── devcontainer.json
│   │   └── README.md
│   ├── base/
│   ├── mongodb/
│   ├── webserver/
│   ├── INDEX.md
│   └── README.md
└── services/
    ├── booking/                  # NO Dockerfile
    ├── movie/                    # NO Dockerfile
    ├── payment/                  # NO Dockerfile
    └── notification/             # NO Dockerfile
```

## 🚀 All Cleanup Commands (Copy-Paste)

```bash
# Navigate to workspace
cd /workspace

# 1. Delete service Dockerfiles
rm -f services/booking/Dockerfile \
      services/movie/Dockerfile \
      services/payment/Dockerfile \
      services/notification/Dockerfile

# 2. Delete old go-service files
rm -f platform/docker/go-service.Dockerfile \
      platform/docker/.dockerignore

# 3. Delete old devcontainer files (keep devcontainer.json and README.md)
rm -f .devcontainer/Dockerfile \
      .devcontainer/docker-compose.yml \
      .devcontainer/docker-compose.devcontainer.yml

# 4. Delete contrib directory
rm -rf contrib/

# 5. Verify
echo "Checking for remaining old files..."
find services -name "Dockerfile" -type f && echo "❌ Service Dockerfiles still exist" || echo "✅ Service Dockerfiles removed"
test -d contrib && echo "❌ contrib still exists" || echo "✅ contrib removed"
echo "Files in .devcontainer:"
ls -1 .devcontainer/
echo "Expected: devcontainer.json, README.md"
```

## ⚠️ Important Notes

1. **Do NOT delete**:
   - `.devcontainer/devcontainer.json` - Required pointer to new location
   - `.devcontainer/README.md` - Documentation
   - Any files in `platform/docker/go-service/` or `platform/docker/devcontainer/`

2. **Safe to delete**:
   - All Dockerfiles in `services/*/` - Using generic Dockerfile now
   - `platform/docker/go-service.Dockerfile` - Moved to subdirectory
   - `platform/docker/.dockerignore` - Moved to subdirectory
   - Old devcontainer files in `.devcontainer/` - Moved to platform/docker/devcontainer/
   - Entire `contrib/` directory - Not used

3. **After cleanup**, the build process will work exactly the same:
   ```bash
   SERVICE=booking VERSION=v1.0.0 platform/scripts/build-go-service.sh
   ```

## 📚 References

- [Centralization Documentation](./DOCKER-CENTRALIZATION.md)
- [Platform Docker Index](../platform/docker/INDEX.md)
- [Go Service README](../platform/docker/go-service/README.md)
- [DevContainer README](../platform/docker/devcontainer/README.md)

---

**Created**: 2026-01-23
**Status**: Awaiting manual cleanup
**Reason**: Bash environment issues prevent automated deletion
