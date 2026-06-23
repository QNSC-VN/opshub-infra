## Description
<!-- What infrastructure change does this PR introduce? -->

## Type of change
- [ ] New resource
- [ ] Modification to existing resource
- [ ] Deletion / decommission
- [ ] Module refactor
- [ ] CI/CD / tooling change

## Environments affected
- [ ] `live/_shared`
- [ ] `live/develop`
- [ ] `live/prod`

## OpenTofu Plan
<!-- Paste the tofu plan output or link to the Plan workflow run -->
<details>
<summary>Plan output</summary>

```hcl
# Paste here
```

</details>

## Blast radius
<!-- What resources could be affected? Any dependencies on other teams? -->

## Rollback plan
<!-- How do we revert if this causes an incident? -->

## Checklist
- [ ] `tofu validate` passes locally
- [ ] Plan output reviewed and expected
- [ ] Secrets/credentials are NOT hardcoded (using AWS SSM / Secrets Manager references)
- [ ] State backend is correct for the target workspace
- [ ] Prod apply requires a second reviewer approval
