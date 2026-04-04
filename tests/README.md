# Tests

User-facing entrypoints:

- `test-deployments.sh`: full containerized deployment test
- `refresh-test-image.sh`: refresh the cached local test image

Auxiliary files:

- `verify-deployment.sh`: scenarios run inside the container
- `test-deployments-in-nix-check.sh`: lightweight `nix build` check
- `home-manager-activation.nix`: helper for test HM activation packages
- `deployments.nix`: flake wiring for the app/check outputs

Output:

- default: concise progress lines only
- `-v`: full logs
