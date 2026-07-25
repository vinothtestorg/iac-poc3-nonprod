# iac-poc3-nonprod

Stack root for app `poc3`, nonprod only. Deployments: dev, uat.

The only file a human edits here is `manifest.yaml`. Everything matching
`*.tfcomponent.hcl` / `*.tfdeploy.hcl`, plus `.terraform-version` and
`.terraform.lock.hcl`, is rendered by stack-forge and listed in
`.stackforge-generated`. Hand-edits are rejected by CI — change the manifest.

| Layer | Source | Pin |
|---|---|---|
| Claim catalog | `vinothtestorg/alicloud-service-catalog` | `@catalog-nonprod` (channel ref, advanced by Governance) |
| Generator + templates | `vinothtestorg/stack-forge` | `@v1.0.0` (immutable release) |
| Modules | HCP Terraform private registry | version pinned by the catalog's `template-matrix.yaml` |

Neither shared repo is checked out and no token is used to read them: they arrive
through `uses:`, which GitHub serves with a scoped read-only token that expires
in an hour.
