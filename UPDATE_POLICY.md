# Update policy

The upstream monitor reads the official GitHub Releases API and may only enqueue a newer normalized release. Every update must pin the exact release asset and SHA-256, pass first-boot readiness with its data volume attached, service and full-instance restart checks, persistence checks, secret and machine-identity scans, exact-artifact import/launch, and public readback. A failed candidate never moves `latest` and never replaces an immutable serial.
