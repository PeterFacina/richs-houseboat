# Private training backup and restore

The private inbox uses SQLite WAL under `%LOCALAPPDATA%\HouseboatPromptTraining`. A consistent online snapshot needs SQLite's backup API so committed data in the live WAL is included. Use the current worker account and keep the staging and restore files in a protected local directory. [Node SQLite backup API](https://nodejs.org/api/sqlite.html#sqlitebackupsource-db-path-options)

## Verified local drill

An online backup from a read-only connection finished in 13 ms while the production worker was running. A temporary authenticated AES-256-GCM copy was decrypted to a separate SQLite file. `PRAGMA integrity_check` passed, and the two verified captures and existing review matched the originals. Altering the ciphertext caused authentication to fail. The temporary files were removed and the ephemeral key was discarded. This exercise verified the local backup mechanics and left the live inbox in place.

## Portable recovery plan

1. Provision a dedicated recovery identity and retain it in an approved offline or organizational secret store. Record who can recover it and verify access from a separate machine. Keep recovery keys separate from encrypted archives. Windows DPAPI's current-user scope is appropriate for a same-user local layer. A portable recovery plan needs an independently recoverable identity. [Microsoft data-protection scopes](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.dataprotectionscope)
2. Use the SQLite online backup API to create a snapshot under the worker's protected profile. Run `PRAGMA integrity_check` on the snapshot. Use a versioned encrypted volume or an audited recipient encryption tool such as `age --encrypt -r RECOVERY_RECIPIENT -o SNAPSHOT.sqlite.age SNAPSHOT.sqlite`. Transfer the encrypted archive to approved off-device storage. Remove the temporary unencrypted snapshot after verification and keep values, credentials, and archives out of Git. [age documentation](https://github.com/FiloSottile/age)
3. On a separate recovery machine, decrypt a test archive to a protected directory with the recovery identity. Verify SQLite integrity and check that known capture and review rows and their publication links match the backup manifest. Establish an interval and retention policy with the team. For a production restore, drain and stop the worker, preserve the current data with its sidecars, and restore the verified database before restarting. Keep a rollback copy until the new instance is confirmed healthy.

The off-device plan still needs a designated recovery owner, destination, independently stored key and cross-machine restore drill. The existing #66 proposed target remains pending human approval in the private inbox.
